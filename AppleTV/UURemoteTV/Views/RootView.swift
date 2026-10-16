import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            switch model.route {
            case .login:
                LoginView()
            case .devices:
                DeviceListView()
            case .session(let device):
                SessionView(device: device)
            }
        }
        .preferredColorScheme(.dark)
    }
}
