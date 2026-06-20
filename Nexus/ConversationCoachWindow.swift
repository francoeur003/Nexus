import AppKit
import SwiftUI

@MainActor
final class ConversationCoachWindowController {
    static let shared = ConversationCoachWindowController()

    private var panel: NSPanel?

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let size = NSSize(width: 940, height: 590)
        let origin = NSPoint(x: screenFrame.maxX - size.width - 28,
                             y: screenFrame.maxY - size.height - 28)

        let panel = CoachPanel(contentRect: NSRect(origin: origin, size: size),
                               styleMask: [.titled, .fullSizeContentView, .closable, .resizable],
                               backing: .buffered,
                               defer: false)
        panel.title = "Hermes 会议翻译板"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.minSize = NSSize(width: 820, height: 500)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.contentViewController = NSHostingController(
            rootView: ConversationCoachPanel()
                .preferredColorScheme(.light)
        )
        return panel
    }
}

private final class CoachPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct ConversationCoachPanel: View {
    @ObservedObject private var recorder = RecordingController.shared

    private var statusText: String {
        if recorder.isPreparing { return "准备中" }
        if recorder.isCallRecording { return recorder.liveModeText }
        if recorder.isTranscribing { return "转写中" }
        if recorder.isAnalyzing { return "分析中" }
        if recorder.lastRecordingURL != nil { return "已保存" }
        return "待开始"
    }

    private var statusColor: Color {
        if recorder.isCallRecording { return Color(hex: "FF453A") }
        if recorder.isTranscribing { return Color(hex: "2563EB") }
        if recorder.isAnalyzing { return Color(hex: "8C35F2") }
        if recorder.lastRecordingURL != nil { return Color(hex: "18A957") }
        return Color(hex: "2563EB")
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow)
            LinearGradient(colors: [
                Color.white.opacity(0.76),
                Color(hex: "EEF5FF").opacity(0.58),
                Color(hex: "F7ECFF").opacity(0.42)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)

            VStack(alignment: .leading, spacing: 12) {
                header
                HStack(spacing: 12) {
                    TranscriptColumn(status: recorder.transcriptionStatus,
                                     lines: recorder.liveTranscriptLines)
                        .frame(width: 550)
                    SummaryColumn(status: recorder.coachStatus,
                                  cards: recorder.liveSummaryCards)
                        .frame(width: 346)
                }
                .frame(height: 420)
                footer
            }
            .padding(16)
        }
        .frame(width: 940, height: 590)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.68), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(statusColor.opacity(0.14))
                Image(systemName: recorder.isCallRecording ? "waveform.circle.fill" : "sparkles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(statusColor)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Hermes 双栏会议板")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Color(hex: "111827"))
                Text("说话人记录 / 20秒理解 / 回应建议")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "5D6B88"))
            }

            Spacer()

            Text(statusText)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(statusColor)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(statusColor.opacity(0.11))
                .clipShape(Capsule())

            Button {
                ConversationCoachWindowController.shared.close()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(CoachIconButtonStyle())
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                recorder.toggleCallRecording()
            } label: {
                Label(recorder.isCallRecording ? "停止监听" : "开始监听",
                      systemImage: recorder.isCallRecording ? "stop.fill" : "mic.fill")
            }
            .buttonStyle(CoachButtonStyle(tint: recorder.isCallRecording ? Color(hex: "FF453A") : Color(hex: "18A957"),
                                          isPrimary: true))
            .disabled(recorder.isPreparing)

            Button {
                recorder.revealLastRecording()
            } label: {
                Label("显示文件", systemImage: "folder")
            }
            .buttonStyle(CoachButtonStyle(tint: Color(hex: "2563EB")))
            .disabled(recorder.lastRecordingURL == nil)

            Button {
                recorder.transcribeLastRecording()
            } label: {
                Label(recorder.isTranscribing ? "转写中" : "转写校正",
                      systemImage: recorder.isTranscribing ? "hourglass" : "text.badge.checkmark")
            }
            .buttonStyle(CoachButtonStyle(tint: Color(hex: "8C35F2")))
            .disabled(recorder.lastRecordingURL == nil || recorder.isCallRecording || recorder.isTranscribing)

            Button {
                recorder.revealLastTranscript()
            } label: {
                Label("打开笔记", systemImage: "doc.text")
            }
            .buttonStyle(CoachButtonStyle(tint: Color(hex: "18A957")))
            .disabled(recorder.lastTranscriptURL == nil)

            Button {
                recorder.analyzeLastTranscriptWithHermes()
            } label: {
                Label(recorder.isAnalyzing ? "生成中" : "生成建议",
                      systemImage: recorder.isAnalyzing ? "hourglass" : "sparkles")
            }
            .buttonStyle(CoachButtonStyle(tint: Color(hex: "8C35F2")))
            .disabled(recorder.lastTranscriptURL == nil || recorder.isAnalyzing)

            Button {
                recorder.revealLastAnalysis()
            } label: {
                Label("打开建议", systemImage: "doc.badge.gearshape")
            }
            .buttonStyle(CoachButtonStyle(tint: Color(hex: "2563EB")))
            .disabled(recorder.lastAnalysisURL == nil)

            Spacer(minLength: 0)
        }
        .frame(height: 42)
    }
}

private struct TranscriptColumn: View {
    let status: String
    let lines: [TranscriptLine]

    var body: some View {
        GlassColumn(title: "实时记录",
                    systemImage: "person.wave.2.fill",
                    tint: Color(hex: "2563EB"),
                    status: status) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(lines) { line in
                            TranscriptRow(line: line)
                                .id(line.id)
                        }
                    }
                    .padding(.top, 4)
                }
                .onChange(of: lines.count) { _ in
                    guard let lastID = lines.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct SummaryColumn: View {
    let status: String
    let cards: [MeetingSummaryCard]

    var body: some View {
        GlassColumn(title: "实时翻译",
                    systemImage: "quote.bubble.fill",
                    tint: Color(hex: "8C35F2"),
                    status: status) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 9) {
                        ForEach(cards) { card in
                            SummaryCardRow(card: card)
                                .id(card.id)
                        }
                    }
                    .padding(.top, 4)
                }
                .onChange(of: cards.count) { _ in
                    guard let lastID = cards.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct GlassColumn<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    let status: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "111827"))
                Spacer()
                Text(status)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(tint)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(tint.opacity(0.10))
                    .clipShape(Capsule())
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.52))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.72), lineWidth: 0.8)
                )
        )
    }
}

private struct TranscriptRow: View {
    let line: TranscriptLine

    private var tint: Color {
        speakerTint(line.speaker)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            SpeakerBadge(label: line.speaker, tint: tint)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(line.rawSpeaker == line.speaker ? line.speaker : "\(line.speaker) / \(line.rawSpeaker)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(tint)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(line.timeRange)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "718096"))
                }

                Text(line.text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "111827"))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(line.isFinal ? Color.white.opacity(0.50) : tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(line.isFinal ? Color.white.opacity(0.54) : tint.opacity(0.20), lineWidth: 0.7)
        )
    }
}

private struct SummaryCardRow: View {
    let card: MeetingSummaryCard

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(card.window)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "8C35F2"))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Color(hex: "8C35F2").opacity(0.11))
                    .clipShape(Capsule())
                Text(card.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "111827"))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Circle()
                    .fill(card.isFinal ? Color(hex: "18A957") : Color(hex: "F59E0B"))
                    .frame(width: 7, height: 7)
            }

            Text(card.body)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "111827"))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let action = card.action, !action.isEmpty {
                Text(action)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "0E8F4E"))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "18A957").opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.white.opacity(0.54))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color.white.opacity(0.62), lineWidth: 0.7)
        )
    }
}

private struct SpeakerBadge: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(String(label.prefix(2)))
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(tint)
            .minimumScaleFactor(0.7)
            .frame(width: 32, height: 32)
            .background(tint.opacity(0.13))
            .clipShape(Circle())
            .padding(.leading, 8)
            .padding(.top, 8)
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

private struct CoachButtonStyle: ButtonStyle {
    let tint: Color
    var isPrimary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(tint)
            .padding(.horizontal, isPrimary ? 12 : 10)
            .frame(height: 32)
            .background(tint.opacity(configuration.isPressed ? 0.20 : (isPrimary ? 0.14 : 0.10)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct CoachIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Color(hex: "5D6B88"))
            .frame(width: 30, height: 30)
            .background(Color.white.opacity(configuration.isPressed ? 0.76 : 0.54))
            .clipShape(Circle())
    }
}

private func speakerTint(_ speaker: String) -> Color {
    if speaker.hasPrefix("A") || speaker == "我" {
        return Color(hex: "2563EB")
    }
    if speaker.hasPrefix("B") {
        return Color(hex: "18A957")
    }
    if speaker.hasPrefix("C") {
        return Color(hex: "F97316")
    }
    if speaker.hasPrefix("D") {
        return Color(hex: "8C35F2")
    }
    return Color(hex: "64748B")
}
