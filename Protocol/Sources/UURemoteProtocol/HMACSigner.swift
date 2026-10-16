import Foundation
import CryptoKit

/// NRD request signing: HMAC-SHA256 over `METHOD + path + sorted(x-param-*) + body`.
public enum UUHMACSigner {
    public static func sign(
        method: String,
        path: String,
        paramHeaders: [String: String],
        body: String,
        key: String
    ) -> String {
        var filtered: [(String, String)] = []
        for (k, v) in paramHeaders {
            let kl = k.lowercased()
            if kl.hasPrefix("x-param-"), kl != "x-param-sign" {
                filtered.append((kl, v))
            }
        }
        filtered.sort { $0.0 < $1.0 }
        let paramsStr = filtered.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        let stringToSign = "\(method.uppercased())\(path)\(paramsStr)\(body)"
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data(stringToSign.utf8),
            using: SymmetricKey(data: Data(key.utf8))
        )
        return mac.map { String(format: "%02x", $0) }.joined()
    }
}
