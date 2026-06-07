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
            VStack(spacing: 0) {
                Header(snapshot: snapshot)
                if snapshot.helperMissing {
                    HelperMissingBanner()
                }
                sep
                CompactStatusSection(snapshot: snapshot.compact)
                    .equatable()
                Color.clear.frame(height: 10)
                sep
                FooterBar(model: model)
            }
        }
        .frame(width: 280)
        .background {
            ZStack {
                FrostedBackground()
                Color.white.opacity(0.62)
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
                Text("请运行 DMG 里的 Install.command，以启用图形处理器、温度和功耗数据。")
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

    var statusColor: Color {
        snapshot.hermesUsageAvailable ? Color(hex: "30D158") : Color(hex: "FFD60A")
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hermes Agent")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundColor(Color(hex: "111827"))
                HStack(spacing: 5) {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(snapshot.hermesTodayTokensText)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(statusColor)
                    Text("·")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "94A3B8"))
                    Text(snapshot.hermesTodayDurationText)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "5D6B88"))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 9)
        .padding(.bottom, 4)
    }
}

// MARK: - Compact status

private struct CompactStatusSnapshot: Equatable {
    let codexUsageAvailable: Bool
    let codexPlanType: String
    let codexTodayTokensText: String
    let codexFiveHourRemainingPct: Int
    let codexFiveHourResetText: String
    let codexWeeklyRemainingPct: Int
    let codexWeeklyResetText: String
    let cpuUsage: Int
    let gpuUsage: Int
    let storagePctPrecise: Double
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
    let chargerInputHistory: [Double]
    let chipPowerHistory: [Double]
    let netInBps: Int64
    let netOutBps: Int64
    let currentCountry: String
    let batteryPct: Int

    init(_ model: SystemStatsModel) {
        codexUsageAvailable = model.codexUsageAvailable
        codexPlanType = model.codexPlanType
        codexTodayTokensText = model.codexTodayTokensText
        codexFiveHourRemainingPct = model.codexFiveHourRemainingPct
        codexFiveHourResetText = model.codexFiveHourResetText
        codexWeeklyRemainingPct = model.codexWeeklyRemainingPct
        codexWeeklyResetText = model.codexWeeklyResetText
        cpuUsage = model.cpuUsage
        gpuUsage = model.gpuUsage
        storagePctPrecise = model.storagePctPrecise
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
        chargerInputHistory = Self.chartSamples(model.chargerInputHistory)
        chipPowerHistory = Self.chartSamples(model.chipPowerHistory)
        netInBps = model.netInBps
        netOutBps = model.netOutBps
        currentCountry = model.currentCountry
        batteryPct = model.batteryPct
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
        VStack(alignment: .leading, spacing: 5) {
            CodexQuotaStrip(snapshot: snapshot)

            SystemResourceCard(snapshot: snapshot)
                .padding(.horizontal, 10)

            HStack(spacing: 6) {
                PowerTrendCard(title: "充电输入趋势",
                               systemImage: "bolt.fill",
                               value: snapshot.chargerInputWatts,
                               history: snapshot.chargerInputHistory,
                               color: Color(hex: "18A957"))
                PowerTrendCard(title: "芯片功耗趋势",
                               systemImage: "cpu",
                               value: snapshot.totalPower,
                               history: snapshot.chipPowerHistory,
                               color: Color(hex: "2563EB"))
            }
            .padding(.horizontal, 10)

            if snapshot.fanRPM > 0 {
                FanReasonPanel(reasons: snapshot.fanReasons, stopAdvice: snapshot.fanStopAdvice)
                    .padding(.horizontal, 10)
            }

            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    MiniStat("风扇转速", fanText)
                    MiniStat("网速", "↓\(fmtB(snapshot.netInBps))/s  ↑\(fmtB(snapshot.netOutBps))/s")
                }

                HStack(spacing: 6) {
                    MiniStat("当前国家", snapshot.currentCountry)
                    MiniStat("电池", "\(snapshot.batteryPct)%")
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 1)
        }
    }
}

private struct SoftPanelBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(0.74))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
            )
            .shadow(color: Color(hex: "64748B").opacity(0.10), radius: 12, x: 0, y: 6)
    }
}

private struct SystemResourceCard: View {
    let snapshot: CompactStatusSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("系统资源", systemImage: "speedometer")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "17213A"))

            VStack(spacing: 4) {
                ResourceMetricRow(title: "处理器",
                                  systemImage: "cpu",
                                  pct: Double(snapshot.cpuUsage),
                                  color: Color(hex: "F05A24"),
                                  value: "\(snapshot.cpuUsage)%")
                ResourceMetricRow(title: "图形",
                                  systemImage: "display",
                                  pct: Double(snapshot.gpuUsage),
                                  color: Color(hex: "F59E0B"),
                                  value: "\(snapshot.gpuUsage)%")
                ResourceMetricRow(title: "存储",
                                  systemImage: "internaldrive",
                                  pct: snapshot.storagePctPrecise,
                                  color: Color(hex: "7C3AED"),
                                  value: String(format: "%.1f%%", snapshot.storagePctPrecise))
            }

            TemperatureBand(cpuTemp: snapshot.cpuTemp,
                            gpuTemp: snapshot.gpuTemp,
                            cpuDieHotspot: snapshot.cpuDieHotspot)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(SoftPanelBackground(cornerRadius: 14))
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
        HStack(spacing: 0) {
            TemperatureBandItem(systemImage: "cpu", label: "CPU", temp: cpuTemp)
            Divider().frame(height: 16)
            TemperatureBandItem(systemImage: "display", label: "图形", temp: gpuTemp)
            if cpuDieHotspot > 0 {
                Divider().frame(height: 16)
                TemperatureBandItem(systemImage: "flame.fill", label: "热点", temp: cpuDieHotspot)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color(hex: "F4F6FB").opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

private struct TemperatureBandItem: View {
    let systemImage: String
    let label: String
    let temp: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(tempColor(temp))
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(tempColor(temp))
            Text(String(format: "%.0f°C", temp))
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(tempColor(temp))
        }
        .frame(maxWidth: .infinity)
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
        guard let first = history.first, first > 0.05 else { return "实时同步" }
        let delta = (value - first) / first * 100
        let arrow = delta >= 0 ? "↑" : "↓"
        return String(format: "较4小时前 %@ %.0f%%", arrow, abs(delta))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Color(hex: "17213A"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                Spacer(minLength: 0)
                Text("4小时⌄")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(Color(hex: "5D6B88"))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(hex: "EEF1F7"))
                    .clipShape(Capsule())
            }
            Text(String(format: "%.1f W", value))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(deltaText)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(color.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            PowerTrendChart(values: history, color: color)
                .frame(height: 29)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(SoftPanelBackground(cornerRadius: 14))
    }
}

private struct PowerTrendChart: View {
    let values: [Double]
    let color: Color

    private var samples: [Double] {
        let cleaned = values.map { max(0, $0) }
        return cleaned.count >= 2 ? cleaned : [0, 0]
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
            let leftInset: CGFloat = 17
            let rightInset: CGFloat = 3
            let chartW = max(1, geo.size.width - leftInset - rightInset)
            let chartH = max(1, geo.size.height - topInset - bottomInset)
            let data = samples
            let maxValue = Swift.max(30, ceil((data.max() ?? 1) / 10) * 10)
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
                ForEach(Array(tickValues.enumerated()), id: \.offset) { _, tick in
                    Text("\(Int(tick.rounded()))W")
                        .font(.system(size: 6, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "5D6B88"))
                        .position(x: 9, y: topInset + chartH * CGFloat((maxValue - tick) / maxValue))
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

                HStack {
                    Text("-4h")
                    Spacer()
                    Text("-3h")
                    Spacer()
                    Text("-2h")
                    Spacer()
                    Text("-1h")
                    Spacer()
                    Text("现在")
                }
                .font(.system(size: 6, weight: .medium))
                .foregroundColor(Color(hex: "5D6B88"))
                .frame(width: chartW)
                .position(x: leftInset + chartW / 2, y: geo.size.height - 5)
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

    private var samples: [Double] {
        let cleaned = values.suffix(28).map { max(0, $0) }
        return cleaned.isEmpty ? [0, 0] : cleaned
    }

    var body: some View {
        GeometryReader { geo in
            let data = samples
            let minValue = data.min() ?? 0
            let maxValue = Swift.max((data.max() ?? 1), minValue + 1)
            let range = maxValue - minValue
            let points = data.enumerated().map { index, value in
                CGPoint(x: geo.size.width * CGFloat(index) / CGFloat(max(data.count - 1, 1)),
                        y: geo.size.height - geo.size.height * CGFloat((value - minValue) / range))
            }

            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: geo.size.height))
                    points.forEach { path.addLine(to: $0) }
                    if let last = points.last {
                        path.addLine(to: CGPoint(x: last.x, y: geo.size.height))
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
        HStack(spacing: 6) {
            HStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(LinearGradient(colors: [Color(hex: "111827"),
                                                      Color(hex: "263146")],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                    Image(systemName: "terminal")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(planTitle)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "111827"))
                        .lineLimit(1)
                    Text(snapshot.codexTodayTokensText)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "5D6B88"))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(0)

            Rectangle()
                .fill(Color(hex: "D9DEE8"))
                .frame(width: 1, height: 32)

            CodexQuotaColumn(label: "5小时余",
                             pct: snapshot.codexFiveHourRemainingPct,
                             caption: snapshot.codexFiveHourResetText.isEmpty ? "预计剩余" : snapshot.codexFiveHourResetText,
                             color: quotaColor(snapshot.codexFiveHourRemainingPct))
                .layoutPriority(2)

            Rectangle()
                .fill(Color(hex: "D9DEE8"))
                .frame(width: 1, height: 32)

            CodexQuotaColumn(label: "周余",
                             pct: snapshot.codexWeeklyRemainingPct,
                             caption: snapshot.codexWeeklyResetText.isEmpty ? "预计剩余" : snapshot.codexWeeklyResetText,
                             color: quotaColor(snapshot.codexWeeklyRemainingPct))
                .layoutPriority(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(SoftPanelBackground(cornerRadius: 14))
        .padding(.horizontal, 10)
    }

    private func quotaColor(_ remaining: Int) -> Color {
        if remaining <= 10 { return Color(hex: "DC2626") }
        if remaining <= 30 { return Color(hex: "F05A24") }
        return Color(hex: "16A34A")
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
        VStack(alignment: .leading, spacing: 5) {
            Label("风扇原因", systemImage: "fan")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "17213A"))

            VStack(spacing: 3) {
                ForEach(Array(reasons.prefix(3).enumerated()), id: \.offset) { index, reason in
                    FanReasonRow(index: index + 1,
                                 text: reason,
                                 pct: fanReasonPercent(reason, index: index))
                }
            }

            Text("强停建议：\(stopAdvice)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(stopAdvice.hasPrefix("可") ? Color(hex: "B45309") : Color(hex: "15803D"))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(SoftPanelBackground(cornerRadius: 14))
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
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "2563EB"))
                .frame(width: 14, height: 14)
                .background(Color(hex: "DBEAFE"))
                .clipShape(RoundedRectangle(cornerRadius: 5))

            Text(text)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Color(hex: "17213A"))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "E7E9F0"))
                    Capsule().fill(Color(hex: "2563EB"))
                        .frame(width: geo.size.width * CGFloat(max(0, min(pct, 100))) / 100)
                }
            }
            .frame(width: 50, height: 4)

            Text("\(pct)%")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "17213A"))
                .frame(width: 24, alignment: .trailing)
        }
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
                Text("登录 macOS 时自动启动 Nexus。")
                    .font(.system(size: 11)).foregroundColor(Color(hex: "666680"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("桌面小组件", isOn: $enableWidget)
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "30D158")))
                Text("右键桌面 → 编辑小组件 → 查找 Nexus。")
                    .font(.system(size: 11)).foregroundColor(Color(hex: "666680"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Color.white.opacity(0.1))

            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Nexus  v\(updater.currentVersion)")
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
