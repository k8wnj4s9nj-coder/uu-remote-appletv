import Foundation
import SwiftUI
// Protocol sources are compiled into this target

@MainActor
final class AppModel: ObservableObject {
    enum Route: Equatable {
        case login
        case devices
        case session(UUDevice)
    }

    @Published var route: Route = .login
    @Published var credentials: UUCredentials?
    @Published var devices: [UUDevice] = []
    @Published var statusText: String = ""
    @Published var errorText: String?
    @Published var qrContent: String?
    @Published var loginPhaseLabel: String = "准备登录…"
    @Published var sessionState: String = ""
    @Published var videoTrack: Any? = nil

    private var loginTask: Task<Void, Never>?
    private var remoteSession: UURemoteSession?

    init() {
        if let saved = UUCredentialStore.load(), saved.isLoggedIn {
            credentials = saved
            route = .devices
            Task { await refreshDevices() }
        } else {
            route = .login
        }
    }

    func startLogin() {
        loginTask?.cancel()
        errorText = nil
        qrContent = nil
        loginPhaseLabel = "准备设备身份…"
        let service = UULoginService(credentials: credentials ?? UUCredentials())
        loginTask = Task { [weak self] in
            guard let self else { return }
            do {
                let creds = try await service.runQRLogin { phase in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        switch phase {
                        case .preparingDevice:
                            self.loginPhaseLabel = "注册 Apple TV 设备…"
                        case .waitingScan(let url):
                            self.qrContent = url
                            self.loginPhaseLabel = "请用手机「网易UU远程」扫码"
                        case .scannedConfirmOnPhone:
                            self.loginPhaseLabel = "已扫码，请在手机上确认"
                        case .exchangingToken:
                            self.loginPhaseLabel = "正在换取登录令牌…"
                        case .succeeded(let name):
                            self.loginPhaseLabel = "登录成功：\(name)"
                        case .expiredRefreshing:
                            self.loginPhaseLabel = "二维码过期，正在刷新…"
                        case .failed(let msg):
                            self.errorText = msg
                        }
                    }
                }
                self.credentials = creds
                self.route = .devices
                await self.refreshDevices()
            } catch is CancellationError {
                // ignore
            } catch {
                self.errorText = error.localizedDescription
                self.loginPhaseLabel = "登录失败"
            }
        }
    }

    func cancelLogin() {
        loginTask?.cancel()
        loginTask = nil
    }

    func refreshDevices() async {
        guard let credentials else { return }
        errorText = nil
        statusText = "刷新设备列表…"
        do {
            let svc = UUDeviceService(credentials: credentials)
            let list = try await svc.fetchDeviceList()
            devices = list.allRemoteHosts
            statusText = "共 \(devices.count) 台设备（非官方客户端）"
        } catch {
            errorText = error.localizedDescription
            statusText = "刷新失败"
        }
    }

    func logout() {
        remoteSession?.disconnect()
        remoteSession = nil
        UUCredentialStore.clear()
        credentials = nil
        devices = []
        route = .login
        qrContent = nil
    }

    func openSession(to device: UUDevice) {
        guard let credentials else { return }
        route = .session(device)
        sessionState = "正在加入房间…"
        let session = UURemoteSession(credentials: credentials)
        remoteSession = session
        session.onState = { [weak self] s in
            Task { @MainActor in self?.sessionState = s }
        }
        session.onVideoTrack = { [weak self] track in
            Task { @MainActor in self?.videoTrack = track }
        }
        Task {
            do {
                try await session.connectViewOnly(to: device)
            } catch {
                sessionState = "连接失败：\(error.localizedDescription)"
            }
        }
    }

    func closeSession() {
        remoteSession?.disconnect()
        remoteSession = nil
        videoTrack = nil
        route = .devices
        Task { await refreshDevices() }
    }
}
