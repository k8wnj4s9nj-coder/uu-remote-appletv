import Foundation

/// `GvPb_ConnectOptions` wire encoding (from host-side decode notes in VallierDev signaling).
/// Field 1: capture_type (1/2 = desktop)
/// Field 4: repeated DecoderCap bytes
/// DecoderCap: 1=fps, 2=codec (1 H264, 2 H265), 3=width, 4=height, 5=chroma (1=420, 3=444)
public enum UUConnectOptions {
    public static let captureTypeDesktop: UInt64 = 1
    public static let codecH264: UInt64 = 1
    public static let chroma420: UInt64 = 1

    public static func encode(
        captureType: UInt64 = captureTypeDesktop,
        fps: UInt64 = 60,
        codec: UInt64 = codecH264,
        width: UInt64 = 1920,
        height: UInt64 = 1080,
        chroma: UInt64 = chroma420
    ) -> Data {
        var out = Data()
        appendVarintField(1, captureType, to: &out)
        var cap = Data()
        appendVarintField(1, fps, to: &cap)
        appendVarintField(2, codec, to: &cap)
        appendVarintField(3, width, to: &cap)
        appendVarintField(4, height, to: &cap)
        appendVarintField(5, chroma, to: &cap)
        appendBytesField(4, cap, to: &out)
        return out
    }

    private static func appendVarintField(_ number: UInt32, _ value: UInt64, to data: inout Data) {
        appendVarint(UInt64(number << 3), to: &data) // wire type 0
        appendVarint(value, to: &data)
    }

    private static func appendBytesField(_ number: UInt32, _ bytes: Data, to data: inout Data) {
        appendVarint(UInt64((number << 3) | 2), to: &data)
        appendVarint(UInt64(bytes.count), to: &data)
        data.append(bytes)
    }

    private static func appendVarint(_ value: UInt64, to data: inout Data) {
        var v = value
        while v > 0x7F {
            data.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        data.append(UInt8(v & 0x7F))
    }
}

/// Header JSON for Socket.IO binary `be-controlled` (paired with ConnectOptions attachment).
public struct UUBeControlledHeader: Sendable {
    public var iceId: String
    public var clientId: String
    public var appControlId: String
    public var controllerPlatform: Int
    public var iceServers: [[String: Any]]
    public var forceRelay: Bool

    public init(
        iceId: String = UUID().uuidString.lowercased(),
        clientId: String,
        appControlId: String = UUID().uuidString.lowercased(),
        controllerPlatform: Int = 5,
        iceServers: [[String: Any]] = [],
        forceRelay: Bool = false
    ) {
        self.iceId = iceId
        self.clientId = clientId
        self.appControlId = appControlId
        self.controllerPlatform = controllerPlatform
        self.iceServers = iceServers
        self.forceRelay = forceRelay
    }

    public func jsonObject() -> [String: Any] {
        var obj: [String: Any] = [
            "ice_id": iceId,
            "iceId": iceId,
            "client_id": clientId,
            "app_control_id": appControlId,
            "controller_platform": controllerPlatform,
            "streamer_data": "{\"control_id\":\"\(appControlId)\"}",
            "force_relay": forceRelay
        ]
        if !iceServers.isEmpty {
            obj["iceServers"] = iceServers
        }
        return obj
    }
}
