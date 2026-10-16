import SwiftUI
// Protocol sources are compiled into this target

struct SessionView: View {
    @EnvironmentObject private var model: AppModel
    let device: UUDevice

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if model.videoTrack != nil {
                RemoteVideoView(track: model.videoTrack)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    Text(device.displayName).font(.title.bold())
                    Text("非官方 · 等待远端画面")
                        .foregroundStyle(.orange)
                    Text(model.sessionState)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                    if !uuWebRTCLinked {
                        Text("当前构建未链接 WebRTC 二进制（见 README）")
                            .font(.footnote)
                            .foregroundStyle(.yellow)
                    }
                }
            }

            VStack {
                HStack {
                    Text(uuWebRTCLinked ? "UU 远程 TV · 非官方" : "UU 远程 TV · 非官方（无 WebRTC）")
                        .font(.caption)
                        .padding(8)
                        .background(.black.opacity(0.5))
                        .cornerRadius(8)
                    Spacer()
                    Button("断开") { model.closeSession() }
                }
                .padding(24)
                Spacer()
                if model.videoTrack != nil {
                    Text(model.sessionState)
                        .font(.caption2)
                        .padding(8)
                        .background(.black.opacity(0.4))
                        .cornerRadius(6)
                        .padding(.bottom, 24)
                }
            }
        }
    }
}
