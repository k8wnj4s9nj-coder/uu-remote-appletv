import Foundation

public struct UUCredentials: Codable, Equatable, Sendable {
    public var userId: String
    public var deviceId: String
    public var clientId: String
    public var systemId: String
    public var machineGuid: String
    public var token: String
    public var csrf: String
    public var signKey: String
    public var accountName: String?

    public init(
        userId: String = "",
        deviceId: String = "",
        clientId: String = "",
        systemId: String = "",
        machineGuid: String = "",
        token: String = "",
        csrf: String = "",
        signKey: String = UUAPIConfig.defaultSignKey,
        accountName: String? = nil
    ) {
        self.userId = userId
        self.deviceId = deviceId
        self.clientId = clientId
        self.systemId = systemId
        self.machineGuid = machineGuid
        self.token = token
        self.csrf = csrf
        self.signKey = signKey.isEmpty ? UUAPIConfig.defaultSignKey : signKey
        self.accountName = accountName
    }

    public var isLoggedIn: Bool {
        !token.isEmpty && !userId.isEmpty && !deviceId.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceId = "device_id"
        case clientId = "client_id"
        case systemId = "system_id"
        case machineGuid = "machine_guid"
        case token, csrf
        case signKey = "sign_key"
        case accountName = "account_name"
    }
}

public enum UUCredentialStore {
    private static let key = "uu.remote.tv.credentials"

    public static func load() -> UUCredentials? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UUCredentials.self, from: data)
    }

    public static func save(_ creds: UUCredentials) {
        if let data = try? JSONEncoder().encode(creds) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
