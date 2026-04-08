import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var wallpaperWindows: [NSWindow] = []
    var animationController = AnimationController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupWallpaperWindows()
    }

    // MARK: - MenuBar

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Dynamic Wallpaper")
        }

        buildMenu()
    }

    func buildMenu() {
        let menu = NSMenu()

        // Preset section
        let presetTitle = NSMenuItem(title: "Preset", action: nil, keyEquivalent: "")
        presetTitle.isEnabled = false
        menu.addItem(presetTitle)

        for preset in AnimationPreset.allCases {
            let item = NSMenuItem(
                title: preset.displayName,
                action: #selector(selectPreset(_:)),
                keyEquivalent: ""
            )
            item.representedObject = preset
            item.target = self
            if animationController.currentPreset == preset {
                item.state = .on
            }
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // Speed
        let speedItem = NSMenuItem(title: "Speed: \(Int(animationController.speed * 100))%", action: nil, keyEquivalent: "")
        speedItem.isEnabled = false
        menu.addItem(speedItem)

        let slowerItem = NSMenuItem(title: "  ◀ Slower", action: #selector(decreaseSpeed), keyEquivalent: "")
        slowerItem.target = self
        menu.addItem(slowerItem)

        let fasterItem = NSMenuItem(title: "  Faster ▶", action: #selector(increaseSpeed), keyEquivalent: "")
        fasterItem.target = self
        menu.addItem(fasterItem)

        menu.addItem(.separator())

        // Toggle
        let toggleItem = NSMenuItem(
            title: animationController.isRunning ? "Pause" : "Resume",
            action: #selector(toggleAnimation),
            keyEquivalent: "p"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Wallpaper Windows

    func setupWallpaperWindows() {
        wallpaperWindows.removeAll()

        for screen in NSScreen.screens {
            let window = makeWallpaperWindow(for: screen)
            wallpaperWindows.append(window)
            window.orderBack(nil)
        }
    }

    func makeWallpaperWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.backgroundColor = .black

        let metalView = MetalAnimationView(
            frame: screen.frame,
            controller: animationController
        )
        window.contentView = metalView

        window.makeKeyAndOrderFront(nil)
        return window
    }

    // MARK: - Actions

    @objc func selectPreset(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? AnimationPreset else { return }
        animationController.currentPreset = preset
        buildMenu()
    }

    @objc func decreaseSpeed() {
        animationController.speed = max(0.1, animationController.speed - 0.1)
        buildMenu()
    }

    @objc func increaseSpeed() {
        animationController.speed = min(3.0, animationController.speed + 0.1)
        buildMenu()
    }

    @objc func toggleAnimation() {
        animationController.isRunning.toggle()
        buildMenu()
    }
}
