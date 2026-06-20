import AppKit
import SwiftUI

@main
struct PopoverPreviewRenderer {
    @MainActor
    static func main() {
        let output = CommandLine.arguments.dropFirst().first
            ?? "/Users/abo/Desktop/土豆大王/hermes-agent-popover-preview.png"
        NSApplication.shared.setActivationPolicy(.accessory)
        let model = previewModel()
        let view = PopoverView(model: model)
            .frame(width: DashboardStyle.popoverWidth, height: DashboardStyle.popoverHeight)
            .environment(\.colorScheme, .light)

        let size = NSSize(width: DashboardStyle.popoverWidth, height: DashboardStyle.popoverHeight)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.setFrameSize(size)

        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -10_000, y: -10_000), size: size),
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        window.contentView = hostingView
        window.orderFront(nil)

        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            fatalError("Failed to create bitmap representation")
        }
        rep.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            fatalError("Failed to encode popover preview")
        }
        try! png.write(to: URL(fileURLWithPath: output))
        print(output)
    }

    @MainActor
    private static func previewModel() -> SystemStatsModel {
        let model = SystemStatsModel()
        model.hermesUsageAvailable = true
        model.hermesTodayTokens = 824_000
        model.hermesTodaySeconds = 3720
        model.hermesTodayTokensText = "今日 824K tok"
        model.hermesTodayDurationText = "1小时2分"

        model.codexUsageAvailable = true
        model.codexPlanType = "Pro"
        model.codexTodayTokens = 824_000
        model.codexTodayTokensText = "今日 824K tok"
        model.codexFiveHourRemainingPct = 95
        model.codexFiveHourResetText = "3 小时后"
        model.codexWeeklyRemainingPct = 74
        model.codexWeeklyResetText = "6 天后"

        model.cpuUsage = 56
        model.gpuUsage = 82
        model.storagePctPrecise = 50.6
        model.cpuUsageHistory = [18, 24, 33, 39, 45, 51, 62, 58, 54, 60, 57, 53, 56]
        model.gpuUsageHistory = [38, 45, 51, 59, 68, 76, 84, 79, 73, 88, 82, 80, 82]
        model.storagePctHistory = [48, 49, 49.5, 50, 50.6]

        model.cpuTemp = 52
        model.gpuTemp = 49
        model.cpuDieHotspot = 68
        model.fanRPM = 2314
        model.fanReasons = [
            "当前窗口渲染：Codex · WindowServer",
            "系统后台任务：syspolicyd · kernel_task",
            "图形处理器负载：41%，可能是窗口渲染"
        ]
        model.fanStopAdvice = "不建议：主要是系统进程"

        model.batteryPct = 97
        model.batteryOnAC = true
        model.batteryCharging = false
        model.chargerInputWatts = 112.0
        model.totalPower = 52.0
        model.energyMeterPowerWatts = 0.1
        model.energyMeterKWh = 0.063
        model.energyMeterCycleDays = 4
        model.chargerInputHistory = [18, 38, 52, 74, 96, 112, 108, 116, 110]
        model.chipPowerHistory = [12, 18, 28, 36, 44, 58, 49, 55, 52]

        model.netInBps = 2 * 1024
        model.netOutBps = 1024
        model.currentCountry = "美国"

        model.pocketWiFiStatus = PocketWiFiStatus(
            available: true,
            networkType: "LTE",
            carrier: "CMCC",
            connectStatus: "已联网",
            signalBars: 5,
            signalDBm: nil,
            batteryPct: 100,
            isCharging: false,
            connectedDevices: 1,
            deviceNames: ["Abo MacBook"],
            ssid: "阿波的随身WIFI",
            monthlyReceivedBytes: 395_650_000_000,
            monthlySentBytes: 0,
            updatedAt: Date(),
            errorText: ""
        )
        UserDefaults.standard.set("600000000000", forKey: "pocketWiFi.monthlyLimitBytes")
        UserDefaults.standard.set("609474439869", forKey: "pocketWiFi.monthlyRouterBaselineBytes")
        UserDefaults.standard.set("395650000000", forKey: "pocketWiFi.monthlyDisplayBaselineBytes")
        return model
    }
}
