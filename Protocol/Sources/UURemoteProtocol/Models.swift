import Foundation

public struct UUAPIEnvelope<T: Decodable>: Decodable {
    public let code: Int
    public let msg: String
    public let data: T?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decodeIfPresent(Int.self, forKey: .code) ?? -1
        msg = try c.decodeIfPresent(String.self, forKey: .msg) ?? ""
        data = try c.decodeIfPresent(T.self, forKey: .data)
    }
    private enum CodingKeys: String, CodingKey { case code, msg, data }
}

public struct UUDevice: Decodable, Identifiable, Hashable, Sendable {
    public var id: String { deviceId }
    public let deviceId: String
    public let platform: Int?
    public let alias: String?
    public let status: String?
    public let versionName: String?
    public let controllable: Bool?
    public let publisherAvailabilityStatus: String?
    public let controlledSupport: Bool?
    public let wallpaperUrl: String?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case platform, alias, status
        case versionName = "version_name"
        case controllable
        case publisherAvailabilityStatus = "publisher_availability_status"
        case controlledSupport = "controlled_support"
        case wallpaperUrl = "wallpaper_url"
    }

    public var displayName: String {
        let name = alias?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? deviceId : name
    }

    public var isOnline: Bool {
        let st = (status ?? "").uppercased()
        let ready = (publisherAvailabilityStatus ?? "").lowercased()
        return st == "CONNECTED" || ready == "ready"
    }

    public var statusLabel: String {
        if isOnline { return "在线" }
        if let s = status, !s.isEmpty { return s }
        return "离线"
    }
}

public struct UUDeviceListData: Decodable, Sendable {
    public let currentDevice: UUDevice?
    public let myBindedDevices: [UUDevice]
    public let othersSharedDevices: [UUDevice]

    enum CodingKeys: String, CodingKey {
        case currentDevice = "current_device"
        case myBindedDevices = "my_binded_devices"
        case othersSharedDevices = "others_shared_devices"
    }

    public var allRemoteHosts: [UUDevice] {
        var list = myBindedDevices + othersSharedDevices
        if let cur = currentDevice {
            // Controller may also appear as current_device; keep hosts that look controllable.
            if cur.controllable == true || cur.controlledSupport == true {
                if !list.contains(where: { $0.deviceId == cur.deviceId }) {
                    list.insert(cur, at: 0)
                }
            }
        }
        return list
    }
}

public struct UURoomCredentials: Decodable, Sendable {
    public let signalingServer: String
    public let token: String
    public let signalingList: [String]?
    public let wsConnectTimeoutMs: UInt64?

    enum CodingKeys: String, CodingKey {
        case signalingServer = "signaling_server"
        case token
        case signalingList = "signaling_list"
        case wsConnectTimeoutMs = "ws_connect_timeout_ms"
    }
}

public struct UUQRGenData: Decodable, Sendable {
    public let qrcodeJumpUrl: String
    public let token: String

    enum CodingKeys: String, CodingKey {
        case qrcodeJumpUrl = "qrcode_jump_url"
        case token
        case statusQueryTicket = "status_query_ticket"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        qrcodeJumpUrl = try c.decode(String.self, forKey: .qrcodeJumpUrl)
        if let t = try c.decodeIfPresent(String.self, forKey: .token) {
            token = t
        } else {
            token = try c.decode(String.self, forKey: .statusQueryTicket)
        }
    }
}

public struct UUQRStatusData: Decodable, Sendable {
    public let status: Int64?
}

public struct UULoginData: Decodable, Sendable {
    public let userId: String?
    public let token: String?
    public let accountName: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token
        case accountName = "account_name"
    }
}

public struct UUUserInfo: Decodable, Sendable {
    public let userId: String?
    public let nickname: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nickname
    }
}

/// Socket.IO SOAC (SDP / ICE) envelope used by UU Remote.
public struct UUSoacMessage: Codable, Sendable {
    public var type: String
    public var sdp: String?
    public var gzipSdp: String?
    public var candidate: AnyCodableJSON?
    public var iceId: AnyCodableJSON?
    public var sdpMid: String?
    public var sdpMlineIndex: Int?
    public var clientId: String?
    public var appControlId: AnyCodableJSON?

    enum CodingKeys: String, CodingKey {
        case type
        case sdp
        case gzipSdp = "gzip_sdp"
        case candidate
        case iceId = "ice_id"
        case sdpMid = "sdp_mid"
        case sdpMlineIndex = "sdp_mline_index"
        case clientId = "client_id"
        case appControlId = "app_control_id"
    }

    public init(type: String, sdp: String? = nil, clientId: String? = nil, iceId: AnyCodableJSON? = nil,
                candidate: AnyCodableJSON? = nil, sdpMid: String? = nil, sdpMlineIndex: Int? = nil,
                appControlId: AnyCodableJSON? = nil, gzipSdp: String? = nil) {
        self.type = type
        self.sdp = sdp
        self.gzipSdp = gzipSdp
        self.clientId = clientId
        self.iceId = iceId
        self.candidate = candidate
        self.sdpMid = sdpMid
        self.sdpMlineIndex = sdpMlineIndex
        self.appControlId = appControlId
    }
}

/// Minimal JSON passthrough for heterogeneous fields.
public struct AnyCodableJSON: Codable, Sendable, Hashable {
    public let value: JSONValue
    public init(_ value: JSONValue) { self.value = value }
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = .null }
        else if let b = try? c.decode(Bool.self) { value = .bool(b) }
        else if let i = try? c.decode(Int64.self) { value = .int(i) }
        else if let d = try? c.decode(Double.self) { value = .double(d) }
        else if let s = try? c.decode(String.self) { value = .string(s) }
        else if let a = try? c.decode([AnyCodableJSON].self) { value = .array(a.map(\.value)) }
        else if let o = try? c.decode([String: AnyCodableJSON].self) {
            value = .object(o.mapValues(\.value))
        } else { value = .null }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a.map(AnyCodableJSON.init))
        case .object(let o): try c.encode(o.mapValues(AnyCodableJSON.init))
        }
    }
}

public enum JSONValue: Sendable, Hashable {
    case null, bool(Bool), int(Int64), double(Double), string(String)
    case array([JSONValue]), object([String: JSONValue])
}
