import Foundation

public final class UUDeviceService: @unchecked Sendable {
    private let client: UUHTTPClient

    public init(credentials: UUCredentials) {
        self.client = UUHTTPClient(credentials: credentials, platform: UUAPIConfig.platformTV)
    }

    public func fetchDeviceList() async throws -> UUDeviceListData {
        try await client.getJSON(UUPath.deviceList, as: UUDeviceListData.self)
    }

    public func fetchUserInfo() async throws -> UUUserInfo {
        try await client.getJSON(UUPath.userInfo, as: UUUserInfo.self)
    }

    /// Controller joins the signaling room for a host device.
    public func joinRoom(deviceId: String) async throws -> UURoomCredentials {
        try await client.postJSON(UUPath.roomJoinByDevice(deviceId), body: [:], as: UURoomCredentials.self)
    }
}
