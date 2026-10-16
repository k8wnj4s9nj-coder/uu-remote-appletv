import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct LoginView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 60) {
            VStack(alignment: .leading, spacing: 24) {
                Text("UU 远程 · Apple TV")
                    .font(.largeTitle.bold())
                Text("非官方客户端（Unofficial）")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text("与网易无关。仅用于个人互通研究；请使用你自己的 UU 账号扫码。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 520, alignment: .leading)

                Text(model.loginPhaseLabel)
                    .font(.headline)

                if let err = model.errorText {
                    Text(err).foregroundStyle(.red)
                }

                Button("开始扫码登录") { model.startLogin() }
                Button("取消") { model.cancelLogin() }
            }
            .focusSection()

            VStack {
                if let content = model.qrContent, let img = QRCodeImage.make(content) {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 360, height: 360)
                        .background(Color.white)
                        .cornerRadius(12)
                    Text("手机打开「网易UU远程」扫码")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 360, height: 360)
                        .overlay(Text("二维码区域").foregroundStyle(.secondary))
                }
            }
        }
        .padding(60)
        .onAppear {
            if model.qrContent == nil { model.startLogin() }
        }
    }
}

enum QRCodeImage {
    static func make(_ string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
