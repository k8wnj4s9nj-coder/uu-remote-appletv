import Foundation

public enum UUHTTPError: Error, LocalizedError {
    case badURL
    case httpStatus(Int, String)
    case apiCode(Int, String)
    case decoding(Error)
    case transport(Error)
    case loginExpired

    public var errorDescription: String? {
        switch self {
        case .badURL: return "无效 URL"
        case .httpStatus(let s, let m): return "HTTP \(s): \(m)"
        case .apiCode(let c, let m): return "API \(c): \(m)"
        case .decoding(let e): return "解码失败: \(e.localizedDescription)"
        case .transport(let e): return "网络错误: \(e.localizedDescription)"
        case .loginExpired: return "登录已失效，请重新扫码"
        }
    }
}

public final class UUHTTPClient: @unchecked Sendable {
    public var credentials: UUCredentials
    public var platform: String
    private let session: URLSession

    public init(credentials: UUCredentials, platform: String = UUAPIConfig.platformTV, session: URLSession = .shared) {
        self.credentials = credentials
        self.platform = platform
        self.session = session
    }

    public func getJSON<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        try await request(method: "GET", path: path, body: nil, as: type)
    }

    public func postJSON<T: Decodable>(_ path: String, body: Any? = [:], as type: T.Type = T.self) async throws -> T {
        try await request(method: "POST", path: path, body: body, as: type)
    }

    public func postEmptyJSON<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        try await request(method: "POST", path: path, body: [:], as: type)
    }

    private func request<T: Decodable>(method: String, path: String, body: Any?, as: T.Type) async throws -> T {
        guard let url = URL(string: path, relativeTo: UUAPIConfig.baseURL) else { throw UUHTTPError.badURL }
        var bodyStr = ""
        var httpBody: Data?
        if let body {
            let data = try JSONSerialization.data(withJSONObject: body, options: [])
            httpBody = data
            bodyStr = String(data: data, encoding: .utf8) ?? ""
        } else if method.uppercased() == "POST" {
            // Some guest endpoints sign empty body; device list uses GET.
        }

        let ts = String(Int(Date().timeIntervalSince1970))
        var params: [String: String] = [
            "x-param-plat": platform,
            "x-param-vn": UUAPIConfig.versionName,
            "x-param-vc": UUAPIConfig.versionCode,
            "x-param-pkgn": UUAPIConfig.packageName,
            "x-param-chn": UUAPIConfig.channel,
            "x-param-lang": "zh-CN",
            "x-param-cnt": "CN",
            "x-param-ts": ts
        ]
        if !credentials.clientId.isEmpty { params["x-param-client-id"] = credentials.clientId }
        if !credentials.deviceId.isEmpty { params["x-param-device-id"] = credentials.deviceId }
        if !credentials.systemId.isEmpty { params["x-param-system-id"] = credentials.systemId }
        if !credentials.userId.isEmpty { params["x-param-user-id"] = credentials.userId }

        let sign = UUHMACSigner.sign(
            method: method,
            path: path,
            paramHeaders: params,
            body: bodyStr,
            key: credentials.signKey
        )

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("UURemoteTV/0.1 (tvOS; unofficial)", forHTTPHeaderField: "User-Agent")
        if httpBody != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = httpBody
        }
        if !credentials.token.isEmpty {
            req.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
            req.setValue(
                "nrd_access_token=\(credentials.token); nrd_csrf_access_token=\(credentials.csrf)",
                forHTTPHeaderField: "Cookie"
            )
            if !credentials.csrf.isEmpty {
                req.setValue(credentials.csrf, forHTTPHeaderField: "X-CSRF-TOKEN")
            }
        }
        for (k, v) in params { req.setValue(v, forHTTPHeaderField: k) }
        req.setValue(sign, forHTTPHeaderField: "X-Param-SIGN")

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw UUHTTPError.transport(error)
        }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let envelope: UUAPIEnvelope<T>
        do {
            envelope = try JSONDecoder().decode(UUAPIEnvelope<T>.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw UUHTTPError.httpStatus(status, String(raw.prefix(200)))
        }
        if envelope.code == Int(UUAPIConfig.tokenInvalidCode) {
            throw UUHTTPError.loginExpired
        }
        guard status == 200, envelope.code == 0, let payload = envelope.data else {
            throw UUHTTPError.apiCode(envelope.code, envelope.msg)
        }
        return payload
    }
}

/// Extract csrf claim from JWT access token (payload only; no signature verify).
public enum UUJWT {
    public static func csrf(from token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        let pad = (4 - payload.count % 4) % 4
        payload += String(repeating: "=", count: pad)
        guard let data = Data(base64Encoded: payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let csrf = obj["csrf"] as? String else { return nil }
        return csrf
    }
}
