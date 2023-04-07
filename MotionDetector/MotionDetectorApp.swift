import SwiftUI


/// A delegate whose sole purpose is to terminate the application after closing the window.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        true
    }
}

@main
struct MotionDetectorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}
