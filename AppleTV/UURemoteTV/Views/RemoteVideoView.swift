import SwiftUI
import UIKit

#if canImport(LiveKitWebRTC) || canImport(WebRTC)

#if canImport(LiveKitWebRTC)
import LiveKitWebRTC
typealias _Track = LKRTCVideoTrack
typealias _View = LKRTCMTLVideoView
#elseif canImport(WebRTC)
import WebRTC
typealias _Track = RTCVideoTrack
typealias _View = RTCMTLVideoView
#endif

struct RemoteVideoView: UIViewRepresentable {
    let track: Any?

    func makeUIView(context: Context) -> _View {
        let v = _View(frame: .zero)
        v.contentMode = .scaleAspectFit
#if canImport(LiveKitWebRTC)
        // LKRTCMTLVideoView is LiveKit's Metal renderer (not LKRTCVideoView)
#endif
        return v
    }

    func updateUIView(_ uiView: _View, context: Context) {
        guard let track = track as? _Track else { return }
        if context.coordinator.bound !== track {
            context.coordinator.bound?.remove(uiView)
            track.add(uiView)
            context.coordinator.bound = track
        }
    }

    static func dismantleUIView(_ uiView: _View, coordinator: Coordinator) {
        coordinator.bound?.remove(uiView)
        coordinator.bound = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var bound: _Track?
    }
}

#else

struct RemoteVideoView: View {
    let track: Any?
    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                Text("WebRTC 未链接")
                Text("本构建暂无 WebRTC 画面，登录与设备列表可用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#endif
