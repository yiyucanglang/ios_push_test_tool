import SwiftUI

@main
struct PushApp: App {
    @StateObject private var viewModel = PushViewModel()

    var body: some Scene {
        WindowGroup("APNs Push Tester") {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 640, minHeight: 560)
        }
        .windowToolbarStyle(.unifiedCompact)
    }
}
