import SwiftUI
import AppKit

@main
struct DynamicWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(controller: appDelegate.animationController)
        }
    }
}
