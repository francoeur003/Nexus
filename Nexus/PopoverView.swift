import SwiftUI
import AppKit
import Combine
import ServiceManagement

// MARK: - Root

struct PopoverView: View {
    let model: SystemStatsModel
    @State private var snapshot: PopoverSnapshot
    private let uiTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    init(model: SystemStatsModel) {
        self.model = model
        _snapshot = State(initialValue: PopoverSnapshot(model))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DashboardStyle.outerSpacing) {
                Header(snapshot: snapshot)
                if snapshot.helperMissing {
                    HelperMissingBanner()
                }
                CompactStatusSection(snapshot: snapshot.compact)
                    .equatable()
            }
            .padding(.horizontal, DashboardStyle.contentPaddingX)
            .padding(.top, DashboardStyle.contentPaddingTop)
            .padding(.bottom, DashboardStyle.contentPaddingBottom)
        }
        .frame(width: DashboardStyle.popoverWidth)
        .background {
            ZStack {
                FrostedBackground()
                DashboardStyle.pageFill
            }
        }
        .onReceive(uiTimer) { _ in
            refreshSnapshot()
        }
    }

    private func refreshSnapshot() {
        let next = PopoverSnapshot(model)
        if next != snapshot {
            snapshot = next
        }
    }

    private var sep: some View {
        Rectangle()
            .fill(Color.black.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }
}

private struct PopoverSnapshot: Equatable {
    let helperMissing: Bool
    let chipName: String
    let thermalState: String
    let totalPower: Double
    let hermesUsageAvailable: Bool
    let hermesTodayTokensText: String
    let hermesTodayDurationText: String
    let compact: CompactStatusSnapshot

    init(_ model: SystemStatsModel) {
        helperMissing = model.helperMissing
        chipName = model.chipName
        thermalState = model.thermalState
        totalPower = model.totalPower
        hermesUsageAvailable = model.hermesUsageAvailable
        hermesTodayTokensText = model.hermesTodayTokensText
        hermesTodayDurationText = model.hermesTodayDurationText
        compact = CompactStatusSnapshot(model)
    }
}

private struct FrostedBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

enum DashboardStyle {
    static let popoverWidth: CGFloat = 280
    static let popoverHeight: CGFloat = 560
    static let outerSpacing: CGFloat = 6
    static let contentPaddingX: CGFloat = 10
    static let contentPaddingTop: CGFloat = 8
    static let contentPaddingBottom: CGFloat = 0

    static let panelRadius: CGFloat = 16
    static let tileRadius: CGFloat = 12
    static let compactRadius: CGFloat = 10
    static let sectionSpacing: CGFloat = 7
    static let tileSpacing: CGFloat = 6
    static let headerSpacing: CGFloat = 4
    static let panelPaddingX: CGFloat = 8
    static let panelPaddingY: CGFloat = 7
    static let densePanelPaddingY: CGFloat = 5
    static let systemStackSpacing: CGFloat = 3
    static let metricTilePaddingX: CGFloat = 6
    static let metricTilePaddingY: CGFloat = 2
    static let topCardHeight: CGFloat = 50
    static let headerChipHeight: CGFloat = 22
    static let statusPillHeight: CGFloat = 31
    static let primaryMetricHeight: CGFloat = 60
    static let secondaryMetricHeight: CGFloat = 21
    static let wifiMetricHeight: CGFloat = 32
    static let usageBarHeight: CGFloat = 6
    static let usageBarRadius: CGFloat = 4
    static let temperatureBandHeight: CGFloat = 17
    static let panelHeaderHeight: CGFloat = 20
    static let panelIconSize: CGFloat = 19
    static let heroIconWidth: CGFloat = 26
    static let heroIconHeight: CGFloat = 28
    static let statusDotSize: CGFloat = 8
    static let topCardPadding: CGFloat = 7
    static let topCardIconSize: CGFloat = 30
    static let statusPrimaryIconSize: CGFloat = 20
    static let statusSecondaryIconSize: CGFloat = 17
    static let statusNetWidth: CGFloat = 74
    static let statusBatteryWidth: CGFloat = 58
    static let metricIconWidth: CGFloat = 10
    static let primaryMetricIconWidth: CGFloat = 11
    static let sparklineHeight: CGFloat = 31
    static let secondaryMetricIconWidth: CGFloat = 11
    static let fanReasonIndexSize: CGFloat = 16
    static let fanReasonRowHeight: CGFloat = 25
    static let fanReasonProgressWidth: CGFloat = 44
    static let fanReasonProgressHeight: CGFloat = 4
    static let fanReasonPercentWidth: CGFloat = 26

    static let accentBlue = Color(hex: "2563EB")
    static let accentGreen = Color(hex: "18A957")
    static let accentPurple = Color(hex: "8C35F2")
    static let accentOrange = Color(hex: "F59E0B")
    static let accentCoral = Color(hex: "FF4B11")
    static let accentRed = Color(hex: "DC2626")
    static let accentYellow = Color(hex: "FFD60A")

    static let pageFill = Color(hex: "F8FBFF").opacity(0.92)
    static let panelFill = Color.white.opacity(0.86)
    static let tileFill = Color.white.opacity(0.74)
    static let raisedTileFill = Color.white.opacity(0.78)
    static let panelStroke = Color(hex: "DDE5F1").opacity(0.92)
    static let tileStroke = Color(hex: "E3E9F3")
    static let titleText = Color(hex: "111827")
    static let bodyText = Color(hex: "17213A")
    static let secondaryText = Color(hex: "5D6B88")
    static let mutedText = Color(hex: "94A3B8")
    static let track = Color(hex: "E7ECF5")
    static let shadow = Color(hex: "23314F").opacity(0.08)
    static let softBlueFill = Color(hex: "EAF1FF")
    static let successText = Color(hex: "15803D")
    static let warningText = Color(hex: "B45309")
    static let codexGreen = Color(hex: "12B765")
    static let usageBlue = Color(hex: "3E8FD8")
    static let usageTeal = Color(hex: "52A8B8")
    static let usageViolet = Color(hex: "6B7FE8")
    static let quotaWarning = Color(hex: "F05A24")
    static let quotaHealthy = Color(hex: "16A34A")
    static let brandGradient = LinearGradient(colors: [Color(hex: "6D6BFF"), Color(hex: "A829F4")],
                                              startPoint: .topLeading,
                                              endPoint: .bottomTrailing)
    static let usageNormalGradient = LinearGradient(colors: [accentBlue.opacity(0.68), accentBlue.opacity(0.82), accentGreen.opacity(0.72)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing)
    static let usageWarningGradient = LinearGradient(colors: [accentOrange, Color(hex: "F97316")],
                                                     startPoint: .leading,
                                                     endPoint: .trailing)
    static let usageDangerGradient = LinearGradient(colors: [accentRed, Color(hex: "F97316")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing)

    static let heroTitleFont = Font.system(size: 25, weight: .heavy)
    static let heroIconFont = Font.system(size: 20, weight: .heavy)
    static let headerMetaFont = Font.system(size: 12, weight: .semibold)
    static let headerMetaMonoFont = Font.system(size: 12, weight: .semibold, design: .monospaced)
    static let headerChipIconFont = Font.system(size: 8.8, weight: .bold)
    static let headerChipTitleFont = Font.system(size: 8.5, weight: .bold)
    static let headerChipCompactFont = Font.system(size: 7.4, weight: .heavy, design: .rounded)
    static let panelTitleFont = Font.system(size: 12.8, weight: .bold)
    static let panelIconFont = Font.system(size: 10, weight: .bold)
    static let wifiTitleFont = Font.system(size: 13, weight: .bold)
    static let wifiLinkArrowFont = Font.system(size: 7.5, weight: .heavy)
    static let topCardTitleFont = Font.system(size: 13, weight: .bold, design: .rounded)
    static let topCardIconFont = Font.system(size: 15, weight: .bold)
    static let topCardCaptionFont = Font.system(size: 8, weight: .semibold)
    static let quotaRingFont = Font.system(size: 8.5, weight: .heavy, design: .rounded)
    static let badgeFont = Font.system(size: 7.5, weight: .bold)
    static let tinyLabelFont = Font.system(size: 7.5, weight: .bold)
    static let smallLabelFont = Font.system(size: 8.5, weight: .bold)
    static let smallValueFont = Font.system(size: 9.2, weight: .heavy, design: .rounded)
    static let mediumValueFont = Font.system(size: 11, weight: .heavy, design: .rounded)
    static let primaryValueFont = Font.system(size: 12.8, weight: .heavy, design: .rounded)
    static let secondaryValueFont = Font.system(size: 9, weight: .heavy, design: .rounded)
    static let usagePercentFont = Font.system(size: 12, weight: .heavy, design: .rounded)
    static let usageDetailFont = Font.system(size: 8, weight: .bold)
    static let metricIconFont = Font.system(size: 8, weight: .bold)
    static let statusPrimaryIconFont = Font.system(size: 10, weight: .bold)
    static let statusSecondaryIconFont = Font.system(size: 8.5, weight: .bold)
    static let primaryMetricIconFont = Font.system(size: 10, weight: .bold)
    static let secondaryMetricIconFont = Font.system(size: 8.5, weight: .bold)
    static let axisLabelFont = Font.system(size: 5.8, weight: .semibold, design: .rounded)
    static let microTextFont = Font.system(size: 8.5, weight: .semibold)
    static let fanReasonFont = Font.system(size: 9.1, weight: .medium)
    static let fanAdviceFont = Font.system(size: 9.2, weight: .semibold)
    static let fanReasonIndexFont = Font.system(size: 10, weight: .semibold, design: .rounded)
    static let monoSmallFont = Font.system(size: 8.5, weight: .semibold, design: .monospaced)
}

// MARK: - Helper missing banner

private struct HelperMissingBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: "FF9F0A"))
                .font(.system(size: 11))
            VStack(alignment: .leading, spacing: 1) {
                Text("系统辅助程序未安装")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "FF9F0A"))
                Text("请使用一键安装命令或 Homebrew 重新安装，以启用图形、温度和功耗数据。")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "888899"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "FF9F0A").opacity(0.08))
    }
}

// MARK: - Header

private struct Header: View {
    let snapshot: PopoverSnapshot
    @ObservedObject private var recorder = RecordingController.shared

    var statusColor: Color {
        snapshot.hermesUsageAvailable ? DashboardStyle.accentGreen : DashboardStyle.accentYellow
    }

    private var audioTitle: String {
        if recorder.isPreparing { return "准备" }
        return recorder.isCallRecording ? "停止" : "监听"
    }

    private var audioIcon: String {
        recorder.isCallRecording ? "stop.fill" : "mic.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardStyle.headerSpacing) {
            HStack(alignment: .center, spacing: 7) {
                Image(systemName: "sparkle")
                    .font(DashboardStyle.heroIconFont)
                    .foregroundStyle(DashboardStyle.brandGradient)
                    .frame(width: DashboardStyle.heroIconWidth,
                           height: DashboardStyle.heroIconHeight)

                Text("Hermes Agent")
                    .font(DashboardStyle.heroTitleFont)
                    .foregroundColor(DashboardStyle.titleText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)

                Spacer(minLength: 0)
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: DashboardStyle.statusDotSize,
                           height: DashboardStyle.statusDotSize)
                Text("今日")
                    .font(DashboardStyle.headerMetaFont)
                    .foregroundColor(DashboardStyle.secondaryText)
                Text(snapshot.hermesTodayTokensText.replacingOccurrences(of: "今日 ", with: ""))
                    .font(DashboardStyle.headerMetaMonoFont)
                    .foregroundColor(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)
                Text("·")
                    .font(DashboardStyle.headerMetaFont)
                    .foregroundColor(DashboardStyle.mutedText)
                Text(snapshot.hermesTodayDurationText)
                    .font(DashboardStyle.headerMetaMonoFont)
                    .foregroundColor(DashboardStyle.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                HeaderCountryChip(country: snapshot.compact.currentCountry)
                HeaderActionButton(title: audioTitle,
                                   systemImage: audioIcon,
                                   tint: recorder.isCallRecording ? DashboardStyle.accentRed : DashboardStyle.accentGreen,
                                   isDisabled: recorder.isPreparing) {
                    recorder.toggleCallRecording()
                }
                .help("录制系统声音和麦克风，并打开 Hermes 会议翻译板")
                HeaderActionButton(title: "录屏",
                                   systemImage: "record.circle",
                                   tint: DashboardStyle.accentBlue,
                                   isDisabled: false) {
                    recorder.openScreenRecorderPicker()
                }
                .help("打开区域录屏选择器")
            }
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 2)
        .padding(.top, 1)
        .padding(.bottom, 5)
    }
}

private struct HeaderCountryChip: View {
    let country: String

    private var label: String {
        let trimmed = country.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "--" { return "国家" }
        if trimmed.localizedCaseInsensitiveContains("united states") { return "美国" }
        if trimmed.localizedCaseInsensitiveContains("china") { return "中国" }
        if trimmed.count > 3 { return String(trimmed.prefix(3)) }
        return trimmed
    }

    var body: some View {
        HeaderUtilityChip(title: label,
                          systemImage: "location.fill",
                          tint: DashboardStyle.accentPurple,
                          compactLabel: compactLabel,
                          showsTitle: false)
    }

    private var compactLabel: String {
        if label.hasPrefix("美") { return "美" }
        if label.hasPrefix("中") { return "中" }
        if label.hasPrefix("新") { return "新" }
        return String(label.prefix(1))
    }
}

private struct HeaderActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HeaderUtilityChip(title: title,
                              systemImage: systemImage,
                              tint: tint,
                              isDisabled: isDisabled,
                              showsTitle: false)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.62 : 1)
    }
}

private struct HeaderUtilityChip: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isDisabled = false
    var compactLabel: String? = nil
    var showsTitle = true

    private var chipWidth: CGFloat {
        showsTitle ? 38 : (compactLabel == nil ? 24 : 28)
    }

    var body: some View {
        HStack(spacing: showsTitle ? 3 : 2) {
            Image(systemName: systemImage)
                .font(DashboardStyle.headerChipIconFont)
                .foregroundColor(tint.opacity(isDisabled ? 0.55 : 1))
            if showsTitle {
                Text(title)
                    .font(DashboardStyle.headerChipTitleFont)
                    .foregroundColor(DashboardStyle.bodyText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            } else if let compactLabel {
                Text(compactLabel)
                    .font(DashboardStyle.headerChipCompactFont)
                    .foregroundColor(DashboardStyle.bodyText)
                    .lineLimit(1)
            }
        }
        .frame(width: chipWidth, height: DashboardStyle.headerChipHeight)
        .background(
            Capsule()
                .fill(DashboardStyle.tileFill)
                .overlay(Capsule().stroke(DashboardStyle.tileStroke, lineWidth: 0.8))
        )
    }
}

// MARK: - Compact status

private struct CompactStatusSnapshot: Equatable {
    let codexUsageAvailable: Bool
    let codexPlanType: String
    let codexTodayTokens: Int64
    let codexTodayTokensText: String
    let codexFiveHourRemainingPct: Int
    let codexFiveHourResetText: String
    let codexWeeklyRemainingPct: Int
    let codexWeeklyResetText: String
    let hermesUsageAvailable: Bool
    let hermesTodayTokens: Int64
    let hermesTodaySeconds: Double
    let hermesTodayDurationText: String
    let hermesTodayTokensHistory: [Double]
    let hermesTodaySecondsHistory: [Double]
    let hermesTokenRateHistory: [Double]
    let cpuUsage: Int
    let gpuUsage: Int
    let storagePctPrecise: Double
    let cpuUsageHistory: [Double]
    let gpuUsageHistory: [Double]
    let storagePctHistory: [Double]
    let cpuTemp: Double
    let gpuTemp: Double
    let cpuDieHotspot: Double
    let fanRPM: Int
    let fanReason: String
    let fanReasons: [String]
    let fanStopAdvice: String
    let batteryOnAC: Bool
    let batteryCharging: Bool
    let batteryCharged: Bool
    let chargerInputWatts: Double
    let totalPower: Double
    let energyMeterPowerWatts: Double
    let sampledEnergyKWh: Double
    let energyMeterCycleDays: Int
    let chargerInputHistory: [Double]
    let chipPowerHistory: [Double]
    let netInBps: Int64
    let netOutBps: Int64
    let currentCountry: String
    let batteryPct: Int
    let pocketWiFiStatus: PocketWiFiStatus

    init(_ model: SystemStatsModel) {
        codexUsageAvailable = model.codexUsageAvailable
        codexPlanType = model.codexPlanType
        codexTodayTokens = model.codexTodayTokens
        codexTodayTokensText = model.codexTodayTokensText
        codexFiveHourRemainingPct = model.codexFiveHourRemainingPct
        codexFiveHourResetText = model.codexFiveHourResetText
        codexWeeklyRemainingPct = model.codexWeeklyRemainingPct
        codexWeeklyResetText = model.codexWeeklyResetText
        hermesUsageAvailable = model.hermesUsageAvailable
        hermesTodayTokens = model.hermesTodayTokens
        hermesTodaySeconds = model.hermesTodaySeconds
        hermesTodayDurationText = model.hermesTodayDurationText
        hermesTodayTokensHistory = Self.chartSamples(model.hermesTodayTokensHistory)
        hermesTodaySecondsHistory = Self.chartSamples(model.hermesTodaySecondsHistory)
        hermesTokenRateHistory = Self.chartSamples(model.hermesTokenRateHistory)
        cpuUsage = model.cpuUsage
        gpuUsage = model.gpuUsage
        storagePctPrecise = model.storagePctPrecise
        cpuUsageHistory = Self.chartSamples(model.cpuUsageHistory)
        gpuUsageHistory = Self.chartSamples(model.gpuUsageHistory)
        storagePctHistory = Self.chartSamples(model.storagePctHistory)
        cpuTemp = model.cpuTemp
        gpuTemp = model.gpuTemp
        cpuDieHotspot = model.cpuDieHotspot
        fanRPM = model.fanRPM
        fanReason = model.fanReason
        fanReasons = model.fanReasons
        fanStopAdvice = model.fanStopAdvice
        batteryOnAC = model.batteryOnAC
        batteryCharging = model.batteryCharging
        batteryCharged = model.batteryCharged
        chargerInputWatts = model.chargerInputWatts
        totalPower = model.totalPower
        energyMeterPowerWatts = model.energyMeterPowerWatts
        sampledEnergyKWh = model.energyMeterKWh
        energyMeterCycleDays = model.energyMeterCycleDays
        chargerInputHistory = Self.chartSamples(model.chargerInputHistory)
        chipPowerHistory = Self.chartSamples(model.chipPowerHistory)
        netInBps = model.netInBps
        netOutBps = model.netOutBps
        currentCountry = model.currentCountry
        batteryPct = model.batteryPct
        pocketWiFiStatus = model.pocketWiFiStatus
    }

    var primaryTodayTokens: Int64 {
        hermesUsageAvailable && hermesTodayTokens > 0 ? hermesTodayTokens : codexTodayTokens
    }

    var primaryTodayTokensText: String {
        Self.compactCount(primaryTodayTokens)
    }

    var usageSourceText: String {
        hermesUsageAvailable && hermesTodayTokens > 0 ? "Hermes" : "Codex"
    }

    var runtimeValueText: String {
        hermesTodaySeconds > 0 ? Self.shortDuration(hermesTodaySeconds) : "--"
    }

    var tokenRateText: String {
        guard hermesUsageAvailable, hermesTodaySeconds > 0, hermesTodayTokens > 0 else { return "--" }
        return Self.compactRate(Double(hermesTodayTokens) / hermesTodaySeconds)
    }

    private static func chartSamples(_ values: [Double], maxPoints: Int = 96) -> [Double] {
        guard values.count > maxPoints else { return values }
        let bucketSize = Double(values.count) / Double(maxPoints)
        return (0..<maxPoints).map { index in
            let start = Int((Double(index) * bucketSize).rounded(.down))
            let end = min(values.count, Int((Double(index + 1) * bucketSize).rounded(.down)))
            let safeEnd = min(values.count, max(end, start + 1))
            let bucket = values[start..<safeEnd]
            return bucket.reduce(0, +) / Double(bucket.count)
        }
    }

    private static func compactCount(_ tokens: Int64) -> String {
        let value = Double(max(tokens, 0))
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.0fK", value / 1_000)
        }
        return "\(tokens)"
    }

    private static func shortDuration(_ seconds: Double) -> String {
        let total = Int(max(0, seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%dh%02dm", hours, minutes)
        }
        if minutes > 0 {
            return String(format: "%dm%02ds", minutes, secs)
        }
        return "\(secs)s"
    }

    private static func compactRate(_ value: Double) -> String {
        if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        if value >= 100 {
            return String(format: "%.0f", value)
        }
        if value >= 10 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", max(0, value))
    }

}

private struct CompactStatusSection: View, Equatable {
    let snapshot: CompactStatusSnapshot

    static func == (lhs: CompactStatusSection, rhs: CompactStatusSection) -> Bool {
        lhs.snapshot == rhs.snapshot
    }

    var chargeText: String {
        snapshot.batteryOnAC ? String(format: "%.1f W", snapshot.chargerInputWatts) : "0.0 W"
    }

    var fanText: String {
        snapshot.fanRPM > 0 ? "\(snapshot.fanRPM) RPM" : "无风扇"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardStyle.sectionSpacing) {
            TopMetricCards(snapshot: snapshot)

            SystemResourceCard(snapshot: snapshot)

            if snapshot.fanRPM > 0 {
                FanReasonPanel(reasons: snapshot.fanReasons, stopAdvice: snapshot.fanStopAdvice)
            }

            PocketWiFiStatusCard(status: snapshot.pocketWiFiStatus)
        }
    }
}

private struct PocketWiFiStatusCard: View {
    let status: PocketWiFiStatus

    private var accent: Color {
        status.available ? DashboardStyle.accentBlue : DashboardStyle.mutedText
    }

    private var titleText: String {
        let ssid = status.ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        if ssid.isEmpty { return "随身 WIFI" }
        if ssid.contains("阿波") { return "阿波随身 WIFI" }
        return ssid
    }

    private var signalColor: Color {
        guard status.available else { return DashboardStyle.mutedText }
        if status.signalBars >= 4 { return DashboardStyle.accentGreen }
        if status.signalBars >= 2 { return DashboardStyle.accentOrange }
        return DashboardStyle.accentRed
    }

    private var batteryColor: Color {
        guard let pct = status.batteryPct else { return DashboardStyle.mutedText }
        if status.isCharging { return DashboardStyle.accentGreen }
        if pct <= 20 { return DashboardStyle.accentRed }
        if pct <= 45 { return DashboardStyle.accentOrange }
        return DashboardStyle.accentBlue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardStyle.tileSpacing) {
            HStack(spacing: 7) {
                PanelIcon(systemImage: "wifi.router", tint: accent)

                Button {
                    if let url = URL(string: "https://192.168.0.1") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(titleText)
                            .font(DashboardStyle.wifiTitleFont)
                            .foregroundColor(DashboardStyle.titleText)
                            .lineLimit(1)
                        Image(systemName: "arrow.up.forward")
                            .font(DashboardStyle.wifiLinkArrowFont)
                            .foregroundColor(DashboardStyle.secondaryText)
                    }
                }
                .buttonStyle(.plain)
                .layoutPriority(1)

                Spacer(minLength: 0)

                PanelStatusPill(text: status.connectStatus, tint: accent)
            }

            HStack(spacing: DashboardStyle.tileSpacing) {
                PocketWiFiMetric(title: "网络",
                                 value: status.networkLabel,
                                 systemImage: "antenna.radiowaves.left.and.right",
                                 tint: DashboardStyle.accentBlue)
                PocketWiFiMetric(title: "信号",
                                 value: status.signalText,
                                 systemImage: "chart.bar.fill",
                                 tint: signalColor)
                PocketWiFiMetric(title: "电量",
                                 value: status.batteryText + (status.isCharging ? " 充" : ""),
                                 systemImage: "battery.75percent",
                                 tint: batteryColor)
                PocketWiFiMetric(title: "链入",
                                 value: status.deviceText,
                                 systemImage: "person.2.fill",
                                 tint: DashboardStyle.accentBlue)
            }

            PocketWiFiUsageBar(status: status)
        }
        .padding(.horizontal, DashboardStyle.panelPaddingX)
        .padding(.vertical, DashboardStyle.panelPaddingY)
        .background(SoftPanelBackground(cornerRadius: DashboardStyle.panelRadius))
    }
}

private struct PocketWiFiUsageBar: View {
    let status: PocketWiFiStatus
    @State private var shimmer = false

    private var fillColor: Color {
        if status.monthlyUsagePercent >= 100 { return DashboardStyle.accentRed }
        if status.monthlyUsagePercent >= 80 { return DashboardStyle.accentOrange }
        return DashboardStyle.usageBlue
    }

    private var fillGradient: LinearGradient {
        if status.monthlyUsagePercent >= 100 {
            return DashboardStyle.usageDangerGradient
        }
        if status.monthlyUsagePercent >= 80 {
            return DashboardStyle.usageWarningGradient
        }
        return DashboardStyle.usageNormalGradient
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text("本月流量")
                    .font(DashboardStyle.smallLabelFont)
                    .foregroundColor(DashboardStyle.secondaryText)
                Spacer(minLength: 0)
                Text(String(format: "%.0f%%", status.monthlyUsagePercent))
                    .font(DashboardStyle.usagePercentFont)
                    .foregroundColor(DashboardStyle.titleText)
                    .lineLimit(1)
                    .monospacedDigit()
                Text(status.monthlyUsageDetail)
                    .font(DashboardStyle.usageDetailFont)
                    .foregroundColor(DashboardStyle.accentBlue.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            GeometryReader { geo in
                let fillWidth = geo.size.width * CGFloat(status.monthlyProgress)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DashboardStyle.usageBarRadius)
                        .fill(DashboardStyle.track)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: DashboardStyle.usageBarRadius)
                            .fill(fillGradient)
                        if fillWidth > 36 {
                            RoundedRectangle(cornerRadius: DashboardStyle.usageBarRadius - 1)
                                .fill(Color.white.opacity(0.22))
                                .frame(width: 42)
                                .offset(x: shimmer ? fillWidth + 12 : -50)
                        }
                    }
                    .frame(width: fillWidth, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: DashboardStyle.usageBarRadius))
                }
            }
            .frame(height: DashboardStyle.usageBarHeight)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: DashboardStyle.tileRadius)
                .fill(DashboardStyle.tileFill)
                .overlay(RoundedRectangle(cornerRadius: DashboardStyle.tileRadius)
                    .stroke(DashboardStyle.tileStroke, lineWidth: 0.8))
        )
        .onAppear {
            shimmer = false
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 1.9).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
        }
    }
}

private struct PocketWiFiMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(DashboardStyle.metricIconFont)
                    .foregroundColor(tint)
                    .frame(width: DashboardStyle.metricIconWidth)
                Text(title)
                    .font(DashboardStyle.tinyLabelFont)
                    .foregroundColor(DashboardStyle.secondaryText)
                    .lineLimit(1)
            }

            Text(value)
                .font(DashboardStyle.smallValueFont)
                .foregroundColor(DashboardStyle.titleText)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .monospacedDigit()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: DashboardStyle.wifiMetricHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DashboardStyle.tileRadius)
                .fill(DashboardStyle.tileFill)
                .overlay(RoundedRectangle(cornerRadius: DashboardStyle.tileRadius)
                    .stroke(DashboardStyle.tileStroke, lineWidth: 0.8))
        )
    }
}

private struct TopMetricCards: View {
    let snapshot: CompactStatusSnapshot

    var body: some View {
        HStack(spacing: DashboardStyle.sectionSpacing) {
            CodexPlanMetricCard(snapshot: snapshot)
            CompactQuotaMetricCard(title: "5小时内",
                                   pct: snapshot.codexFiveHourRemainingPct,
                                   caption: snapshot.codexFiveHourResetText.isEmpty ? "4 小时后" : snapshot.codexFiveHourResetText,
                                   color: quotaColor(snapshot.codexFiveHourRemainingPct))
            CompactQuotaMetricCard(title: "周券",
                                   pct: snapshot.codexWeeklyRemainingPct,
                                   caption: snapshot.codexWeeklyResetText.isEmpty ? "2 天后" : snapshot.codexWeeklyResetText,
                                   color: DashboardStyle.accentPurple)
        }
    }

    private func quotaColor(_ remaining: Int) -> Color {
        if remaining <= 10 { return DashboardStyle.accentRed }
        if remaining <= 30 { return DashboardStyle.quotaWarning }
        return DashboardStyle.quotaHealthy
    }
}

private struct CodexPlanMetricCard: View {
    let snapshot: CompactStatusSnapshot

    private var planTitle: String {
        "Codex"
    }

    private var planBadgeText: String {
        let trimmed = snapshot.codexPlanType.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Pro" }
        if trimmed.localizedCaseInsensitiveContains("max") { return "Max" }
        if trimmed.localizedCaseInsensitiveContains("pro") { return "Pro" }
        if trimmed.localizedCaseInsensitiveContains("plus") { return "Plus" }
        return String(trimmed.prefix(4))
    }

    private var tokenText: String {
        snapshot.codexTodayTokensText
            .replacingOccurrences(of: "今日 ", with: "")
            .replacingOccurrences(of: "tokens", with: "tok")
            .replacingOccurrences(of: "token", with: "tok")
    }

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle().fill(DashboardStyle.codexGreen.opacity(0.12))
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(DashboardStyle.topCardIconFont)
                    .foregroundColor(DashboardStyle.codexGreen)
            }
            .frame(width: DashboardStyle.topCardIconSize, height: DashboardStyle.topCardIconSize)

            VStack(alignment: .leading, spacing: 1) {
                Text(planTitle)
                    .font(DashboardStyle.topCardTitleFont)
                    .foregroundColor(DashboardStyle.titleText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)
                Text(tokenText)
                    .font(DashboardStyle.monoSmallFont)
                    .foregroundColor(DashboardStyle.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Text(planBadgeText)
                    .font(DashboardStyle.badgeFont)
                    .foregroundColor(DashboardStyle.accentBlue)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .frame(height: 14)
                    .background(DashboardStyle.softBlueFill)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DashboardStyle.topCardPadding)
        .padding(.vertical, DashboardStyle.topCardPadding)
        .frame(maxWidth: .infinity, minHeight: DashboardStyle.topCardHeight)
        .background(SoftPanelBackground(cornerRadius: DashboardStyle.panelRadius))
    }
}

private struct CompactQuotaMetricCard: View {
    let title: String
    let pct: Int
    let caption: String
    let color: Color

    var body: some View {
        HStack(spacing: DashboardStyle.sectionSpacing) {
            ZStack {
                Circle().fill(color.opacity(0.12))
                CircularQuotaProgress(pct: pct, color: color)
                    .frame(width: DashboardStyle.topCardIconSize, height: DashboardStyle.topCardIconSize)
                Text("\(pct)%")
                    .font(DashboardStyle.quotaRingFont)
                    .foregroundColor(DashboardStyle.titleText)
                    .minimumScaleFactor(0.62)
            }
            .frame(width: DashboardStyle.topCardIconSize, height: DashboardStyle.topCardIconSize)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(pct)%")
                    .font(DashboardStyle.topCardTitleFont)
                    .foregroundColor(DashboardStyle.titleText)
                    .lineLimit(1)
                Text(title)
                    .font(DashboardStyle.topCardCaptionFont)
                    .foregroundColor(DashboardStyle.secondaryText)
                    .lineLimit(1)
                Text(caption)
                    .font(DashboardStyle.topCardCaptionFont.weight(.bold))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DashboardStyle.topCardPadding)
        .padding(.vertical, DashboardStyle.topCardPadding)
        .frame(maxWidth: .infinity, minHeight: DashboardStyle.topCardHeight)
        .background(SoftPanelBackground(cornerRadius: DashboardStyle.panelRadius))
    }
}

private struct CircularQuotaProgress: View {
    let pct: Int
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(DashboardStyle.track, lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(pct, 100))) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-92))
        }
    }
}

private struct InfoActionTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    var showChevron = false

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle().fill(tint.opacity(0.10))
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(hex: "5D6B88"))
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "111827"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "5D6B88"))
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(SoftPanelBackground(cornerRadius: 14))
    }
}

private struct SoftPanelBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DashboardStyle.panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DashboardStyle.panelStroke, lineWidth: 0.8)
            )
            .shadow(color: DashboardStyle.shadow, radius: 12, x: 0, y: 6)
    }
}

private struct PanelHeader: View {
    let title: String
    let systemImage: String
    let tint: Color
    var trailingText: String? = nil

    var body: some View {
        HStack(spacing: DashboardStyle.sectionSpacing) {
            PanelIcon(systemImage: systemImage, tint: tint)
            Text(title)
                .font(DashboardStyle.panelTitleFont)
                .foregroundColor(DashboardStyle.titleText)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let trailingText {
                PanelStatusPill(text: trailingText, tint: tint)
            }
        }
        .frame(height: DashboardStyle.panelHeaderHeight)
    }
}

private struct PanelIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.11))
            Image(systemName: systemImage)
                .font(DashboardStyle.panelIconFont)
                .foregroundColor(tint)
        }
        .frame(width: DashboardStyle.panelIconSize, height: DashboardStyle.panelIconSize)
    }
}

private struct PanelStatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(DashboardStyle.smallLabelFont)
            .foregroundColor(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 7)
            .frame(height: DashboardStyle.headerChipHeight - 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.09))
                    .overlay(Capsule().stroke(tint.opacity(0.12), lineWidth: 0.6))
            )
    }
}

private struct SystemMetricState {
    let label: String
    let tint: Color
}

private struct SystemResourceCard: View {
    let snapshot: CompactStatusSnapshot

    private var chargerValue: Double {
        snapshot.batteryOnAC ? snapshot.chargerInputWatts : 0
    }

    private var chargerDetail: String {
        if snapshot.batteryCharging { return "充电中" }
        if snapshot.batteryOnAC { return "外接" }
        return "电池"
    }

    private var energyReadingText: String {
        let kWh = max(0, snapshot.sampledEnergyKWh)
        if kWh < 1 {
            let wh = kWh * 1000
            return wh >= 10 ? String(format: "%.0fWh", wh) : String(format: "%.1fWh", wh)
        }
        if kWh < 10 {
            return String(format: "%.2fkWh", kWh)
        }
        return String(format: "%.1fkWh", kWh)
    }

    private var cpuState: SystemMetricState {
        performanceState(percent: snapshot.cpuUsage, activeAt: 45, highAt: 75, maxAt: 90)
    }

    private var gpuState: SystemMetricState {
        performanceState(percent: snapshot.gpuUsage, activeAt: 40, highAt: 70, maxAt: 88)
    }

    private var chargerState: SystemMetricState {
        if !snapshot.batteryOnAC {
            return SystemMetricState(label: "电池", tint: DashboardStyle.accentBlue)
        }
        if chargerValue >= 96 {
            return SystemMetricState(label: "高功率", tint: DashboardStyle.accentRed)
        }
        if chargerValue >= 45 {
            return SystemMetricState(label: "快充", tint: DashboardStyle.accentOrange)
        }
        if chargerValue >= 5 {
            return SystemMetricState(label: "充电中", tint: DashboardStyle.accentGreen)
        }
        return SystemMetricState(label: chargerDetail, tint: DashboardStyle.accentGreen)
    }

    private var chipState: SystemMetricState {
        if snapshot.totalPower >= 80 {
            return SystemMetricState(label: "过载", tint: DashboardStyle.accentRed)
        }
        if snapshot.totalPower >= 45 {
            return SystemMetricState(label: "高功耗", tint: DashboardStyle.accentOrange)
        }
        if snapshot.totalPower >= 18 {
            return SystemMetricState(label: "性能", tint: DashboardStyle.accentBlue)
        }
        return SystemMetricState(label: "省电", tint: DashboardStyle.accentGreen)
    }

    private func performanceState(percent: Int, activeAt: Int, highAt: Int, maxAt: Int) -> SystemMetricState {
        if percent >= maxAt {
            return SystemMetricState(label: "满载", tint: DashboardStyle.accentRed)
        }
        if percent >= highAt {
            return SystemMetricState(label: "高载", tint: DashboardStyle.accentOrange)
        }
        if percent >= activeAt {
            return SystemMetricState(label: "性能", tint: DashboardStyle.accentBlue)
        }
        return SystemMetricState(label: "轻载", tint: DashboardStyle.accentGreen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardStyle.systemStackSpacing) {
            PanelHeader(title: "系统资源",
                        systemImage: "speedometer",
                        tint: DashboardStyle.accentBlue)

            SystemPriorityStatusRow(fanRPM: snapshot.fanRPM,
                                    netInBps: snapshot.netInBps,
                                    netOutBps: snapshot.netOutBps,
                                    batteryPct: snapshot.batteryPct)

            HStack(spacing: DashboardStyle.systemStackSpacing) {
                PrimarySystemMetricTile(title: "CPU",
                                        systemImage: "cpu",
                                        value: "\(snapshot.cpuUsage)%",
                                        detail: cpuState.label,
                                        history: snapshot.cpuUsageHistory,
                                        unit: "%",
                                        fixedMax: nil,
                                        color: DashboardStyle.accentCoral,
                                        iconColor: cpuState.tint)
                PrimarySystemMetricTile(title: "GPU",
                                        systemImage: "cpu",
                                        value: "\(snapshot.gpuUsage)%",
                                        detail: gpuState.label,
                                        history: snapshot.gpuUsageHistory,
                                        unit: "%",
                                        fixedMax: nil,
                                        color: DashboardStyle.accentPurple,
                                        iconColor: gpuState.tint)
            }

            HStack(spacing: DashboardStyle.systemStackSpacing) {
                PrimarySystemMetricTile(title: "充电",
                                        systemImage: "bolt.fill",
                                        value: String(format: "%.1fW", chargerValue),
                                        detail: chargerState.label,
                                        history: snapshot.chargerInputHistory,
                                        unit: "W",
                                        fixedMax: nil,
                                        color: DashboardStyle.accentGreen,
                                        iconColor: chargerState.tint)
                PrimarySystemMetricTile(title: "芯片",
                                        systemImage: "cpu",
                                        value: String(format: "%.1fW", snapshot.totalPower),
                                        detail: chipState.label,
                                        history: snapshot.chipPowerHistory,
                                        unit: "W",
                                        fixedMax: nil,
                                        color: DashboardStyle.accentBlue,
                                        iconColor: chipState.tint)
            }

            HStack(spacing: DashboardStyle.systemStackSpacing) {
                SecondarySystemMetricPill(title: "SSD",
                                          value: String(format: "%.1f%%", snapshot.storagePctPrecise),
                                          detail: "健康",
                                          systemImage: "internaldrive",
                                          tint: DashboardStyle.accentBlue)
                SecondarySystemMetricPill(title: "用电表",
                                          value: energyReadingText,
                                          detail: "\(snapshot.energyMeterCycleDays)天",
                                          systemImage: "bolt.square",
                                          tint: DashboardStyle.accentPurple)
            }

            TemperatureBand(cpuTemp: snapshot.cpuTemp,
                            gpuTemp: snapshot.gpuTemp,
                            cpuDieHotspot: snapshot.cpuDieHotspot)
        }
        .padding(.horizontal, DashboardStyle.panelPaddingX)
        .padding(.vertical, DashboardStyle.densePanelPaddingY)
        .background(SoftPanelBackground(cornerRadius: DashboardStyle.panelRadius))
    }
}

private struct SystemPriorityStatusRow: View {
    let fanRPM: Int
    let netInBps: Int64
    let netOutBps: Int64
    let batteryPct: Int

    private var fanText: String {
        fanRPM > 0 ? "\(fanRPM) RPM" : "无风扇"
    }

    private var fanState: SystemMetricState {
        if fanRPM <= 0 {
            return SystemMetricState(label: "静音", tint: DashboardStyle.mutedText)
        }
        if fanRPM >= 5200 {
            return SystemMetricState(label: "满速", tint: DashboardStyle.accentRed)
        }
        if fanRPM >= 3600 {
            return SystemMetricState(label: "高转", tint: DashboardStyle.accentOrange)
        }
        if fanRPM >= 2200 {
            return SystemMetricState(label: "散热", tint: DashboardStyle.accentBlue)
        }
        return SystemMetricState(label: "安静", tint: DashboardStyle.accentGreen)
    }

    private static func shortB(_ bps: Int64) -> String {
        let value = Double(max(0, bps))
        if value >= 1_048_576 {
            return String(format: "%.1fM", value / 1_048_576)
        }
        if value >= 1_024 {
            return String(format: "%.0fK", value / 1_024)
        }
        return "\(Int(value))B"
    }

    var body: some View {
        HStack(spacing: DashboardStyle.systemStackSpacing) {
            SystemStatusPill(title: "风扇转速",
                             value: fanText,
                             systemImage: "fan",
                             tint: DashboardStyle.accentBlue,
                             iconTint: fanState.tint,
                             isPrimary: true)
                .frame(maxWidth: .infinity)

            SystemStatusPill(title: "网速",
                             value: "↓\(Self.shortB(netInBps)) ↑\(Self.shortB(netOutBps))",
                             systemImage: "wifi",
                             tint: DashboardStyle.accentGreen,
                             isPrimary: false)
                .frame(width: DashboardStyle.statusNetWidth)

            SystemStatusPill(title: "电池",
                             value: "\(batteryPct)%",
                             systemImage: "battery.75percent",
                             tint: DashboardStyle.accentCoral,
                             isPrimary: false)
                .frame(width: DashboardStyle.statusBatteryWidth)
        }
    }
}

private struct SystemStatusPill: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    var iconTint: Color? = nil
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: isPrimary ? 5 : 3) {
            ZStack {
                Circle().fill(tint.opacity(isPrimary ? 0.12 : 0.10))
                Image(systemName: systemImage)
                    .font(isPrimary ? DashboardStyle.statusPrimaryIconFont : DashboardStyle.statusSecondaryIconFont)
                    .foregroundColor(iconTint ?? tint)
            }
            .frame(width: isPrimary ? DashboardStyle.statusPrimaryIconSize : DashboardStyle.statusSecondaryIconSize,
                   height: isPrimary ? DashboardStyle.statusPrimaryIconSize : DashboardStyle.statusSecondaryIconSize)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(isPrimary ? DashboardStyle.smallLabelFont : DashboardStyle.tinyLabelFont)
                    .foregroundColor(DashboardStyle.secondaryText)
                    .lineLimit(1)
                Text(value)
                    .font(isPrimary ? DashboardStyle.mediumValueFont : DashboardStyle.smallValueFont)
                    .foregroundColor(DashboardStyle.titleText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, isPrimary ? 7 : 5)
        .frame(height: DashboardStyle.statusPillHeight)
        .background(
            RoundedRectangle(cornerRadius: DashboardStyle.tileRadius)
                .fill(DashboardStyle.tileFill)
                .overlay(RoundedRectangle(cornerRadius: DashboardStyle.tileRadius)
                    .stroke(DashboardStyle.tileStroke, lineWidth: 0.8))
        )
    }
}

private struct PrimarySystemMetricTile: View {
    let title: String
    let systemImage: String
    let value: String
    let detail: String
    let history: [Double]
    let unit: String
    let fixedMax: Double?
    let color: Color
    var iconColor: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: systemImage)
                            .font(DashboardStyle.primaryMetricIconFont)
                            .foregroundColor(iconColor ?? color)
                            .frame(width: DashboardStyle.primaryMetricIconWidth)
                        Text(title)
                            .font(DashboardStyle.smallLabelFont.weight(.bold))
                            .foregroundColor(DashboardStyle.titleText)
                            .lineLimit(1)
                    }
                    Text(detail)
                        .font(DashboardStyle.badgeFont)
                        .foregroundColor(color.opacity(0.86))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 5)
                        .frame(height: 13)
                        .background(color.opacity(0.09))
                        .clipShape(Capsule())
                }
                Spacer(minLength: 0)
                Text(value)
                    .font(DashboardStyle.primaryValueFont)
                    .foregroundColor(DashboardStyle.titleText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .monospacedDigit()
                    .frame(maxWidth: 52, alignment: .trailing)
            }
            SparklineView(values: history,
                          color: color,
                          unit: unit,
                          fixedMax: fixedMax,
                          timeLabel: "4h")
                .frame(height: DashboardStyle.sparklineHeight)
        }
        .padding(.horizontal, DashboardStyle.metricTilePaddingX)
        .padding(.vertical, DashboardStyle.metricTilePaddingY)
        .frame(maxWidth: .infinity, minHeight: DashboardStyle.primaryMetricHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DashboardStyle.tileRadius)
                .fill(DashboardStyle.raisedTileFill)
                .overlay(RoundedRectangle(cornerRadius: DashboardStyle.tileRadius)
                    .stroke(DashboardStyle.tileStroke, lineWidth: 0.8))
        )
    }
}

private struct SecondarySystemMetricPill: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(DashboardStyle.secondaryMetricIconFont)
                .foregroundColor(tint)
                .frame(width: DashboardStyle.secondaryMetricIconWidth)
            Text(title)
                .font(DashboardStyle.smallLabelFont)
                .foregroundColor(DashboardStyle.secondaryText)
                .lineLimit(1)
            Text(value)
                .font(DashboardStyle.secondaryValueFont)
                .foregroundColor(DashboardStyle.bodyText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()
            Spacer(minLength: 0)
            Text(detail)
                .font(DashboardStyle.badgeFont)
                .foregroundColor(tint)
                .lineLimit(1)
        }
        .padding(.horizontal, DashboardStyle.metricTilePaddingX)
        .frame(maxWidth: .infinity)
        .frame(height: DashboardStyle.secondaryMetricHeight)
        .background(
            RoundedRectangle(cornerRadius: DashboardStyle.compactRadius)
                .fill(DashboardStyle.tileFill)
                .overlay(RoundedRectangle(cornerRadius: DashboardStyle.compactRadius)
                    .stroke(DashboardStyle.tileStroke, lineWidth: 0.8))
        )
    }
}

private struct DecorativeSparkline: View {
    let color: Color
    var seed: Double = 50

    var body: some View {
        GeometryReader { geo in
            let normalized = CGFloat(max(8, min(seed, 100))) / 100
            let points = [
                CGPoint(x: 0, y: geo.size.height * (0.72 - normalized * 0.10)),
                CGPoint(x: geo.size.width * 0.18, y: geo.size.height * 0.66),
                CGPoint(x: geo.size.width * 0.34, y: geo.size.height * (0.48 + normalized * 0.15)),
                CGPoint(x: geo.size.width * 0.52, y: geo.size.height * 0.60),
                CGPoint(x: geo.size.width * 0.70, y: geo.size.height * (0.34 + normalized * 0.18)),
                CGPoint(x: geo.size.width, y: geo.size.height * (0.44 - normalized * 0.12))
            ]

            ZStack(alignment: .bottom) {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: geo.size.height))
                    points.forEach { path.addLine(to: $0) }
                    if let last = points.last {
                        path.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                    }
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.14), color.opacity(0.02)],
                                     startPoint: .top,
                                     endPoint: .bottom))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct ResourceMetricRow: View {
    let title: String
    let systemImage: String
    let pct: Double
    let color: Color
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 17)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "17213A"))
                .frame(width: 36, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "E7E9F0"))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.86), color],
                                             startPoint: .leading,
                                             endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(max(0, min(pct, 100))) / 100)
                }
            }
            .frame(height: 5)
            Text(value)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "17213A"))
                .frame(width: 36, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(height: 13)
    }
}

private struct TemperatureBand: View {
    let cpuTemp: Double
    let gpuTemp: Double
    let cpuDieHotspot: Double

    var body: some View {
        HStack(spacing: 7) {
            TemperatureBandItem(systemImage: "cpu", label: "CPU", temp: cpuTemp)
            TemperatureBandItem(systemImage: "display", label: "GPU", temp: gpuTemp)
            if cpuDieHotspot > 0 {
                TemperatureBandItem(systemImage: "flame.fill", label: "热点", temp: cpuDieHotspot)
            }
        }
    }
}

private struct TemperatureBandItem: View {
    let systemImage: String
    let label: String
    let temp: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(DashboardStyle.topCardCaptionFont)
                .foregroundColor(tempColor(temp))
            Text(label)
                .font(DashboardStyle.topCardCaptionFont)
                .foregroundColor(tempColor(temp))
            Text(String(format: "%.0f°C", temp))
                .font(DashboardStyle.monoSmallFont)
                .foregroundColor(tempColor(temp))
        }
        .padding(.horizontal, 6)
        .frame(height: DashboardStyle.temperatureBandHeight)
        .frame(maxWidth: .infinity)
        .background(tempColor(temp).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DashboardStyle.compactRadius - 2))
        .lineLimit(1)
        .minimumScaleFactor(0.68)
    }
}

private struct PowerTrendCard: View {
    let title: String
    let systemImage: String
    let value: Double
    let history: [Double]
    let color: Color

    private var deltaText: String {
        guard let first = history.first, first > 0.05 else { return "同步中" }
        let delta = (value - first) / first * 100
        let arrow = delta >= 0 ? "↑" : "↓"
        return String(format: "4h %@%.0f%%", arrow, abs(delta))
    }

    private var compactTitle: String {
        if title.contains("充电") { return "充电" }
        if title.contains("芯片") { return "芯片" }
        return title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 9)
                Text(compactTitle)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(hex: "17213A"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                TimeRangePill()
            }
            Text(String(format: "%.1fW", value))
                .font(.system(size: 15.5, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()
            Text(deltaText)
                .font(.system(size: 7.5, weight: .bold))
                .foregroundColor(color.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            PowerTrendChart(values: history, currentValue: value, color: color)
                .frame(height: 29)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 102, alignment: .topLeading)
        .background(SoftPanelBackground(cornerRadius: 14))
    }
}

private struct TimeRangePill: View {
    var body: some View {
        Text("4h")
            .font(.system(size: 7.5, weight: .bold, design: .rounded))
            .foregroundColor(Color(hex: "5D6B88"))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(width: 22, height: 15)
            .background(Color(hex: "EEF1F7"))
            .clipShape(Capsule())
            .layoutPriority(2)
    }
}

private struct PowerTrendChart: View {
    let values: [Double]
    let currentValue: Double
    let color: Color

    private var samples: [Double] {
        var cleaned = values.map { max(0, $0) }
        if cleaned.isEmpty {
            cleaned = [0, max(0, currentValue)]
        } else {
            cleaned[cleaned.count - 1] = max(0, currentValue)
        }
        return cleaned.count >= 2 ? cleaned : [0, 0]
    }

    private func chartUpperBound(for maxSample: Double) -> Double {
        let padded = maxSample * 1.15
        if padded <= 30 { return 30 }
        if padded <= 60 { return ceil(padded / 10) * 10 }
        if padded <= 120 { return ceil(padded / 20) * 20 }
        return ceil(padded / 50) * 50
    }

    private func smoothLinePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 2 else {
            points.dropFirst().forEach { path.addLine(to: $0) }
            return path
        }
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let mid = CGPoint(x: (previous.x + current.x) / 2,
                              y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: mid, control: previous)
            if index == points.count - 1 {
                path.addQuadCurve(to: current, control: current)
            }
        }
        return path
    }

    private func smoothAreaPath(points: [CGPoint], baseline: CGFloat) -> Path {
        var path = smoothLinePath(points: points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: baseline))
        path.addLine(to: CGPoint(x: first.x, y: baseline))
        path.closeSubpath()
        return path
    }

    var body: some View {
        GeometryReader { geo in
            let topInset: CGFloat = 3
            let bottomInset: CGFloat = 10
            let leftInset: CGFloat = 14
            let rightInset: CGFloat = 3
            let chartW = max(1, geo.size.width - leftInset - rightInset)
            let chartH = max(1, geo.size.height - topInset - bottomInset)
            let data = samples
            let maxValue = chartUpperBound(for: data.max() ?? 1)
            let tickValues = [maxValue, maxValue * 2 / 3, maxValue / 3, 0]
            let points = data.enumerated().map { index, value in
                CGPoint(x: leftInset + chartW * CGFloat(index) / CGFloat(max(data.count - 1, 1)),
                        y: topInset + chartH - chartH * CGFloat(max(0, min(value, maxValue)) / maxValue))
            }

            ZStack(alignment: .topLeading) {
                ForEach(0..<4, id: \.self) { row in
                    let y = topInset + chartH * CGFloat(row) / 3
                    Path { path in
                        path.move(to: CGPoint(x: leftInset, y: y))
                        path.addLine(to: CGPoint(x: leftInset + chartW, y: y))
                    }
                    .stroke(Color(hex: "D9DEE8"), lineWidth: 0.7)
                }
                ForEach(Array(tickValues.enumerated()), id: \.offset) { offset, tick in
                    if offset == 0 || offset == tickValues.count - 1 {
                        Text("\(Int(tick.rounded()))W")
                            .font(.system(size: 5.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "5D6B88"))
                            .position(x: 7, y: topInset + chartH * CGFloat((maxValue - tick) / maxValue))
                    }
                }
                smoothAreaPath(points: points, baseline: topInset + chartH)
                .fill(LinearGradient(colors: [color.opacity(0.18), color.opacity(0.02)],
                                     startPoint: .top,
                                     endPoint: .bottom))

                smoothLinePath(points: points)
                .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

                if let last = points.last {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                        .overlay(Circle().stroke(color, lineWidth: 1.7))
                        .position(last)
                }

                Group {
                    Text("-4h")
                        .position(x: leftInset + 7, y: geo.size.height - 5)
                    Text("-2h")
                        .position(x: leftInset + chartW / 2, y: geo.size.height - 5)
                    Text("现在")
                        .position(x: leftInset + chartW - 7, y: geo.size.height - 5)
                }
                .font(.system(size: 5.5, weight: .semibold))
                .foregroundColor(Color(hex: "5D6B88"))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}

private struct CGSStatusCard: View {
    let snapshot: CompactStatusSnapshot

    private var maxLoad: Double {
        Swift.max(Swift.max(Double(snapshot.cpuUsage), Double(snapshot.gpuUsage)), snapshot.storagePctPrecise)
    }

    private var isHot: Bool {
        snapshot.cpuTemp >= 85 || snapshot.gpuTemp >= 82 || snapshot.cpuDieHotspot >= 90
    }

    private var title: String {
        if isHot { return "温度过高" }
        if maxLoad >= 95 { return "危险（过载）" }
        if maxLoad >= 85 { return "接近满载" }
        if maxLoad >= 70 { return "高负载" }
        if maxLoad >= 45 { return "中等负载" }
        return "正常"
    }

    private var detail: String {
        if isHot { return "温度过高，立即处理" }
        if maxLoad >= 95 { return "负载过高，存在风险" }
        if maxLoad >= 85 { return "负载很高，建议关注" }
        if maxLoad >= 70 { return "负载较高，注意性能" }
        if maxLoad >= 45 { return "负载适中" }
        return "负载低，运行正常"
    }

    private var gpuState: String {
        let gpu = snapshot.gpuUsage
        if isHot && snapshot.gpuTemp >= 82 { return "GPU触发：图形温度高" }
        if gpu >= 90 { return "GPU触发：图形过载" }
        if gpu >= 70 { return "GPU触发：图形高负载" }
        if gpu >= 45 { return "GPU触发：图形活跃" }
        return "GPU触发：图形正常"
    }

    private var accent: Color {
        if isHot || maxLoad >= 95 { return Color(hex: "FF3B5C") }
        if maxLoad >= 85 { return Color(hex: "FF9F0A") }
        if maxLoad >= 45 { return Color(hex: "FFD60A") }
        return Color.white
    }

    var body: some View {
        HStack(spacing: 10) {
            CGSIconPanel(snapshot: snapshot, isHot: isHot)
                .frame(width: 82, height: 72)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    if isHot || maxLoad >= 95 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "FF3B5C"))
                    }
                    Spacer(minLength: 0)
                    Text("\(Int(maxLoad.rounded()))%")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(accent)
                }
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(gpuState)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                Text("C 处理器  ·  G 图形  ·  S 存储")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.58))
                    .lineLimit(1)
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(
                    LinearGradient(colors: [Color(hex: "5B77EA").opacity(0.92),
                                            Color(hex: "7489F1").opacity(0.74)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color.white.opacity(0.28), lineWidth: 0.9)
        )
        .shadow(color: Color(hex: "4C63D9").opacity(0.18), radius: 10, x: 0, y: 5)
    }
}

private struct CGSIconPanel: View {
    let snapshot: CompactStatusSnapshot
    let isHot: Bool

    var body: some View {
        VStack(spacing: 6) {
            CGSLine(label: "C", pct: Double(snapshot.cpuUsage), color: colorFor(value: Double(snapshot.cpuUsage), role: "C"))
            CGSLine(label: "G", pct: Double(snapshot.gpuUsage), color: colorFor(value: Double(snapshot.gpuUsage), role: "G"))
            CGSLine(label: "S", pct: snapshot.storagePctPrecise, color: colorFor(value: snapshot.storagePctPrecise, role: "S"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }

    private func colorFor(value: Double, role: String) -> Color {
        if isHot { return Color(hex: "FF3B5C") }
        if value >= 95 { return Color(hex: "FF3B5C") }
        if value >= 85 { return role == "G" ? Color(hex: "FF3B5C") : Color(hex: "FF9F0A") }
        if value >= 70 { return role == "S" ? Color(hex: "FFD60A") : Color(hex: "FF9F0A") }
        if value >= 45 { return role == "C" ? Color(hex: "FFD60A") : Color(hex: "FF9F0A") }
        return Color.white
    }
}

private struct CGSLine: View {
    let label: String
    let pct: Double
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Text(label)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
                .frame(width: 15, alignment: .leading)
            GeometryReader { geo in
                let progress = CGFloat(max(0, min(pct, 100))) / 100
                let width = Swift.max(16, geo.size.width * progress)
                Capsule()
                    .fill(color)
                    .frame(width: width, height: 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shadow(color: color.opacity(0.38), radius: 4, x: 0, y: 0)
            }
            .frame(height: 8)
        }
    }
}

private struct EnergyFlowTrendCard: View {
    let snapshot: CompactStatusSnapshot

    private var flow: Double {
        snapshot.chargerInputWatts - snapshot.totalPower
    }

    private var flowColor: Color {
        flow >= 0 ? Color(hex: "27C46B") : Color(hex: "FF6B22")
    }

    private var batteryState: String {
        if snapshot.batteryCharged { return "已充满" }
        if snapshot.batteryCharging { return "正在充电" }
        if snapshot.batteryOnAC { return "外接电源" }
        return "使用电池"
    }

    var body: some View {
        VStack(spacing: 7) {
            VStack(spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Label("能量流", systemImage: "bolt.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "475569"))
                    Spacer(minLength: 0)
                    Text(String(format: "%+.1f W", flow))
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundColor(flowColor)
                }
                Text(String(format: "充电输入 %.1f W  →  芯片功耗 %.1f W", snapshot.chargerInputWatts, snapshot.totalPower))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: "64748B"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                EnergyFlowPill(input: snapshot.chargerInputWatts, chip: snapshot.totalPower)
                    .frame(height: 34)
                HStack(spacing: 5) {
                    Circle().fill(flowColor).frame(width: 5, height: 5)
                    Text("\(batteryState) · 电量 \(snapshot.batteryPct)%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "64748B"))
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 7) {
                MiniTrendCard(title: "功耗趋势",
                              value: snapshot.totalPower,
                              color: Color(hex: "3B6BFF"),
                              history: snapshot.chipPowerHistory)
                MiniTrendCard(title: "充电输入趋势",
                              value: snapshot.chargerInputWatts,
                              color: Color(hex: "2CA94F"),
                              history: snapshot.chargerInputHistory)
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.white.opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color(hex: "FED7AA").opacity(0.58), lineWidth: 0.8)
        )
    }
}

private struct EnergyFlowPill: View {
    let input: Double
    let chip: Double

    private let dots: [(CGFloat, CGFloat, CGFloat)] = [
        (0.08, 0.36, 1.8), (0.14, 0.62, 1.4), (0.20, 0.28, 1.6), (0.26, 0.50, 1.3),
        (0.34, 0.66, 1.7), (0.42, 0.40, 1.4), (0.50, 0.58, 1.8), (0.58, 0.30, 1.5),
        (0.66, 0.52, 1.3), (0.74, 0.64, 1.7), (0.82, 0.38, 1.4), (0.90, 0.55, 1.8)
    ]

    var body: some View {
        GeometryReader { geo in
            let total = Swift.max(Swift.max(input, chip), 1)
            let split = CGFloat(max(0.34, min(0.72, input / total * 0.55)))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: "F1F5F9"))
                Capsule()
                    .fill(
                        LinearGradient(colors: [Color(hex: "7BE495").opacity(0.78),
                                                Color(hex: "F8D36B").opacity(0.72),
                                                Color(hex: "FFB157").opacity(0.58)],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: geo.size.width * split)
                ForEach(0..<dots.count, id: \.self) { index in
                    let dot = dots[index]
                    Circle()
                        .fill(Color.white.opacity(0.78))
                        .frame(width: dot.2, height: dot.2)
                        .position(x: geo.size.width * dot.0, y: geo.size.height * dot.1)
                }
            }
            .overlay(Capsule().stroke(Color.white.opacity(0.55), lineWidth: 1))
            .shadow(color: Color(hex: "65C786").opacity(0.25), radius: 8, x: 0, y: 3)
        }
    }
}

private struct MiniTrendCard: View {
    let title: String
    let value: Double
    let color: Color
    let history: [Double]

    private var subtitle: String {
        guard let first = history.first, first > 0.05 else { return "实时" }
        let delta = (value - first) / first * 100
        return String(format: "较前 %+.0f%%", delta)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: title.contains("充电") ? "bolt.fill" : "chart.line.uptrend.xyaxis")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(hex: "475569"))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("实时")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(Color(hex: "94A3B8"))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.04))
                    .clipShape(Capsule())
            }
            Text(String(format: "%.1f W", value))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(subtitle)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(color.opacity(0.82))
            SparklineView(values: history, color: color)
                .frame(height: 34)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.50))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct SparklineView: View {
    let values: [Double]
    let color: Color
    var unit = ""
    var fixedMax: Double? = nil
    var timeLabel = "4h"

    private var samples: [Double] {
        let cleaned = values.suffix(96).map { max(0, $0) }
        return cleaned.isEmpty ? [0, 0] : cleaned
    }

    private func niceUpperBound(for value: Double) -> Double {
        let raw = max(value, 1)
        if let fixedMax { return max(fixedMax, raw) }
        if unit == "%" {
            if raw <= 20 { return 20 }
            if raw <= 50 { return 50 }
            return 100
        }
        if raw <= 1 { return 1 }
        if raw <= 10 { return ceil(raw / 2) * 2 }
        if raw <= 30 { return ceil(raw / 5) * 5 }
        if raw <= 60 { return ceil(raw / 10) * 10 }
        if raw <= 150 { return ceil(raw / 25) * 25 }
        return ceil(raw / 50) * 50
    }

    private func axisText(_ value: Double) -> String {
        if unit == "%" {
            return "\(Int(value.rounded()))%"
        }
        if unit == "W" {
            if value >= 100 { return "\(Int(value.rounded()))W" }
            if value >= 10 { return "\(Int(value.rounded()))W" }
            return String(format: "%.0fW", value)
        }
        return "\(Int(value.rounded()))"
    }

    var body: some View {
        GeometryReader { geo in
            let data = samples
            let chartTop: CGFloat = 2
            let chartBottom: CGFloat = 9
            let leftAxisWidth: CGFloat = 20
            let axisGap: CGFloat = 2
            let chartX = leftAxisWidth + axisGap
            let chartWidth = max(1, geo.size.width - chartX)
            let chartHeight = max(1, geo.size.height - chartTop - chartBottom)
            let minValue = 0.0
            let maxValue = niceUpperBound(for: data.max() ?? 1)
            let range = maxValue - minValue
            let points = data.enumerated().map { index, value in
                CGPoint(x: chartX + chartWidth * CGFloat(index) / CGFloat(max(data.count - 1, 1)),
                        y: chartTop + chartHeight - chartHeight * CGFloat((min(max(value, minValue), maxValue) - minValue) / range))
            }

            ZStack(alignment: .topLeading) {
                ForEach([0.0, 0.5, 1.0], id: \.self) { tick in
                    let y = chartTop + chartHeight * CGFloat(1 - tick)
                    Path { path in
                        path.move(to: CGPoint(x: chartX, y: y))
                        path.addLine(to: CGPoint(x: chartX + chartWidth, y: y))
                    }
                    .stroke(DashboardStyle.track.opacity(tick == 0 ? 0.9 : 0.58),
                            style: StrokeStyle(lineWidth: 0.65, dash: tick == 0 ? [] : [2.2, 3]))
                }

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: chartTop + chartHeight))
                    points.forEach { path.addLine(to: $0) }
                    if let last = points.last {
                        path.addLine(to: CGPoint(x: last.x, y: chartTop + chartHeight))
                    }
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(colors: [color.opacity(0.22), color.opacity(0.02)],
                                   startPoint: .top,
                                   endPoint: .bottom)
                )

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(color.opacity(0.92), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

                if let last = points.last {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                        .overlay(Circle().stroke(color, lineWidth: 1.4))
                        .position(last)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(axisText(maxValue))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                    Text(axisText(maxValue / 2))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                    Text(axisText(0))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(DashboardStyle.axisLabelFont)
                .foregroundColor(DashboardStyle.secondaryText)
                .frame(width: leftAxisWidth, height: chartHeight + 2, alignment: .leading)
                .position(x: leftAxisWidth / 2,
                          y: chartTop + chartHeight / 2)

                HStack {
                    Text("\(timeLabel)前")
                    Spacer(minLength: 0)
                    Text("现在")
                }
                .font(DashboardStyle.axisLabelFont)
                .foregroundColor(DashboardStyle.secondaryText)
                .frame(width: chartWidth, height: chartBottom, alignment: .bottom)
                .position(x: chartX + chartWidth / 2,
                          y: chartTop + chartHeight + chartBottom / 2)
            }
        }
    }
}

private struct CodexQuotaStrip: View {
    let snapshot: CompactStatusSnapshot

    private var planTitle: String {
        if snapshot.codexPlanType.localizedCaseInsensitiveContains("codex") {
            return snapshot.codexPlanType
        }
        return "Codex \(snapshot.codexPlanType)"
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                TerminalBadge()
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(planTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "111827"))
                        .lineLimit(1)
                    Text(snapshot.codexTodayTokensText.replacingOccurrences(of: "今日 ", with: ""))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "5D6B88"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("Pro Plan")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(hex: "246BFF"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "EAF1FF"))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color(hex: "D9DEE8"))
                .frame(width: 1, height: 50)

            QuotaRing(label: "5小时内",
                      pct: snapshot.codexFiveHourRemainingPct,
                      caption: snapshot.codexFiveHourResetText.isEmpty ? "4 小时后重置" : snapshot.codexFiveHourResetText,
                      color: quotaColor(snapshot.codexFiveHourRemainingPct))

            QuotaRing(label: "周券",
                      pct: snapshot.codexWeeklyRemainingPct,
                      caption: snapshot.codexWeeklyResetText.isEmpty ? "6 天后重置" : snapshot.codexWeeklyResetText,
                      color: Color(hex: "8C35F2"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(SoftPanelBackground(cornerRadius: 16))
    }

    private func quotaColor(_ remaining: Int) -> Color {
        if remaining <= 10 { return Color(hex: "DC2626") }
        if remaining <= 30 { return Color(hex: "F05A24") }
        return Color(hex: "16A34A")
    }
}

private struct TerminalBadge: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [Color(hex: "111827"),
                                              Color(hex: "263146")],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
            Image(systemName: "terminal")
                .font(.system(size: 21, weight: .heavy))
                .foregroundColor(Color(hex: "DDE7F4"))
        }
        .shadow(color: Color(hex: "111827").opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

private struct QuotaRing: View {
    let label: String
    let pct: Int
    let caption: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(Color(hex: "5D6B88"))
                .lineLimit(1)
            ZStack {
                Circle()
                    .stroke(Color(hex: "E7ECF5"), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(pct, 100))) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-92))
                Text("\(pct)%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "111827"))
            }
            .frame(width: 44, height: 44)
            Text(caption)
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(Color(hex: "5D6B88"))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(width: 48)
    }
}

private struct CodexQuotaColumn: View {
    let label: String
    let pct: Int
    let caption: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(label)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(Color(hex: "24324B"))
                    .frame(width: 31, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(pct)%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(height: 12, alignment: .bottom)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "E7E9F0"))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(max(0, min(pct, 100))) / 100)
                }
            }
            .frame(height: 5)
            Text(caption)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Color(hex: "5D6B88"))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(height: 10, alignment: .top)
        }
        .frame(width: 62, height: 31, alignment: .leading)
    }
}

private struct QuotaTinyPill: View {
    let label: String
    let pct: Int
    let reset: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Color(hex: "64748B"))
                Text("\(pct)%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(quotaColor(pct))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule().fill(quotaColor(pct))
                        .frame(width: geo.size.width * CGFloat(max(0, min(pct, 100))) / 100)
                }
            }
            .frame(width: 45, height: 4)
            Text(reset)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(Color(hex: "94A3B8"))
                .lineLimit(1)
        }
        .frame(width: 48, alignment: .leading)
    }

    private func quotaColor(_ remaining: Int) -> Color {
        if remaining <= 10 { return Color(hex: "DC2626") }
        if remaining <= 30 { return Color(hex: "F05A24") }
        return Color(hex: "16A34A")
    }
}

private struct FanReasonPanel: View {
    let reasons: [String]
    let stopAdvice: String

    var body: some View {
        HStack(spacing: 6) {
            PanelIcon(systemImage: "fan", tint: DashboardStyle.accentBlue)
            Text("风扇原因")
                .font(DashboardStyle.smallLabelFont)
                .foregroundColor(DashboardStyle.titleText)
                .lineLimit(1)
            FanReasonRow(index: 1,
                         text: reasons.first ?? "正在判断当前任务",
                         pct: fanReasonPercent(reasons.first ?? "", index: 0))
            Text(stopAdvice.hasPrefix("可") ? "可停" : "不建议")
                .font(DashboardStyle.badgeFont)
                .foregroundColor(stopAdvice.hasPrefix("可") ? DashboardStyle.warningText : DashboardStyle.successText)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(height: 16)
                .background((stopAdvice.hasPrefix("可") ? DashboardStyle.accentOrange : DashboardStyle.accentGreen).opacity(0.09))
                .clipShape(Capsule())
        }
        .padding(.horizontal, DashboardStyle.panelPaddingX)
        .frame(height: 34)
        .background(SoftPanelBackground(cornerRadius: DashboardStyle.panelRadius))
    }

    private func fanReasonPercent(_ reason: String, index: Int) -> Int {
        if let range = reason.range(of: #"([0-9]+(?:\.[0-9]+)?)\s*%"#, options: .regularExpression) {
            let matched = String(reason[range])
                .replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespaces)
            if let value = Double(matched) {
                return max(4, min(100, Int(value.rounded())))
            }
        }
        return [38, 18, 12][min(index, 2)]
    }
}

private struct FanReasonRow: View {
    let index: Int
    let text: String
    let pct: Int

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .font(DashboardStyle.fanReasonFont)
                .foregroundColor(DashboardStyle.bodyText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            GeometryReader { geo in
                let progress = CGFloat(max(0, min(pct, 100))) / 100
                ZStack(alignment: .leading) {
                    Capsule().fill(DashboardStyle.track)
                    Capsule().fill(DashboardStyle.accentBlue)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeOut(duration: 1.15), value: pct)
                }
            }
            .frame(width: DashboardStyle.fanReasonProgressWidth, height: DashboardStyle.fanReasonProgressHeight)
            .fixedSize(horizontal: true, vertical: false)

            Text("\(pct)%")
                .font(DashboardStyle.secondaryValueFont)
                .foregroundColor(DashboardStyle.bodyText)
                .frame(width: DashboardStyle.fanReasonPercentWidth, alignment: .trailing)
        }
        .frame(height: DashboardStyle.fanReasonRowHeight)
    }
}

private struct ProductMetricRow: View {
    let label: String
    let pct: Double
    let color: Color
    var value: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "111827"))
                .frame(width: 42, alignment: .leading)
            GeometryReader { g in
                let fillWidth = g.size.width * CGFloat(max(0, min(pct, 100))) / 100
                ZStack(alignment: .topLeading) {
                    ProductGridLines()
                        .frame(height: 12)
                    StripedMetricShadow()
                        .frame(width: max(fillWidth, 12), height: 3)
                        .offset(y: 7)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 5)
                        .offset(y: 1)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [barColor.opacity(0.78), barColor],
                                             startPoint: .leading,
                                             endPoint: .trailing))
                        .frame(width: max(fillWidth, 5), height: 5)
                        .offset(y: 1)
                }
            }
            .frame(height: 11)
            Text(value ?? "\(Int(pct.rounded()))%")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "111827"))
                .frame(width: 34, alignment: .trailing)
        }
        .frame(height: 14)
    }

    private var barColor: Color {
        pct >= 85 ? Color(hex: "FF453A") : pct >= 60 ? Color(hex: "FFD60A") : color
    }
}

private struct ProductGridLines: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                for index in 0...4 {
                    let x = geo.size.width * CGFloat(index) / 4
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
            }
            .stroke(Color.black.opacity(0.045), lineWidth: 1)
        }
    }
}

private struct StripedMetricShadow: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: -size.height, through: size.width + size.height, by: 3) {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
            }
            context.stroke(path, with: .color(Color.black.opacity(0.20)), lineWidth: 0.55)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

private struct GaugeMiniStat: View {
    let k: String
    let v: String
    let value: Double
    let maxValue: Double
    let color: Color
    @State private var animatedValue: Double = 0

    init(_ k: String, _ v: String, value: Double, maxValue: Double, color: Color) {
        self.k = k
        self.v = v
        self.value = value
        self.maxValue = maxValue
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(k)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(hex: "111827"))
                Spacer(minLength: 0)
                Text(v)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            SemiGauge(value: animatedValue, maxValue: dynamicMax, color: color)
                .frame(height: 34)
                .onAppear { animatedValue = value }
                .onChange(of: value) { newValue in
                    animatedValue = newValue
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color(hex: "FED7AA").opacity(0.50), lineWidth: 0.8)
        )
    }

    private var dynamicMax: Double {
        max(maxValue, ceil(max(value, animatedValue) * 1.25 / 10) * 10)
    }
}

private struct SemiGauge: View {
    let value: Double
    let maxValue: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let progress = max(0, min(value / max(maxValue, 1), 1))
            let width = min(geo.size.width, 96)
            let radius = max(8, min(width / 2 - 5, geo.size.height - 8))
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height - 2)
            let start = Angle.degrees(180)
            let end = Angle.degrees(360)
            let progressEnd = Angle.degrees(180 + 180 * progress)

            ZStack {
                Path { path in
                    path.addArc(center: center,
                                radius: radius,
                                startAngle: start,
                                endAngle: end,
                                clockwise: false)
                }
                .stroke(Color.black.opacity(0.08), style: StrokeStyle(lineWidth: 6, lineCap: .round))

                Path { path in
                    path.addArc(center: center,
                                radius: radius,
                                startAngle: start,
                                endAngle: progressEnd,
                                clockwise: false)
                }
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))

                ForEach(0..<7, id: \.self) { index in
                    let angle = Double(index) / 6 * 180 + 180
                    GaugeTick(center: center, radius: radius - 8, angle: angle)
                        .stroke(Color.black.opacity(0.13), lineWidth: 0.7)
                }
            }
        }
    }
}

private struct GaugeTick: Shape {
    let center: CGPoint
    let radius: CGFloat
    let angle: Double

    func path(in rect: CGRect) -> Path {
        let radians = CGFloat(angle * .pi / 180)
        let inner = CGPoint(x: center.x + cos(radians) * radius,
                            y: center.y + sin(radians) * radius)
        let outer = CGPoint(x: center.x + cos(radians) * (radius + 4),
                            y: center.y + sin(radians) * (radius + 4))
        var path = Path()
        path.move(to: inner)
        path.addLine(to: outer)
        return path
    }
}

private struct TemperatureLine: View {
    let cpuTemp: Double
    let gpuTemp: Double
    let cpuDieHotspot: Double

    var body: some View {
        HStack(spacing: 7) {
            Text("温度")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "475569"))
                .frame(width: 48, alignment: .leading)
            TempText("CPU", cpuTemp)
            TempText("图形", gpuTemp)
            if cpuDieHotspot > 0 {
                TempText("热点", cpuDieHotspot)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct TempText: View {
    let label: String
    let temp: Double

    init(_ label: String, _ temp: Double) {
        self.label = label
        self.temp = temp
    }

    var body: some View {
        Text("\(label) \(String(format: "%.0f°C", temp))")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(tempColor(temp))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private struct MiniStat: View {
    let k: String
    let v: String
    var color: Color = Color(hex: "111827")

    init(_ k: String, _ v: String, color: Color = Color(hex: "111827")) {
        self.k = k
        self.v = v
        self.color = color
    }

    private var icon: String {
        switch k {
        case "风扇转速": return "fan"
        case "网速": return "wifi"
        case "当前国家": return "location.fill"
        case "电池": return "battery.100percent"
        default: return "circle.grid.2x2"
        }
    }

    private var accent: Color {
        switch k {
        case "风扇转速": return Color(hex: "2563EB")
        case "网速": return Color(hex: "18A957")
        case "当前国家": return Color(hex: "7C3AED")
        case "电池": return Color(hex: "F05A24")
        default: return Color(hex: "64748B")
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(accent)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(k)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Color(hex: "5D6B88"))
                    .lineLimit(1)
                Text(v)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SoftPanelBackground(cornerRadius: 12))
    }
}

private struct EnergyUsageCard: View {
    let powerWatts: Double
    let isOnAC: Bool
    let energyKWh: Double
    let cycleDays: Int

    private var meterReadingText: String {
        let kWh = max(0, energyKWh)
        if kWh < 1 {
            let wh = kWh * 1000
            return wh >= 10 ? String(format: "%.0f", wh) : String(format: "%.1f", wh)
        }
        if kWh < 10 {
            return String(format: "%.2f", kWh)
        }
        return String(format: "%.1f", kWh)
    }

    private var meterUnitText: String {
        energyKWh < 1 ? "Wh" : "kWh"
    }

    private var powerText: String {
        String(format: "%.1fW", max(0, powerWatts))
    }

    private var powerLabelText: String {
        isOnAC ? "输入" : "放电"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                Image(systemName: "bolt.square")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundColor(Color(hex: "8C35F2"))
                    .frame(width: 10)
                Text("用电表")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(Color(hex: "17213A"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Text("今日")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(Color(hex: "8C35F2"))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .frame(height: 16)
                    .background(Color(hex: "F1E8FF"))
                    .clipShape(Capsule())
            }

            ElectricMeterDisplay(reading: meterReadingText, unit: meterUnitText)

            HStack(spacing: 5) {
                MeterValue(label: powerLabelText, value: powerText, color: Color(hex: "2563EB"))
                MeterValue(label: "周期", value: "\(cycleDays)天", color: Color(hex: "8C35F2"))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 102, alignment: .topLeading)
        .background(SoftPanelBackground(cornerRadius: 14))
    }
}

private struct ElectricMeterDisplay: View {
    let reading: String
    let unit: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(reading)
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundColor(Color(hex: "111827"))
                .lineLimit(1)
                .minimumScaleFactor(0.50)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "8C35F2"))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .frame(height: 31)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [Color(hex: "F5EFFF"), Color(hex: "FFFFFF")],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "D8C6FF"), lineWidth: 0.8))
        )
    }
}

private struct MeterValue: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 6.5, weight: .semibold))
                .foregroundColor(Color(hex: "5D6B88"))
            Text(value)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DashboardFooter: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("Hermes")
            Circle().fill(DashboardStyle.codexGreen).frame(width: 5, height: 5)
            Text("稳定运行")
        }
        .font(DashboardStyle.usageDetailFont)
        .foregroundColor(DashboardStyle.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.top, 0)
    }
}

private enum RecordingActionsStyle: Equatable {
    case compact
    case dashboard
}

private struct RecordingActionsRow: View {
    @ObservedObject private var recorder = RecordingController.shared
    var style: RecordingActionsStyle = .compact

    private var audioTitle: String {
        if recorder.isPreparing { return "准备中" }
        return recorder.isCallRecording ? "停止监听" : "监听"
    }

    private var audioIcon: String {
        recorder.isCallRecording ? "stop.fill" : "mic.fill"
    }

    var body: some View {
        HStack(spacing: 6) {
            RecordingActionButton(title: audioTitle,
                                  systemImage: audioIcon,
                                  tint: Color(hex: recorder.isCallRecording ? "FF453A" : "18A957"),
                                  subtitle: style == .dashboard ? "录音 + 会议板" : nil,
                                  height: style == .dashboard ? 42 : 32,
                                  isDisabled: recorder.isPreparing) {
                recorder.toggleCallRecording()
            }
            .help("录制系统声音和麦克风，并打开 Hermes 会议翻译板")

            RecordingActionButton(title: "录屏",
                                  systemImage: "record.circle",
                                  tint: Color(hex: "2563EB"),
                                  subtitle: style == .dashboard ? "点击开始录屏" : nil,
                                  height: style == .dashboard ? 42 : 32,
                                  isDisabled: false) {
                recorder.openScreenRecorderPicker()
            }
            .help("打开区域录屏选择器")
        }
    }
}

private struct RecordingActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    var subtitle: String? = nil
    var height: CGFloat = 32
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(tint.opacity(0.10))
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(width: subtitle == nil ? 16 : 28, height: subtitle == nil ? 16 : 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(Color(hex: "5D6B88"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(isDisabled ? 0.08 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint.opacity(isDisabled ? 0.16 : 0.28), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.62 : 1)
    }
}

// MARK: - CPU

private struct CPUSection: View {
    @ObservedObject var model: SystemStatsModel
    var body: some View {
        SectionBox(icon: "cpu", title: "处理器") {
            Row(label: "总体") { StatBar(pct: model.cpuUsage) }
            if model.eCoreCount > 0 {
                Row(label: "能效核心  \(model.eCoresMHz) MHz") {
                    StatBar(pct: model.eCoresPct, color: Color(hex: "64D2FF"))
                }
                Row(label: "性能核心  \(model.pCoresMHz) MHz") {
                    StatBar(pct: model.pCoresPct, color: Color(hex: "BF5AF2"))
                }
                // M5+ Super cluster — only shown when present
                if model.sClusterPct > 0 || model.sClusterMHz > 0 {
                    Row(label: "超大核心  \(model.sClusterMHz) MHz") {
                        StatBar(pct: model.sClusterPct, color: Color(hex: "FF6B6B"))
                    }
                }
            }
            HStack {
                Pill(icon: "thermometer", val: String(format: "%.0f°C", model.cpuTemp),
                     color: tempColor(model.cpuTemp))
                if model.cpuDieHotspot > 0 {
                    Pill(icon: "thermometer.sun.fill",
                         val: String(format: "%.0f°C", model.cpuDieHotspot),
                         color: tempColor(model.cpuDieHotspot))
                }
                Spacer()
                Pill(icon: "bolt", val: String(format: "%.2f W", model.cpuPower),
                     color: Color(hex: "FFD60A"))
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - Fan (hidden on fanless models)

private struct FanSection: View {
    @ObservedObject var model: SystemStatsModel
    var body: some View {
        SectionBox(icon: "fan", title: "风扇") {
            Row(label: "转速") {
                HStack {
                    Text("\(model.fanRPM) RPM")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("转动原因")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex:"666680"))
                Text(model.fanReason)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex:"EBEBF5"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - GPU + Memory

private struct GPUMemorySection: View {
    @ObservedObject var model: SystemStatsModel
    var body: some View {
        SectionBox(icon: "rectangle.3.group", title: "图形处理器 / 内存") {
            Row(label: "图形  \(model.gpuMHz) MHz") {
                StatBar(pct: model.gpuUsage, color: Color(hex: "FF9F0A"))
            }
            HStack {
                Pill(icon: "thermometer", val: String(format: "%.0f°C", model.gpuTemp),
                     color: tempColor(model.gpuTemp))
                Spacer()
                Pill(icon: "bolt", val: String(format: "%.3f W", model.gpuPower),
                     color: Color(hex: "FFD60A"))
            }
            .padding(.top, 2)
            Row(label: "内存  \(fmtB(model.memUsed)) / \(fmtB(model.memTotal))") {
                StatBar(pct: model.memPct, color: Color(hex: "0A84FF"))
            }
            HStack(spacing: 16) {
                KV("内存带宽",  String(format: "%.1f GB/s", model.dramBW))
                KV("交换空间", model.swapTotal > 0
                    ? "\(fmtB(model.swapUsed)) / \(fmtB(model.swapTotal))" : "无")
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - Battery

private struct BatterySection: View {
    @ObservedObject var model: SystemStatsModel

    var statusLabel: String {
        if model.batteryCharged  { return "已充满" }
        if model.batteryCharging { return "充电中" }
        return "使用电池"
    }

    var batteryColor: Color {
        model.batteryPct < 20 ? Color(hex: "FF453A")
            : (model.batteryCharging || model.batteryCharged)
                ? Color(hex: "30D158") : Color(hex: "FFD60A")
    }

    var body: some View {
        SectionBox(icon: "battery.75percent", title: "电池") {
            Row(label: statusLabel) {
                StatBar(pct: model.batteryPct, color: batteryColor)
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    KV("电源来源",     model.batteryOnAC ? "电源适配器" : "电池")
                    KV("剩余时间",  model.batteryTimeLeft)
                }
                GridRow {
                    KV("适配器",    model.adapterWatts > 0
                        ? String(format: "%.0f W", model.adapterWatts) : "—")
                    KV("充电功率",model.chargingWatts > 0
                        ? String(format: "%.1f W", model.chargingWatts) : "—")
                }
                GridRow {
                    KV("温度",       model.batteryTempC > 0
                        ? String(format: "%.1f °C", model.batteryTempC) : "—")
                    KV("循环次数",     model.batteryCycles > 0
                        ? "\(model.batteryCycles)" : "—")
                }
                GridRow {
                    KV("健康度",     "\(model.batteryHealthPct)%")
                    KV("容量",   model.batteryMaxMAh > 0
                        ? "\(model.batteryMaxMAh) / \(model.batteryDesignMAh) mAh" : "—")
                }
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - Network + Disk

private struct NetworkDiskSection: View {
    @ObservedObject var model: SystemStatsModel
    var body: some View {
        HStack(spacing: 0) {
            SectionBox(icon: "wifi", title: "网络") {
                IORow(icon: "arrow.down", val: fmtB(model.netInBps)  + "/s", color: Color(hex:"30D158"))
                IORow(icon: "arrow.up",   val: fmtB(model.netOutBps) + "/s", color: Color(hex:"FF9F0A"))
            }
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1)
            SectionBox(icon: "internaldrive", title: "磁盘读写") {
                IORow(icon: "arrow.down", val: String(format: "%.0f KB/s", model.diskReadKBs),  color: Color(hex:"64D2FF"))
                IORow(icon: "arrow.up",   val: String(format: "%.0f KB/s", model.diskWriteKBs), color: Color(hex:"FF9F0A"))
            }
        }
    }
}

private struct IORow: View {
    let icon: String; let val: String; let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9)).foregroundColor(color)
            Text(val)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(hex: "EBEBF5"))
            Spacer()
        }
    }
}

// MARK: - Power rails

private struct PowerSection: View {
    @ObservedObject var model: SystemStatsModel
    var body: some View {
        SectionBox(icon: "bolt.fill", title: "功耗") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                PowerTile(label: "处理器",   val: model.cpuPower)
                PowerTile(label: "图形",   val: model.gpuPower)
                PowerTile(label: "神经",   val: model.anePower)
                PowerTile(label: "内存",  val: model.dramPower)
                PowerTile(label: "系统",   val: model.sysPower)
                PowerTile(label: "合计", val: model.totalPower, highlight: true)
            }
        }
    }
}

private struct PowerTile: View {
    let label: String; let val: Double; var highlight: Bool = false
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(highlight ? Color(hex:"FFD60A") : Color(hex:"888899"))
            Spacer()
            Text(String(format: val >= 1 ? "%.2f W" : "%.3f W", val))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(highlight ? Color(hex:"FFD60A") : .white)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Color.white.opacity(highlight ? 0.07 : 0.03))
        .cornerRadius(6)
    }
}

// MARK: - Processes

private struct ProcessSection: View {
    @ObservedObject var model: SystemStatsModel
    var body: some View {
        SectionBox(icon: "list.bullet", title: "高占用进程") {
            HStack {
                Text("进程").frame(maxWidth: .infinity, alignment: .leading)
                Text("处理器").frame(width: 40, alignment: .trailing)
                Text("内存").frame(width: 64, alignment: .trailing)
            }
            .font(.system(size: 9)).foregroundColor(Color(hex: "666680"))

            ForEach(model.topProcs) { p in
                HStack(spacing: 0) {
                    Text(p.name)
                        .font(.system(size: 11)).foregroundColor(Color(hex: "EBEBF5"))
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.1f%%", p.cpu))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(cpuClr(p.cpu))
                        .frame(width: 40, alignment: .trailing)
                    Text(fmtB(p.mem))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "64D2FF"))
                        .frame(width: 64, alignment: .trailing)
                }
            }
        }
    }
    func cpuClr(_ v: Double) -> Color {
        v >= 50 ? Color(hex:"FF453A") : v >= 20 ? Color(hex:"FFD60A") : Color(hex:"30D158")
    }
}

// MARK: - Footer

private struct FooterBar: View {
    @ObservedObject var model: SystemStatsModel
    @State private var working = false
    var body: some View {
        Button {
            working = true
            model.optimize {
                DispatchQueue.main.async { working = false }
            }
        } label: {
            Label(working ? "急救中…" : "紧急优化", systemImage: "bolt.fill")
                .frame(maxWidth: .infinity)
                .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(hex: "FF453A"))
        .disabled(working)
        .controlSize(.regular)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Settings sheet

struct SettingsSheet: View {
    @Binding var isPresented: Bool
    @AppStorage("enableMenuBar") var enableMenuBar = true
    @AppStorage("enableWidget")  var enableWidget  = false
    @AppStorage("openAtLogin")   var openAtLogin   = false
    @ObservedObject private var updater = UpdateChecker.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("设置")
                .font(.system(size: 16, weight: .bold)).foregroundColor(.white)

            VStack(alignment: .leading, spacing: 6) {
                Toggle("菜单栏应用", isOn: $enableMenuBar)
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "30D158")))
                Text("在菜单栏显示实时状态，点击可打开完整面板。")
                    .font(.system(size: 11)).foregroundColor(Color(hex: "666680"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("登录时自动打开", isOn: $openAtLogin)
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "30D158")))
                    .onChange(of: openAtLogin) { enabled in
                        if enabled {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
                Text("登录 macOS 时自动启动 Hermes。")
                    .font(.system(size: 11)).foregroundColor(Color(hex: "666680"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("桌面小组件", isOn: $enableWidget)
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "30D158")))
                Text("右键桌面 → 编辑小组件 → 查找 Hermes。")
                    .font(.system(size: 11)).foregroundColor(Color(hex: "666680"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Color.white.opacity(0.1))

            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hermes  v\(updater.currentVersion)")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                    Group {
                        switch updater.updatePhase {
                        case .idle:
                            if updater.updateAvailable {
                                Text("发现 v\(updater.latestVersion) 新版本")
                                    .foregroundColor(Color(hex: "FF9F0A"))
                            } else {
                                Text("Apple Silicon  ·  macOS 13 及以上  ·  MIT")
                                    .foregroundColor(Color(hex: "666680"))
                            }
                        case .downloading:
                            Text("正在下载 v\(updater.latestVersion)…")
                                .foregroundColor(Color(hex: "FF9F0A"))
                        case .installing:
                            Text("正在安装…")
                                .foregroundColor(Color(hex: "FF9F0A"))
                        case .readyToRelaunch:
                            Text("准备完成，重新启动后生效")
                                .foregroundColor(Color(hex: "30D158"))
                        case .failed(let msg):
                            Text(msg)
                                .foregroundColor(Color(hex: "FF453A"))
                        }
                    }
                    .font(.system(size: 10))
                }
                Spacer()
                Group {
                    switch updater.updatePhase {
                    case .idle:
                        HStack(spacing: 6) {
                            if updater.updateAvailable {
                                Button("更新") { updater.startUpdate() }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color(hex: "FF9F0A"))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Button("完成") { isPresented = false }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(hex: "0A84FF"))
                        }
                    case .downloading:
                        VStack(alignment: .trailing, spacing: 3) {
                            ProgressView(value: updater.downloadFraction)
                                .progressViewStyle(.linear)
                                .tint(Color(hex: "FF9F0A"))
                                .frame(width: 80)
                            Text("\(Int(updater.downloadFraction * 100))%")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: "888899"))
                        }
                    case .installing:
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(Color(hex: "FF9F0A"))
                    case .readyToRelaunch:
                        Button("重新启动") { updater.relaunch() }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: "30D158"))
                            .font(.system(size: 12, weight: .semibold))
                    case .failed:
                        Button("关闭") { updater.dismissUpdateError() }
                            .buttonStyle(.bordered)
                            .font(.system(size: 12))
                    }
                }
            }
        }
        .padding(22).frame(width: 320)
        .background(Color(hex: "1C1C1E"))
        .preferredColorScheme(.dark)
    }
}

// MARK: - Reusable atoms

private struct SectionBox<Content: View>: View {
    let icon: String; let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "64748B"))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "64748B")).tracking(0.6)
            }
            content
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }
}

private struct Row<R: View>: View {
    let label: String; @ViewBuilder let right: R
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11)).foregroundColor(Color(hex: "ABABC0"))
                .frame(width: 130, alignment: .leading).lineLimit(1)
            right
        }
    }
}

private struct StatBar: View {
    let pct: Int; var color: Color = Color(hex: "30D158")
    private var barColor: Color {
        pct >= 85 ? Color(hex:"FF453A") : pct >= 60 ? Color(hex:"FFD60A") : color
    }
    var body: some View {
        HStack(spacing: 6) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: 3).fill(barColor)
                        .frame(width: g.size.width * CGFloat(min(pct,100)) / 100)
                }
            }
            .frame(height: 7)
            Text("\(pct)%")
                .font(.system(size: 11, design: .monospaced)).foregroundColor(.white)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

private struct Pill: View {
    let icon: String; let val: String; let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9))
            Text(val).font(.system(size: 10, design: .monospaced))
        }
        .foregroundColor(color)
    }
}

private struct KV: View {
    let k: String; let v: String
    init(_ k: String, _ v: String) { self.k = k; self.v = v }
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(k).font(.system(size: 9)).foregroundColor(Color(hex:"666680"))
            Text(v).font(.system(size: 11, design: .monospaced)).foregroundColor(Color(hex:"EBEBF5"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Helpers

private func fmtB(_ b: Int64) -> String {
    let d = Double(b)
    if d >= 1_099_511_627_776 { return String(format: "%.1f TB", d/1_099_511_627_776) }
    if d >= 1_073_741_824 { return String(format: "%.1f GB", d/1_073_741_824) }
    if d >= 1_048_576     { return String(format: "%.1f MB", d/1_048_576) }
    if d >= 1_024         { return String(format: "%.0f KB", d/1_024) }
    return "\(b) B"
}

private func tempColor(_ t: Double) -> Color {
    t >= 80 ? Color(hex:"DC2626") : t >= 65 ? Color(hex:"B45309") : Color(hex:"64748B")
}

// MARK: - Hex colour helper

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double((int)       & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
