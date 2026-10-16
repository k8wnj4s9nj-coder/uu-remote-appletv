import Foundation

/// NetEase UU Remote (网易UU远程) cloud API constants.
/// Unofficial reverse-engineered values from public clients / open host implementations.
public enum UUAPIConfig {
    public static let baseURL = URL(string: "https://api.nrd.nie.163.com")!

    /// Built into the official UU PC client (`x-param-plat=1`). Same for every user.
    /// Override via Credentials.signKey if NetEase rotates it.
    public static let defaultSignKey = "alWiSzXZTLu3WfFnw13uBru3"

    /// Mimic a recent official desktop build for header compatibility.
    public static let versionName = "4.42.0.2770"
    public static let versionCode = "2770"
    public static let packageName = "com.netease.gameviewer"
    public static let channel = "gwqd"

    /// Website platform enum observed in host logs:
    /// 1 windows, 2 android, 3 ios, 4 macos, 5 tv
    public static let platformTV = "5"
    public static let platformMac = "4"
    public static let platformWindows = "1"

    public static let tokenInvalidCode: Int64 = 1120
    public static let qrExpiredCode: Int64 = 1190
}

public enum UUPath {
    public static let windowsInit = "/api/v1/device/windows/init"
    public static let macosInit = "/api/v1/device/macos/init"
    public static let qrGenLogin = "/api/v1/qrcode/gen/login"
    public static let qrLoginStatus = "/api/v1/qrcode/login/status"
    public static let loginByQRCode = "/api/v1/login/by_qrcode"
    public static let userInfo = "/api/v1/user/info"
    public static let userLogout = "/api/v1/user/logout"
    public static let deviceList = "/api/v1/device/list"
    public static let roomCreate = "/api/v1/room/create"
    /// Controller joins the host room: POST `/api/v1/room/join/by_device/{device_id}`
    public static func roomJoinByDevice(_ deviceId: String) -> String {
        "/api/v1/room/join/by_device/\(deviceId)"
    }
}
