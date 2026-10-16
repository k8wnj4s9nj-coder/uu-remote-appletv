import Foundation

#if canImport(LiveKitWebRTC) || canImport(WebRTC)

#if canImport(LiveKitWebRTC)
import LiveKitWebRTC
private typealias _PC = LKRTCPeerConnection
private typealias _Factory = LKRTCPeerConnectionFactory
private typealias _SDP = LKRTCSessionDescription
private typealias _Ice = LKRTCIceCandidate
private typealias _Constraints = LKRTCMediaConstraints
private typealias _Config = LKRTCConfiguration
private typealias _IceServer = LKRTCIceServer
private typealias _TxInit = LKRTCRtpTransceiverInit
typealias _VideoTrack = LKRTCVideoTrack
private typealias _Stream = LKRTCMediaStream
private typealias _DC = LKRTCDataChannel
private typealias _DCConfig = LKRTCDataChannelConfiguration
private func _initSSL() { LKRTCInitializeSSL() }
public typealias UURemoteVideoTrack = LKRTCVideoTrack
#elseif canImport(WebRTC)
import WebRTC
private typealias _PC = RTCPeerConnection
private typealias _Factory = RTCPeerConnectionFactory
private typealias _SDP = RTCSessionDescription
private typealias _Ice = RTCIceCandidate
private typealias _Constraints = RTCMediaConstraints
private typealias _Config = RTCConfiguration
private typealias _IceServer = RTCIceServer
private typealias _TxInit = RTCRtpTransceiverInit
typealias _VideoTrack = RTCVideoTrack
private typealias _Stream = RTCMediaStream
private typealias _DC = RTCDataChannel
private typealias _DCConfig = RTCDataChannelConfiguration
private func _initSSL() { RTCInitializeSSL() }
public typealias UURemoteVideoTrack = RTCVideoTrack
#endif

/// Real WebRTC controller session: be-controlled → offer → answer → remote video track.
public final class UUWebRTCMediaSession: NSObject, UUMediaSession {
    public var onConnectionState: ((String) -> Void)?
    public var onFrameHint: ((String) -> Void)?
    public var onRemoteVideoTrack: ((UURemoteVideoTrack) -> Void)?

    private weak var signaling: UUSignalingClient?
    private var factory: _Factory?
    private var peer: _PC?
    private var clientId: String = ""
    private var iceId: String = ""
    private var appControlId: String = ""
    private var pendingRemoteCandidates: [_Ice] = []
    private var hasRemoteDescription = false
    private let credentialsClientId: String
    private var delegateBox: PeerDelegateBox?

    public init(clientId: String) {
        self.credentialsClientId = clientId
        super.init()
    }

    public func start(room: UURoomCredentials, signaling: UUSignalingClient) async throws {
        self.signaling = signaling
        onConnectionState?("webrtc: init")
        _initSSL()
        let factory = _Factory()
        self.factory = factory

        let config = _Config()
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        config.iceServers = [
            _IceServer(urlStrings: [
                "stun:stun.l.google.com:19302",
                "stun:stun1.l.google.com:19302",
                "stun:stun.miwifi.com:3478"
            ])
        ]

        let constraints = _Constraints(mandatoryConstraints: nil, optionalConstraints: [
            "DtlsSrtpKeyAgreement": "true"
        ])

        let box = PeerDelegateBox(owner: self)
        self.delegateBox = box

        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: box) else {
            throw UUHTTPError.apiCode(-1, "RTCPeerConnection 创建失败")
        }
        self.peer = pc

        let videoInit = _TxInit()
        videoInit.direction = .recvOnly
        _ = pc.addTransceiver(of: .video, init: videoInit)

        let audioInit = _TxInit()
        audioInit.direction = .recvOnly
        _ = pc.addTransceiver(of: .audio, init: audioInit)

        for label in ["CONTROL_DATA_CHANNEL", "TEXT_DATA_CHANNEL", "FILE_DATA_CHANNEL", "BINARY_DATA_CHANNEL"] {
            let dcConfig = _DCConfig()
            dcConfig.isOrdered = true
            _ = pc.dataChannel(forLabel: label, configuration: dcConfig)
        }

        clientId = credentialsClientId.isEmpty ? UUID().uuidString.lowercased() : credentialsClientId
        iceId = UUID().uuidString.lowercased()
        appControlId = UUID().uuidString.lowercased()

        onConnectionState?("signaling: connecting")
        try await signaling.connect(signalingServer: room.signalingServer, roomToken: room.token)

        signaling.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .connected:
                self.onConnectionState?("signaling: connected")
            case .roomInfoAck:
                self.onConnectionState?("signaling: room_info ack → handshake")
                Task { await self.beginControllerHandshake() }
            case .soac(let msg):
                Task { await self.handleRemoteSoac(msg) }
            case .disconnected(let reason):
                self.onConnectionState?("signaling: disconnected (\(reason))")
            case .released, .left:
                self.onConnectionState?("session: peer left")
            default:
                break
            }
        }
    }

    private func beginControllerHandshake() async {
        guard let signaling, let peer else { return }
        let header = UUBeControlledHeader(
            iceId: iceId,
            clientId: clientId,
            appControlId: appControlId,
            controllerPlatform: 5
        )
        do {
            try await signaling.emitBeControlled(header: header, connectOptions: UUConnectOptions.encode())
            onConnectionState?("sent be-controlled")
        } catch {
            onConnectionState?("be-controlled failed: \(error.localizedDescription)")
            return
        }

        let constraints = _Constraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "true"
            ],
            optionalConstraints: nil
        )
        peer.offer(for: constraints) { [weak self] sdp, error in
            guard let self else { return }
            if let error {
                self.onConnectionState?("createOffer failed: \(error.localizedDescription)")
                return
            }
            guard let sdp else { return }
            peer.setLocalDescription(sdp) { err in
                if let err {
                    self.onConnectionState?("setLocalDescription failed: \(err.localizedDescription)")
                    return
                }
                Task {
                    var msg = UUSoacMessage(type: "offer", sdp: sdp.sdp, clientId: self.clientId,
                                            iceId: AnyCodableJSON(.string(self.iceId)))
                    msg.appControlId = AnyCodableJSON(.string(self.appControlId))
                    do {
                        try await signaling.emitSoac(msg)
                        self.onConnectionState?("sent SOAC offer")
                    } catch {
                        self.onConnectionState?("emit offer failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    public func handleRemoteSoac(_ message: UUSoacMessage) async {
        switch message.type {
        case "answer":
            var sdp = message.sdp ?? ""
            if sdp.isEmpty, let gz = message.gzipSdp {
                onConnectionState?("answer used gzip_sdp (inflate not implemented; need plain sdp)")
                _ = gz
            }
            guard !sdp.isEmpty else {
                onConnectionState?("answer SDP empty")
                return
            }
            await applyRemoteAnswer(sdp)
        case "candidate":
            await addRemoteCandidate(message)
        default:
            onConnectionState?("soac: \(message.type)")
        }
    }

    private func applyRemoteAnswer(_ sdp: String) async {
        guard let peer else { return }
        let desc = _SDP(type: .answer, sdp: sdp)
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            peer.setRemoteDescription(desc) { [weak self] error in
                guard let self else { cont.resume(); return }
                if let error {
                    self.onConnectionState?("setRemoteDescription failed: \(error.localizedDescription)")
                } else {
                    self.hasRemoteDescription = true
                    self.onConnectionState?("remote answer applied")
                    for c in self.pendingRemoteCandidates {
                        self.peer?.add(c) { _ in }
                    }
                    self.pendingRemoteCandidates.removeAll()
                }
                cont.resume()
            }
        }
    }

    private func addRemoteCandidate(_ message: UUSoacMessage) async {
        var candStr: String?
        var mid: String? = message.sdpMid
        var mline: Int32 = Int32(message.sdpMlineIndex ?? 0)
        if let c = message.candidate {
            switch c.value {
            case .string(let s): candStr = s
            case .object(let o):
                if case .string(let s) = o["candidate"] { candStr = s }
                if case .string(let s) = o["sdpMid"] { mid = s }
                if case .int(let i) = o["sdpMLineIndex"] { mline = Int32(i) }
            default: break
            }
        }
        guard let candStr, !candStr.isEmpty else { return }
        let ice = _Ice(sdp: candStr, sdpMLineIndex: mline, sdpMid: mid)
        if hasRemoteDescription {
            peer?.add(ice) { _ in }
        } else {
            pendingRemoteCandidates.append(ice)
        }
    }

    public func stop() {
        signaling?.disconnect()
        signaling = nil
        peer?.close()
        peer = nil
        factory = nil
        delegateBox = nil
        onConnectionState?("stopped")
    }

    fileprivate func emitLocalCandidate(_ candidate: _Ice) {
        guard let signaling else { return }
        let mid = candidate.sdpMid ?? "0"
        let mline = Int(candidate.sdpMLineIndex)
        let msg = UUSoacMessage(
            type: "candidate",
            clientId: clientId,
            iceId: AnyCodableJSON(.string(iceId)),
            candidate: AnyCodableJSON(.object([
                "candidate": .string(candidate.sdp),
                "sdpMid": .string(mid),
                "sdpMLineIndex": .int(Int64(mline))
            ])),
            sdpMid: mid,
            sdpMlineIndex: mline
        )
        Task { try? await signaling.emitSoac(msg) }
    }

    fileprivate func noteVideoTrack(_ track: _VideoTrack) {
        onFrameHint?("remote video track received")
        onRemoteVideoTrack?(track)
        onConnectionState?("video track ready")
    }

    /// NSObject delegate bridge (RTCPeerConnectionDelegate is @objc).
    }


fileprivate final class PeerDelegateBox: NSObject {
    weak var owner: UUWebRTCMediaSession?
    init(owner: UUWebRTCMediaSession) { self.owner = owner }
}

#if canImport(LiveKitWebRTC)
import LiveKitWebRTC
extension PeerDelegateBox: LKRTCPeerConnectionDelegate {
    // Signatures aligned with livekit/client-sdk-swift Transport.swift (LKRTC* state enums).
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange stateChanged: LKRTCSignalingState) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd stream: LKRTCMediaStream) {
        if let t = stream.videoTracks.first { owner?.noteVideoTrack(t) }
    }
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove stream: LKRTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: LKRTCPeerConnection) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceConnectionState) {
        owner?.onConnectionState?("ICE: \(String(describing: newState))")
        if newState == .failed {
            owner?.onConnectionState?("ICE failed — NAT/firewall; host may need TURN from cloud")
        }
    }
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceGatheringState) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didGenerate candidate: LKRTCIceCandidate) {
        owner?.emitLocalCandidate(candidate)
    }
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove candidates: [LKRTCIceCandidate]) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didOpen dataChannel: LKRTCDataChannel) {
        owner?.onFrameHint?("data channel: \(dataChannel.label)")
    }
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCPeerConnectionState) {
        owner?.onConnectionState?("PC: \(String(describing: newState))")
    }
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd rtpReceiver: LKRTCRtpReceiver, streams: [LKRTCMediaStream]) {
        if let t = rtpReceiver.track as? LKRTCVideoTrack {
            owner?.noteVideoTrack(t)
        }
    }
}
#elseif canImport(WebRTC)
import WebRTC
extension PeerDelegateBox: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        if let t = stream.videoTracks.first { owner?.noteVideoTrack(t) }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        owner?.onConnectionState?("ICE: \(String(describing: newState))")
        if newState == .failed {
            owner?.onConnectionState?("ICE failed — NAT/firewall; host may need TURN from cloud")
        }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        owner?.emitLocalCandidate(candidate)
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        owner?.onFrameHint?("data channel: \(dataChannel.label)")
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        owner?.onConnectionState?("PC: \(String(describing: newState))")
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams: [RTCMediaStream]) {
        if let t = rtpReceiver.track as? RTCVideoTrack {
            owner?.noteVideoTrack(t)
        }
    }
}
#endif

#else

/// No WebRTC linked: signaling-only path with clear Mac instructions.
public final class UUWebRTCMediaSession: UUMediaSession {
    public var onConnectionState: ((String) -> Void)?
    public var onFrameHint: ((String) -> Void)?
    public var onRemoteVideoTrack: ((Any) -> Void)?

    private let stub = UUStubMediaSession()
    public init(clientId: String) {
        _ = clientId
        stub.onConnectionState = { [weak self] s in self?.onConnectionState?(s) }
        stub.onFrameHint = { [weak self] s in self?.onFrameHint?(s) }
    }

    public func start(room: UURoomCredentials, signaling: UUSignalingClient) async throws {
        onConnectionState?("WebRTC 未链接 — 仅信令（本构建 stub）")
        onFrameHint?("本构建暂无 WebRTC 画面，登录与设备列表可用")
        try await stub.start(room: room, signaling: signaling)
    }

    public func handleRemoteSoac(_ message: UUSoacMessage) async { await stub.handleRemoteSoac(message) }
    public func stop() { stub.stop() }
}

#endif
