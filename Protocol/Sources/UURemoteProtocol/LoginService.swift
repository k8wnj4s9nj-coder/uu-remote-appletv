import Foundation

public enum UUQRLoginPhase: Equatable, Sendable {
    case preparingDevice
    case waitingScan(qrContent: String)
    case scannedConfirmOnPhone
    case exchangingToken
    case succeeded(accountName: String)
    case expiredRefreshing
    case failed(String)
}

private struct DeviceInitResponse: Decodable {
    let deviceId: String
    enum CodingKeys: String, CodingKey { case deviceId = "device_id" }
}

public final class UULoginService: @unchecked Sendable {
    private var client: UUHTTPClient
    private var credentials: UUCredentials

    public init(credentials: UUCredentials = UUCredentials()) {
        var c = credentials
        if c.signKey.isEmpty { c.signKey = UUAPIConfig.defaultSignKey }
        self.credentials = c
        self.client = UUHTTPClient(credentials: c, platform: UUAPIConfig.platformTV)
    }

    public var currentCredentials: UUCredentials { credentials }

    public func prepareDevice(displayName: String = "Apple TV") async throws {
        if credentials.clientId.isEmpty { credentials.clientId = UUID().uuidString.lowercased() }
        if credentials.systemId.isEmpty { credentials.systemId = UUID().uuidString.uppercased() }
        if credentials.machineGuid.isEmpty { credentials.machineGuid = UUID().uuidString.uppercased() }
        client.credentials = credentials

        if credentials.deviceId.isEmpty {
            let body: [String: Any] = [
                "name": displayName,
                "client_id": credentials.clientId,
                "system_id": credentials.systemId,
                "machine_guid": credentials.machineGuid,
                "os": "tvOS",
                "base_board": "Apple TV",
                "cpu": "Apple Silicon",
                "video": ["Apple TV GPU"],
                "mac": "",
                "memory": 4096,
                "screen": "1920x1080"
            ]
            let id: String
            do {
                id = try await client.postJSON(UUPath.macosInit, body: body, as: DeviceInitResponse.self).deviceId
            } catch {
                id = try await client.postJSON(UUPath.windowsInit, body: body, as: DeviceInitResponse.self).deviceId
            }
            credentials.deviceId = id
            client.credentials = credentials
            UUCredentialStore.save(credentials)
        }
    }

    public func runQRLogin(onPhase: @escaping @Sendable (UUQRLoginPhase) -> Void) async throws -> UUCredentials {
        onPhase(.preparingDevice)
        try await prepareDevice()

        while !Task.isCancelled {
            let gen = try await client.postJSON(UUPath.qrGenLogin, body: [:], as: UUQRGenData.self)
            onPhase(.waitingScan(qrContent: gen.qrcodeJumpUrl))

            var loginStatus: Int64 = 1
            var needNewQR = false
            for _ in 0..<150 {
                if Task.isCancelled { throw CancellationError() }
                let query: [String: Any] = [
                    "token": gen.token,
                    "qrcode_jump_url": gen.qrcodeJumpUrl,
                    "login_status": loginStatus
                ]
                let statusPayload: UUQRStatusData
                do {
                    statusPayload = try await client.postJSON(UUPath.qrLoginStatus, body: query, as: UUQRStatusData.self)
                } catch let UUHTTPError.apiCode(code, _) where code == Int(UUAPIConfig.qrExpiredCode) {
                    onPhase(.expiredRefreshing)
                    needNewQR = true
                    break
                } catch {
                    continue
                }
                let st = statusPayload.status ?? loginStatus
                if st == loginStatus { continue }
                loginStatus = st
                if st == 2 {
                    onPhase(.scannedConfirmOnPhone)
                } else if st == 3 || st == 4 {
                    onPhase(.exchangingToken)
                    let body: [String: Any] = [
                        "token": gen.token,
                        "qrcode_jump_url": gen.qrcodeJumpUrl
                    ]
                    do {
                        let login = try await client.postJSON(UUPath.loginByQRCode, body: body, as: UULoginData.self)
                        guard let token = login.token, let userId = login.userId else {
                            throw UUHTTPError.apiCode(-1, "login 未返回 token/user_id")
                        }
                        credentials.token = token
                        credentials.userId = userId
                        credentials.csrf = UUJWT.csrf(from: token) ?? ""
                        credentials.accountName = login.accountName ?? userId
                        client.credentials = credentials
                        UUCredentialStore.save(credentials)
                        onPhase(.succeeded(accountName: credentials.accountName ?? userId))
                        return credentials
                    } catch {
                        needNewQR = true
                        break
                    }
                }
            }
            if !needNewQR { onPhase(.expiredRefreshing) }
        }
        throw CancellationError()
    }
}
