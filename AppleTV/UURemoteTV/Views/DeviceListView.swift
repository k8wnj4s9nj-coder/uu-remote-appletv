import SwiftUI
// Protocol sources are compiled into this target

struct DeviceListView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("我的设备")
                            .font(.largeTitle.bold())
                        Text("非官方 Apple TV 控制端 · 仅画面（里程碑 1）")
                            .foregroundStyle(.secondary)
                        if let name = model.credentials?.accountName {
                            Text("账号：\(name)").font(.caption)
                        }
                    }
                    Spacer()
                    Button("刷新") { Task { await model.refreshDevices() } }
                    Button("退出登录") { model.logout() }
                }

                Text(model.statusText).font(.footnote).foregroundStyle(.secondary)
                if let err = model.errorText {
                    Text(err).foregroundStyle(.red)
                }

                if model.devices.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tv").font(.system(size: 48))
                        Text("暂无设备").font(.title2)
                        Text("请确认本机 uuremote-server 已在线，或官方客户端里已有绑定主机。")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(model.devices) { device in
                        Button {
                            model.openSession(to: device)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(device.displayName).font(.headline)
                                    Text("\(device.statusLabel) · \(device.versionName ?? "")")
                                        .font(.caption)
                                        .foregroundStyle(device.isOnline ? .green : .secondary)
                                }
                                Spacer()
                                Text(device.isOnline ? "连接观看" : "离线")
                                    .foregroundStyle(device.isOnline ? .primary : .secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .disabled(!device.isOnline)
                    }
                }
            }
            .padding(40)
        }
        .task { await model.refreshDevices() }
    }
}
