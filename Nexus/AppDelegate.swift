import AppKit
import SwiftUI
import Combine
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?
    var popover    = NSPopover()
    var welcomeWin: NSWindow?
    let model      = SystemStatsModel()

    // Subscribe to model changes so the label updates in sync with each tick,
    // not on a separate independent timer that may fire before data is ready.
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()
        model.startMonitoring()

        // Drive the label from published model values — fires immediately on change
        Publishers.CombineLatest3(model.$cpuUsage, model.$gpuUsage, model.$storagePct)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cpu, gpu, storage in
                self?.updateLabel(cpu: cpu, gpu: gpu, storage: storage)
            }
            .store(in: &cancellables)

        // Restore Open at Login state on launch
        if UserDefaults.standard.bool(forKey: "openAtLogin") {
            try? SMAppService.mainApp.register()
        }

        // Show welcome window on very first launch
        if !UserDefaults.standard.bool(forKey: "hasLaunched") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showWelcomeWindow()
            }
        }

        // Check for updates in the background — non-blocking
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 5.0) {
            UpdateChecker.shared.check()
        }
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: 26)
        if let btn = statusItem?.button {
            btn.title = ""
            btn.image = statusIcon(cpu: 0, gpu: 0, storage: 0)
            btn.imagePosition = .imageOnly
            btn.contentTintColor = nil
            btn.toolTip = "Nexus"
            btn.setAccessibilityLabel("Nexus")
            btn.target = self
            btn.action = #selector(handleClick)
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.contentSize = NSSize(width: 280, height: 500)
        popover.behavior    = .transient
        popover.animates    = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(model: model).preferredColorScheme(.light)
        )
    }

    private func updateLabel(cpu: Int, gpu: Int, storage: Int) {
        guard let btn = statusItem?.button else { return }
        btn.title = ""
        btn.image = statusIcon(cpu: cpu, gpu: gpu, storage: storage)
        btn.imagePosition = .imageOnly
        btn.contentTintColor = nil
        btn.toolTip = "处理器 \(cpu)%  图形 \(gpu)%  存储 \(storage)%"
        btn.setAccessibilityLabel("Nexus")
    }

    private func statusIcon(cpu: Int, gpu: Int, storage: Int) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(x: 1.4, y: 1.4, width: size.width - 2.8, height: size.height - 2.8)
        let bg = NSBezierPath(roundedRect: rect, xRadius: 4.6, yRadius: 4.6)
        NSColor(calibratedWhite: 1.0, alpha: 0.34).setFill()
        bg.fill()
        NSColor(calibratedWhite: 1.0, alpha: 0.44).setStroke()
        bg.lineWidth = 0.7
        bg.stroke()

        drawStackedMetric(label: "C", value: cpu, color: NSColor.systemGreen, y: 14.8)
        drawStackedMetric(label: "G", value: gpu, color: NSColor.systemOrange, y: 9.2)
        drawStackedMetric(label: "S", value: storage, color: NSColor.systemPurple, y: 3.6)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func drawStackedMetric(label: String, value: Int, color: NSColor, y: CGFloat) {
        let pct = max(0, min(value, 100))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 5.8, weight: .bold),
            .foregroundColor: NSColor(calibratedWhite: 0.10, alpha: 0.88)
        ]
        label.draw(at: NSPoint(x: 3.8, y: y - 1.4), withAttributes: attrs)

        let track = NSRect(x: 10.0, y: y + 0.2, width: 8.9, height: 2.35)
        NSColor(calibratedWhite: 0.0, alpha: 0.11).setFill()
        NSBezierPath(roundedRect: track, xRadius: 1.2, yRadius: 1.2).fill()

        let fillWidth = max(2, CGFloat(pct) / 100 * track.width)
        let fill = NSRect(x: track.minX, y: track.minY, width: fillWidth, height: track.height)
        color.setFill()
        NSBezierPath(roundedRect: fill, xRadius: 1.15, yRadius: 1.15).fill()
    }

    // MARK: - Click handling

    @objc func handleClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开状态面板",
                                action: #selector(openPopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "设置…",
                                action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 Nexus",
                                action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc func openPopover() {
        if let btn = statusItem?.button { togglePopover(btn) }
    }

    // MARK: - Welcome window

    func showWelcomeWindow() {
        let win = NSWindow(
            contentRect:  NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask:    [.titled, .closable, .fullSizeContentView],
            backing:      .buffered,
            defer:        false
        )
        win.titlebarAppearsTransparent  = true
        win.titleVisibility             = .hidden
        win.isMovableByWindowBackground = true
        win.backgroundColor             = NSColor(Color(hex: "0E0E12"))
        win.contentViewController       = NSHostingController(rootView: WelcomeView())
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        welcomeWin = win
    }

    // MARK: - Settings window

    @objc func openSettings() {
        let win = NSWindow(
            contentRect:  NSRect(x: 0, y: 0, width: 320, height: 280),
            styleMask:    [.titled, .closable, .fullSizeContentView],
            backing:      .buffered,
            defer:        false
        )
        win.title                      = "Nexus 设置"
        win.titlebarAppearsTransparent = true
        win.backgroundColor            = NSColor(Color(hex: "1C1C1E"))
        win.contentViewController      = NSHostingController(
            rootView: SettingsSheet(isPresented: .constant(true))
                .preferredColorScheme(.dark)
        )
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
