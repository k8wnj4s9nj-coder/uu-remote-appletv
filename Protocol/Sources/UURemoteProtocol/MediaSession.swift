import Foundation

/// View-only remote video session.
public protocol UUMediaSession: AnyObject {
    var onConnectionState: ((String) -> Void)? { get set }
    var onFrameHint: ((String) -> Void)? { get set }

    func start(room: UURoomCredentials, signaling: UUSignalingClient) async throws
    func handleRemoteSoac(_ message: UUSoacMessage) async
    func stop()
}

/// Signaling-only placeholder used when WebRTC binary is not linked.
public final class UUStubMediaSession: UUMediaSession, @unchecked Sendable {
    public var onConnectionState: ((String) -> Void)?
    public var onFrameHint: ((String) -> Void)?
    private weak var signaling: UUSignalingClient?

    public init() {}

    public func start(room: UURoomCredentials, signaling: UUSignalingClient) async throws {
        self.signaling = signaling
        onConnectionState?("signaling: connecting (stub)")
        try await signaling.connect(signalingServer: room.signalingServer, roomToken: room.token)
        signaling.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .connected:
                self.onConnectionState?("signaling: connected")
            case .roomInfoAck:
                self.onConnectionState?("signaling: room_info ack (stub — no WebRTC)")
                self.onFrameHint?("本构建暂无 WebRTC 画面，登录与设备列表可用")
            case .soac(let msg):
                Task { await self.handleRemoteSoac(msg) }
            case .disconnected(let reason):
                self.onConnectionState?("signaling: disconnected (\(reason))")
            default:
                break
            }
        }
    }

    public func handleRemoteSoac(_ message: UUSoacMessage) async {
        onConnectionState?("soac: \(message.type)")
    }

    public func stop() {
        signaling?.disconnect()
        signaling = nil
        onConnectionState?("stopped")
    }
}

/// Session orchestrator used by the Apple TV UI.
public final class UURemoteSession: @unchecked Sendable {
    private let devices: UUDeviceService
    private let signaling = UUSignalingClient()
    private var media: UUMediaSession
    public var onState: ((String) -> Void)?
    /// Opaque video track for UI (`LKRTCVideoTrack` / `RTCVideoTrack` when WebRTC linked).
    public var onVideoTrack: ((Any) -> Void)?

    public init(credentials: UUCredentials, media: UUMediaSession? = nil) {
        self.devices = UUDeviceService(credentials: credentials)
        let webrtc: UUWebRTCMediaSession?
        if let media {
            self.media = media
            webrtc = media as? UUWebRTCMediaSession
        } else {
            let created = UUWebRTCMediaSession(clientId: credentials.clientId)
            self.media = created
            webrtc = created
        }
        // Wire callbacks only after all stored properties are initialized.
        webrtc?.onRemoteVideoTrack = { [weak self] track in
            self?.onVideoTrack?(track)
        }
        self.media.onConnectionState = { [weak self] s in self?.onState?(s) }
        self.media.onFrameHint = { [weak self] s in self?.onState?(s) }
    }

    public func listDevices() async throws -> [UUDevice] {
        try await devices.fetchDeviceList().allRemoteHosts
    }

    public func connectViewOnly(to device: UUDevice) async throws {
        onState?("joining room for \(device.displayName)…")
        let room = try await devices.joinRoom(deviceId: device.deviceId)
        onState?("joined; starting WebRTC…")
        try await media.start(room: room, signaling: signaling)
    }

    public func disconnect() {
        media.stop()
    }
}
