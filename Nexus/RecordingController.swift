import AppKit
import AVFoundation
import CoreGraphics
import ScreenCaptureKit
import Speech

struct TranscriptLine: Identifiable, Equatable {
    let id = UUID()
    let timeRange: String
    let speaker: String
    let rawSpeaker: String
    let text: String
    let isFinal: Bool
    let startSeconds: Double
}

struct MeetingSummaryCard: Identifiable, Equatable {
    let id = UUID()
    let window: String
    let title: String
    let body: String
    let action: String?
    let isFinal: Bool
    let startSeconds: Double
}

@MainActor
final class RecordingController: NSObject, ObservableObject {
    static let shared = RecordingController()

    @Published private(set) var isCallRecording = false
    @Published private(set) var isPreparing = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var isAnalyzing = false
    @Published private(set) var transcriptionStatus = "待转写"
    @Published private(set) var coachStatus = "待分析"
    @Published private(set) var coachAnswer = "开始监听后，左边实时记录对话，右边每 20 秒解释对方真实意思并给出回应建议。"
    @Published private(set) var lastRecordingURL: URL?
    @Published private(set) var lastTranscriptURL: URL?
    @Published private(set) var lastAnalysisURL: URL?
    @Published private(set) var liveModeText = "待开始"
    @Published private(set) var liveTranscriptLines: [TranscriptLine] = [
        TranscriptLine(timeRange: "00:00",
                       speaker: "A?",
                       rawSpeaker: "实时分段",
                       text: "等待开始记录。",
                       isFinal: false,
                       startSeconds: 0)
    ]
    @Published private(set) var liveSummaryCards: [MeetingSummaryCard] = [
        MeetingSummaryCard(window: "待开始",
                           title: "20秒理解",
                           body: "开始监听后，这里会按时间窗口滚动更新。",
                           action: nil,
                           isFinal: false,
                           startSeconds: 0)
    ]

    private var stream: SCStream?
    private var audioWriter: AnyObject?
    private var microphoneRecorder: AVAudioRecorder?
    private var currentOutputURL: URL?
    private var summaryTimer: Timer?
    private var recordingStartDate: Date?
    private var summaryWindowIndex = 0
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_CN"))
    private var speechAudioEngine: AVAudioEngine?
    private var speechRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechRecognitionTask: SFSpeechRecognitionTask?
    private var liveRecognizedText = ""
    private var liveLastAnalyzedText = ""
    private var liveAnalysisProcess: Process?
    private var liveEnglishAnnotationProcesses: [String: Process] = [:]
    private var liveEnglishAnnotationCache: [String: String] = [:]
    private var didAutoStartLiveInterpreter = false

    func autoStartLiveInterpreterIfIdle() {
        guard !didAutoStartLiveInterpreter,
              !isCallRecording,
              !isPreparing,
              !isTranscribing else { return }
        didAutoStartLiveInterpreter = true
        appendRecordingLog("autoStartLiveInterpreterIfIdle")
        ConversationCoachWindowController.shared.show()
        startCallRecording()
    }

    func toggleCallRecording() {
        appendRecordingLog("toggleCallRecording isCallRecording=\(isCallRecording) isPreparing=\(isPreparing)")
        if isCallRecording {
            stopCallRecording()
        } else {
            ConversationCoachWindowController.shared.show()
            startCallRecording()
        }
    }

    func revealLastRecording() {
        guard let lastRecordingURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastRecordingURL])
    }

    func revealLastTranscript() {
        guard let lastTranscriptURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastTranscriptURL])
    }

    func revealLastAnalysis() {
        guard let lastAnalysisURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastAnalysisURL])
    }

    func transcribeLastRecording(autoAnalyze: Bool = false) {
        guard let lastRecordingURL, !isCallRecording, !isPreparing, !isTranscribing else { return }
        appendRecordingLog("transcribe start file=\(lastRecordingURL.path) autoAnalyze=\(autoAnalyze)")

        isTranscribing = true
        transcriptionStatus = "转写中"
        liveModeText = "转写校正"
        liveTranscriptLines = [
            TranscriptLine(timeRange: "00:00",
                           speaker: "A",
                           rawSpeaker: "S1",
                           text: "正在把录音整理成按说话人排列的逐字稿。",
                           isFinal: false,
                           startSeconds: 0)
        ]
        lastTranscriptURL = nil

        let script = "/Users/abo/Desktop/土豆大王/自动化脚本与运行数据/scripts/whisper_transcribe.py"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3",
            script,
            lastRecordingURL.path,
            "--timeout", "1800",
            "--archive-root", "/Users/abo/Desktop/录音文档",
            "--obsidian-dir", "/Users/abo/Documents/Obsidian Vault/工作记录/对象库/录音文档",
            "--identify-speakers",
            "--max-speakers", "4"
        ]
        process.environment = [
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": NSHomeDirectory()
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { [weak self] finishedProcess in
            let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let noteURL = Self.extractOutputURL(from: stdout, marker: "📝 已写入 Obsidian 笔记:")

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isTranscribing = false
                if finishedProcess.terminationStatus == 0 {
                    if let noteURL {
                        self.appendRecordingLog("transcribe success note=\(noteURL.path)")
                        self.transcriptionStatus = "转写完成"
                        self.lastTranscriptURL = noteURL
                        self.loadTranscriptTimeline(for: lastRecordingURL)
                        let localCards = self.buildTwentySecondCards(from: self.liveTranscriptLines)
                        if !localCards.isEmpty {
                            self.liveSummaryCards = localCards
                        }
                        if autoAnalyze {
                            self.analyzeLastTranscriptWithHermes()
                        }
                    } else {
                        self.appendRecordingLog("transcribe success but note marker missing")
                        self.transcriptionStatus = "转写完成，未找到笔记"
                        self.coachStatus = "等待手动分析"
                        self.loadTranscriptTimeline(for: lastRecordingURL)
                        let localCards = self.buildTwentySecondCards(from: self.liveTranscriptLines)
                        if !localCards.isEmpty {
                            self.liveSummaryCards = localCards
                        }
                    }
                } else {
                    let message = stderr.isEmpty ? stdout : stderr
                    self.appendRecordingLog("transcribe failed status=\(finishedProcess.terminationStatus) message=\(message.prefix(300))")
                    self.transcriptionStatus = "转写失败"
                    self.showAlert(title: "转写失败", message: message.isEmpty ? "whisper_transcribe.py 运行失败。" : message)
                }
            }
        }

        do {
            try process.run()
        } catch {
            appendRecordingLog("transcribe launch failed \(error.localizedDescription)")
            isTranscribing = false
            transcriptionStatus = "转写失败"
            showAlert(title: "无法启动转写", message: error.localizedDescription)
        }
    }

    func analyzeLastTranscriptWithHermes() {
        guard let lastTranscriptURL, !isAnalyzing else { return }
        appendRecordingLog("hermes analyze start note=\(lastTranscriptURL.path)")

        let transcript: String
        do {
            transcript = try String(contentsOf: lastTranscriptURL, encoding: .utf8)
        } catch {
            showAlert(title: "无法读取转写笔记", message: error.localizedDescription)
            return
        }

        isAnalyzing = true
        coachStatus = "Hermes 分析中"
        coachAnswer = "Hermes 正在读取转写内容，生成回答建议..."
        lastAnalysisURL = nil

        let clippedTranscript = String(transcript.prefix(30_000))
        let timeline = String(formattedTimelineForPrompt().prefix(18_000))
        let prompt = """
        你是 abo 的实时会议副驾。请基于下面的会议/对话转写，用中文输出一份极简但可执行的“中对中翻译 + 回答建议”。

        输出格式固定为：
        20秒滚动理解：
        - 00:00-00:20｜意思：这一段真实在推进什么｜你该回应：一句能直接说出口的话
        - 00:20-00:40｜意思：...｜你该回应：...
        老板真正意思：
        他现在需要听到：
        建议你这样回：
        别这样回：
        TODO：

        要求：
        - 不要复述全文。
        - 重点解释对方真实意图、业务边界、风险和下一步。
        - “建议你这样回”必须能直接复制给对方说。
        - 如果信息不足，直接列出需要追问的 1-3 个问题。
        - 20秒滚动理解要按时间窗口输出；没有内容的窗口不要硬编。

        按说话人时间线：
        \(timeline.isEmpty ? "暂无结构化时间线" : timeline)

        完整笔记补充：
        \(clippedTranscript)
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["hermes", "-z", prompt]
        process.environment = [
            "PATH": "/Users/abo/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": NSHomeDirectory()
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: "/Users/abo/Desktop/土豆大王")

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { [weak self] finishedProcess in
            let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAnalyzing = false
                if finishedProcess.terminationStatus == 0, !stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let answer = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.appendRecordingLog("hermes analyze success")
                    self.coachStatus = "建议已生成"
                    self.coachAnswer = answer
                    self.refreshSummaryCards(fromHermesAnswer: answer)
                    self.lastAnalysisURL = self.writeHermesAnalysis(answer, beside: lastTranscriptURL)
                } else {
                    let message = stderr.isEmpty ? stdout : stderr
                    self.appendRecordingLog("hermes analyze failed status=\(finishedProcess.terminationStatus) message=\(message.prefix(300))")
                    self.coachStatus = "分析失败"
                    self.coachAnswer = "Hermes 分析失败。"
                    let localCards = self.buildTwentySecondCards(from: self.liveTranscriptLines)
                    if !localCards.isEmpty {
                        self.liveSummaryCards = localCards
                    }
                    self.showAlert(title: "Hermes 分析失败", message: message.isEmpty ? "hermes -z 未返回内容。" : message)
                }
            }
        }

        do {
            try process.run()
        } catch {
            appendRecordingLog("hermes launch failed \(error.localizedDescription)")
            isAnalyzing = false
            coachStatus = "分析失败"
            coachAnswer = "无法启动 Hermes。"
            showAlert(title: "无法启动 Hermes", message: error.localizedDescription)
        }
    }

    func openScreenRecorderPicker() {
        do {
            let outputURL = try makeOutputURL(prefix: "录屏", ext: "mov")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-v", "-g", "-i", "-J", "video", "-U", outputURL.path]
            process.terminationHandler = { [weak self] finishedProcess in
                guard finishedProcess.terminationStatus == 0,
                      FileManager.default.fileExists(atPath: outputURL.path) else { return }
                Task { @MainActor [weak self] in
                    self?.showFinishedAlert(title: "录屏已保存", outputURL: outputURL)
                }
            }
            try process.run()
        } catch {
            showAlert(title: "无法打开录屏", message: error.localizedDescription)
        }
    }

    private func startCallRecording() {
        guard #available(macOS 15.0, *) else {
            appendRecordingLog("macOS below 15 fallback QuickTime")
            openQuickTimeAudioRecorder()
            return
        }
        guard !isPreparing else { return }
        appendRecordingLog("startCallRecording begin")
        isPreparing = true

        Task {
            do {
                let microphoneAllowed = await requestMicrophoneAccess()
                appendRecordingLog("microphoneAllowed=\(microphoneAllowed)")
                guard microphoneAllowed else {
                    throw RecordingError.microphoneDenied
                }

                let screenCaptureAllowed = requestScreenCaptureAccess()
                appendRecordingLog("screenCaptureAllowed=\(screenCaptureAllowed)")
                guard screenCaptureAllowed else {
                    openScreenCapturePrivacySettings()
                    try startMicrophoneOnlyRecording()
                    return
                }

                let content = try await SCShareableContent.current
                guard let display = content.displays.first else {
                    appendRecordingLog("no display for screen capture, fallback microphone only")
                    try startMicrophoneOnlyRecording()
                    return
                }

                let bundleID = Bundle.main.bundleIdentifier
                let currentApp = content.applications.first { app in
                    guard let bundleID else { return false }
                    return app.bundleIdentifier == bundleID
                }
                let excludedApps = currentApp.map { [$0] } ?? []

                let filter = SCContentFilter(display: display,
                                             excludingApplications: excludedApps,
                                             exceptingWindows: [])

                let configuration = SCStreamConfiguration()
                configuration.width = 320
                configuration.height = 180
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
                configuration.showsCursor = false
                configuration.capturesAudio = true
                configuration.excludesCurrentProcessAudio = true
                configuration.sampleRate = 48_000
                configuration.channelCount = 2
                configuration.captureMicrophone = true

                let outputURL = try makeOutputURL(prefix: "通话录音", ext: "m4a")
                let nextWriter = try AudioOnlyWriter(outputURL: outputURL)
                let nextStream = SCStream(filter: filter, configuration: configuration, delegate: self)
                try nextStream.addStreamOutput(nextWriter, type: .audio, sampleHandlerQueue: nextWriter.sampleQueue)
                try nextStream.addStreamOutput(nextWriter, type: .microphone, sampleHandlerQueue: nextWriter.sampleQueue)

                try await nextStream.startCapture()

                stream = nextStream
                audioWriter = nextWriter
                currentOutputURL = outputURL
                lastRecordingURL = nil
                lastTranscriptURL = nil
                lastAnalysisURL = nil
                resetLiveWorkspace(recordingMode: "系统+麦克风")
                transcriptionStatus = "实时监听中"
                coachStatus = "等待转写"
                coachAnswer = "正在监听。左边会实时出现对话，右边会按 20 秒解释对方真实意思和建议回复。"
                isCallRecording = true
                isPreparing = false
                startLiveSpeechRecognition()
                startSummaryTicker()
                appendRecordingLog("startCallRecording success output=\(outputURL.path)")
            } catch {
                isPreparing = false
                cleanupRecordingState()
                appendRecordingLog("startCallRecording failed \(error.localizedDescription)")
                showAlert(title: "监听启动失败", message: error.localizedDescription)
            }
        }
    }

    private func stopCallRecording() {
        guard !isPreparing else { return }
        appendRecordingLog("stopCallRecording begin")
        if let microphoneRecorder {
            microphoneRecorder.stop()
            let outputURL = currentOutputURL
            cleanupRecordingState()
            if let outputURL {
                lastRecordingURL = outputURL
                appendRecordingLog("stopMicrophoneOnlyRecording saved output=\(outputURL.path)")
                transcriptionStatus = "监听文件已保存"
                coachStatus = "自动转写中"
                coachAnswer = "麦克风监听文件已保存，正在自动转写；转写完成后会自动生成回答建议。"
                transcribeLastRecording(autoAnalyze: true)
            }
            return
        }
        guard let stream else {
            cleanupRecordingState()
            return
        }

        isPreparing = true
        Task {
            do {
                try await stream.stopCapture()
                let outputURL = currentOutputURL
                try await finishAudioWriter()
                if let outputURL {
                    lastRecordingURL = outputURL
                }
                cleanupRecordingState()
                isPreparing = false
                if outputURL != nil {
                    appendRecordingLog("stopCallRecording saved output=\(outputURL?.path ?? "")")
                    transcriptionStatus = "监听文件已保存"
                    coachStatus = "自动转写中"
                    coachAnswer = "监听文件已保存，正在自动转写；转写完成后会自动生成回答建议。"
                    transcribeLastRecording(autoAnalyze: true)
                }
            } catch {
                cleanupRecordingState()
                isPreparing = false
                appendRecordingLog("stopCallRecording failed \(error.localizedDescription)")
                showAlert(title: "停止监听失败", message: error.localizedDescription)
            }
        }
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    private func requestScreenCaptureAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        return CGRequestScreenCaptureAccess()
    }

    private func startMicrophoneOnlyRecording() throws {
        let outputURL = try makeOutputURL(prefix: "麦克风录音", ext: "m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 96_000
        ]
        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.isMeteringEnabled = false
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw RecordingError.microphoneRecorderFailed
        }

        microphoneRecorder = recorder
        currentOutputURL = outputURL
        lastRecordingURL = nil
        lastTranscriptURL = nil
        lastAnalysisURL = nil
        resetLiveWorkspace(recordingMode: "麦克风")
        transcriptionStatus = "仅麦克风监听中"
        coachStatus = "实时监听中"
        coachAnswer = "已先进入麦克风监听模式：左边实时记录现场对话，右边按 20 秒做中译中解释。"
        isCallRecording = true
        isPreparing = false
        startLiveSpeechRecognition()
        startSummaryTicker()
        appendRecordingLog("startMicrophoneOnlyRecording success output=\(outputURL.path)")
    }

    private func openScreenCapturePrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func makeOutputURL(prefix: String, ext: String) throws -> URL {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/土豆大王/录音录屏", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "\(prefix)-\(formatter.string(from: Date())).\(ext)"
        return root.appendingPathComponent(filename)
    }

    private func openQuickTimeAudioRecorder() {
        let script = """
        tell application "QuickTime Player"
            activate
            new audio recording
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        do {
            try process.run()
        } catch {
            showAlert(title: "无法打开录音", message: error.localizedDescription)
        }
    }

    private func cleanupRecordingState() {
        stopSummaryTicker()
        stopLiveSpeechRecognition()
        stream = nil
        audioWriter = nil
        microphoneRecorder = nil
        currentOutputURL = nil
        isCallRecording = false
    }

    private func resetLiveWorkspace(recordingMode: String) {
        recordingStartDate = Date()
        summaryWindowIndex = 0
        liveRecognizedText = ""
        liveLastAnalyzedText = ""
        liveEnglishAnnotationCache.removeAll()
        liveModeText = recordingMode
        liveTranscriptLines = [
            TranscriptLine(timeRange: "00:00",
                           speaker: "A?",
                           rawSpeaker: "实时分段",
                           text: "正在监听，实时阶段会按停顿分段；停止后会做 A/B/C 声纹校正。",
                           isFinal: false,
                           startSeconds: 0)
        ]
        liveSummaryCards = [
            MeetingSummaryCard(window: "00:00-00:20",
                               title: "实时中译中",
                               body: "正在收音。",
                               action: "听到内容后会解释对方是什么意思，以及你可以怎么回。",
                               isFinal: false,
                               startSeconds: 0)
        ]
    }

    private func startSummaryTicker() {
        stopSummaryTicker()
        summaryTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.appendLiveSummaryPlaceholder()
            }
        }
    }

    private func stopSummaryTicker() {
        summaryTimer?.invalidate()
        summaryTimer = nil
    }

    private func appendLiveSummaryPlaceholder() {
        guard isCallRecording else { return }
        summaryWindowIndex += 1
        let start = summaryWindowIndex * 20
        let end = start + 20
        requestLiveInterpretation(window: "\(formatSeconds(start))-\(formatSeconds(end))",
                                  startSeconds: Double(start))
    }

    private func startLiveSpeechRecognition() {
        guard speechRecognitionTask == nil else { return }
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            appendRecordingLog("live speech unavailable")
            transcriptionStatus = "实时识别不可用"
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard status == .authorized else {
                    self.appendRecordingLog("speech auth denied status=\(status.rawValue)")
                    self.transcriptionStatus = "语音识别未授权"
                    self.liveTranscriptLines = [
                        TranscriptLine(timeRange: "00:00",
                                       speaker: "A",
                                       rawSpeaker: "S1",
                                       text: "需要允许语音识别权限，才能实时显示对话内容。",
                                       isFinal: false,
                                       startSeconds: 0)
                    ]
                    return
                }
                self.activateLiveSpeechRecognition(with: speechRecognizer)
            }
        }
    }

    private func activateLiveSpeechRecognition(with recognizer: SFSpeechRecognizer) {
        stopLiveSpeechRecognition()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        speechRecognitionRequest = request
        speechAudioEngine = engine
        transcriptionStatus = "实时识别中"
        coachStatus = "实时中译中"

        speechRecognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.updateLiveTranscript(result)
                }
                if let error {
                    self.appendRecordingLog("live speech error \(error.localizedDescription)")
                }
            }
        }

        do {
            engine.prepare()
            try engine.start()
            appendRecordingLog("live speech recognition started")
        } catch {
            appendRecordingLog("live speech engine failed \(error.localizedDescription)")
            transcriptionStatus = "实时识别启动失败"
        }
    }

    private func stopLiveSpeechRecognition() {
        if let engine = speechAudioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        speechRecognitionRequest?.endAudio()
        speechRecognitionTask?.cancel()
        speechAudioEngine = nil
        speechRecognitionRequest = nil
        speechRecognitionTask = nil
        if let process = liveAnalysisProcess, process.isRunning {
            process.terminate()
        }
        liveAnalysisProcess = nil
        for process in liveEnglishAnnotationProcesses.values where process.isRunning {
            process.terminate()
        }
        liveEnglishAnnotationProcesses.removeAll()
    }

    private func updateLiveTranscript(_ result: SFSpeechRecognitionResult) {
        let transcription = result.bestTranscription
        let clean = transcription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean != liveRecognizedText else { return }
        liveRecognizedText = clean

        var rows = buildLiveTranscriptRows(from: transcription, isFinal: result.isFinal)
        if rows.isEmpty {
            let elapsed = Int(Date().timeIntervalSince(recordingStartDate ?? Date()))
            rows = [
                TranscriptLine(timeRange: "00:00-\(formatSeconds(elapsed))",
                               speaker: "A?",
                               rawSpeaker: "实时分段",
                               text: clean,
                               isFinal: result.isFinal,
                               startSeconds: 0)
            ]
        }

        liveTranscriptLines = rows.map { line in
            guard let annotated = liveEnglishAnnotationCache[line.text] else { return line }
            return TranscriptLine(timeRange: line.timeRange,
                                  speaker: line.speaker,
                                  rawSpeaker: line.rawSpeaker,
                                  text: annotated,
                                  isFinal: line.isFinal,
                                  startSeconds: line.startSeconds)
        }

        for (index, line) in rows.enumerated() where line.isFinal || index < rows.count - 1 {
            annotateEnglishIfNeeded(in: line)
        }

        liveModeText = "实时分段"
        transcriptionStatus = "实时识别中"
    }

    private func buildLiveTranscriptRows(from transcription: SFTranscription, isFinal: Bool) -> [TranscriptLine] {
        var rows: [TranscriptLine] = []
        var currentText = ""
        var currentStart = 0.0
        var currentEnd = 0.0
        var previousEnd: Double?
        var turnIndex = 0

        func flushCurrent(final: Bool) {
            let body = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return }
            let start = max(0, Int(currentStart.rounded(.down)))
            let end = max(start, Int(currentEnd.rounded(.up)))
            rows.append(
                TranscriptLine(timeRange: "\(formatSeconds(start))-\(formatSeconds(end))",
                               speaker: liveSpeakerLabel(for: turnIndex),
                               rawSpeaker: final ? "实时分段" : "实时分段中",
                               text: body,
                               isFinal: final,
                               startSeconds: currentStart)
            )
            turnIndex += 1
            currentText = ""
            currentStart = 0
            currentEnd = 0
        }

        for segment in transcription.segments {
            let token = segment.substring.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { continue }

            let start = max(0, segment.timestamp)
            let end = max(start, segment.timestamp + segment.duration)
            let gap = previousEnd.map { start - $0 } ?? 0
            let shouldSplit = !currentText.isEmpty
                && (gap > 1.05 || currentText.count >= 70 || hasSentenceEnding(currentText))

            if shouldSplit {
                flushCurrent(final: true)
            }
            if currentText.isEmpty {
                currentStart = start
            }
            currentText = appendSpeechToken(token, to: currentText)
            currentEnd = end
            previousEnd = end
        }

        if !currentText.isEmpty {
            flushCurrent(final: isFinal)
        }
        return rows
    }

    private func liveSpeakerLabel(for index: Int) -> String {
        let aliases = ["A?", "B?", "C?", "D?", "E?", "F?"]
        return aliases[index % aliases.count]
    }

    private func appendSpeechToken(_ token: String, to text: String) -> String {
        guard !text.isEmpty else { return token }
        guard let last = text.unicodeScalars.last,
              let first = token.unicodeScalars.first else {
            return text + token
        }
        if isClosingPunctuation(first) || isOpeningPunctuation(last) {
            return text + token
        }
        if isASCIILetterOrNumber(last) || isASCIILetterOrNumber(first) {
            return text + " " + token
        }
        return text + token
    }

    private func hasSentenceEnding(_ text: String) -> Bool {
        guard text.count >= 22 else { return false }
        return text.hasSuffix("。") || text.hasSuffix("？") || text.hasSuffix("！")
            || text.hasSuffix(".") || text.hasSuffix("?") || text.hasSuffix("!")
    }

    private func isASCIILetterOrNumber(_ scalar: UnicodeScalar) -> Bool {
        (65...90).contains(scalar.value)
            || (97...122).contains(scalar.value)
            || (48...57).contains(scalar.value)
    }

    private func isClosingPunctuation(_ scalar: UnicodeScalar) -> Bool {
        CharacterSet(charactersIn: "，。？！、；：,.?!;:%)]}）】》").contains(scalar)
    }

    private func isOpeningPunctuation(_ scalar: UnicodeScalar) -> Bool {
        CharacterSet(charactersIn: "([（【《").contains(scalar)
    }

    private func annotateEnglishIfNeeded(in line: TranscriptLine) {
        let original = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard containsEnglish(original),
              liveEnglishAnnotationCache[original] == nil,
              liveEnglishAnnotationProcesses[original] == nil else { return }

        let prompt = """
        只做一件事：保留下面原文顺序，把其中英文单词或英文短语后面补中文括号解释；中文部分不要改写，不要总结。
        示例：review deadline -> review（审阅/复盘） deadline（截止时间）
        只输出改好的同一行。

        原文：
        \(String(original.prefix(700)))
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["hermes", "-z", prompt]
        process.environment = [
            "PATH": "/Users/abo/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": NSHomeDirectory()
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: "/Users/abo/Desktop/土豆大王")

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { [weak self] finishedProcess in
            let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.liveEnglishAnnotationProcesses[original] = nil
                guard finishedProcess.terminationStatus == 0 else {
                    self.appendRecordingLog("english annotation failed status=\(finishedProcess.terminationStatus) message=\((stderr.isEmpty ? stdout : stderr).prefix(160))")
                    return
                }
                let annotated = self.cleanInlineHermesOutput(stdout, fallback: original)
                guard annotated != original else { return }
                self.liveEnglishAnnotationCache[original] = annotated
                self.applyEnglishAnnotation(original: original, annotated: annotated)
            }
        }

        do {
            liveEnglishAnnotationProcesses[original] = process
            try process.run()
        } catch {
            liveEnglishAnnotationProcesses[original] = nil
            appendRecordingLog("english annotation launch failed \(error.localizedDescription)")
        }
    }

    private func applyEnglishAnnotation(original: String, annotated: String) {
        liveTranscriptLines = liveTranscriptLines.map { line in
            guard line.text == original else { return line }
            return TranscriptLine(timeRange: line.timeRange,
                                  speaker: line.speaker,
                                  rawSpeaker: line.rawSpeaker,
                                  text: annotated,
                                  isFinal: line.isFinal,
                                  startSeconds: line.startSeconds)
        }
    }

    private func containsEnglish(_ text: String) -> Bool {
        text.range(of: #"[A-Za-z][A-Za-z0-9_+/\-.]*(\s+[A-Za-z][A-Za-z0-9_+/\-.]*)*"#,
                   options: .regularExpression) != nil
    }

    private func cleanInlineHermesOutput(_ output: String, fallback: String) -> String {
        var cleaned = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLine = cleaned.components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            cleaned = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if cleaned.hasPrefix("原文：") {
            cleaned = cleaned.replacingOccurrences(of: "原文：", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if cleaned.hasPrefix("输出：") {
            cleaned = cleaned.replacingOccurrences(of: "输出：", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned.isEmpty ? fallback : cleaned
    }

    private func requestLiveInterpretation(window: String, startSeconds: Double) {
        let timelineText = liveTranscriptLines
            .filter { !$0.text.contains("正在监听") && !$0.text.contains("需要允许语音识别权限") }
            .map { "[\($0.timeRange)] [\($0.speaker)/\($0.rawSpeaker)] \($0.text)" }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = timelineText.isEmpty
            ? liveRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
            : timelineText
        guard !fullText.isEmpty else {
            liveSummaryCards.append(
                MeetingSummaryCard(window: window,
                                   title: "实时中译中",
                                   body: "这一段暂时没有识别到清晰人声。",
                                   action: nil,
                                   isFinal: false,
                                   startSeconds: startSeconds)
            )
            return
        }

        let newText: String
        if fullText.hasPrefix(liveLastAnalyzedText) {
            newText = String(fullText.dropFirst(liveLastAnalyzedText.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            newText = fullText
        }

        guard newText.count >= 4 else {
            liveSummaryCards.append(
                MeetingSummaryCard(window: window,
                                   title: "实时中译中",
                                   body: "这一段新增内容太短，继续听。",
                                   action: nil,
                                   isFinal: false,
                                   startSeconds: startSeconds)
            )
            return
        }
        liveLastAnalyzedText = fullText

        guard liveAnalysisProcess?.isRunning != true else {
            liveSummaryCards.append(
                MeetingSummaryCard(window: window,
                                   title: "实时中译中",
                                   body: "上一段还在理解中。",
                                   action: "先看左边实时记录，右边稍后补解释。",
                                   isFinal: false,
                                   startSeconds: startSeconds)
            )
            return
        }

        coachStatus = "实时理解中"
        liveSummaryCards.append(
            MeetingSummaryCard(window: window,
                               title: "实时中译中",
                               body: "正在理解这一段。",
                               action: nil,
                               isFinal: false,
                               startSeconds: startSeconds)
        )
        runHermesLiveInterpretation(text: newText, context: fullText, window: window, startSeconds: startSeconds)
    }

    private func runHermesLiveInterpretation(text: String, context: String, window: String, startSeconds: Double) {
        let prompt = """
        你是 abo 的实时“中译中翻译机”和会议副驾。
        下面是最近 20 秒识别到的中文对话，请不要逐字复述，直接解释“对方到底是什么意思”，以及 abo 可以怎么回。

        固定输出：
        意思：
        对方需要听到：
        建议这样回：
        别这样回：

        要求：
        - 对象可能是老板、客户、同事，不要默认都是老板。
        - 左侧 A?/B?/C? 是实时停顿分段，不是最终声纹身份；不要把它当绝对说话人。
        - 如果出现英文，保留英文，并在英文后加中文括号解释。
        - “建议这样回”必须是可以直接说出口的一两句话。
        - 如果信息不足，给一个稳妥追问。
        - 输出必须简短。

        最近新增内容：
        \(String(text.prefix(1200)))

        当前上下文：
        \(String(context.suffix(2400)))
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["hermes", "-z", prompt]
        process.environment = [
            "PATH": "/Users/abo/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": NSHomeDirectory()
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: "/Users/abo/Desktop/土豆大王")

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { [weak self] finishedProcess in
            let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.liveAnalysisProcess = nil
                if finishedProcess.terminationStatus == 0 {
                    let answer = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.coachStatus = "实时中译中"
                    self.appendLiveInterpretationCard(answer: answer,
                                                      fallbackText: text,
                                                      window: window,
                                                      startSeconds: startSeconds)
                } else {
                    self.appendRecordingLog("live hermes failed status=\(finishedProcess.terminationStatus) message=\((stderr.isEmpty ? stdout : stderr).prefix(200))")
                    self.coachStatus = "实时理解失败"
                    self.appendLiveInterpretationCard(answer: "",
                                                      fallbackText: text,
                                                      window: window,
                                                      startSeconds: startSeconds)
                }
            }
        }

        do {
            liveAnalysisProcess = process
            try process.run()
        } catch {
            liveAnalysisProcess = nil
            coachStatus = "实时理解失败"
            appendRecordingLog("live hermes launch failed \(error.localizedDescription)")
            appendLiveInterpretationCard(answer: "", fallbackText: text, window: window, startSeconds: startSeconds)
        }
    }

    private func appendLiveInterpretationCard(answer: String, fallbackText: String, window: String, startSeconds: Double) {
        let meaning = extractSection("意思", from: answer) ?? String(fallbackText.prefix(220))
        let need = extractSection("对方需要听到", from: answer)
        let reply = extractSection("建议这样回", from: answer)
        let body = [meaning, need.map { "对方需要听到：\($0)" }]
            .compactMap { $0 }
            .joined(separator: "\n")

        liveSummaryCards.append(
            MeetingSummaryCard(window: window,
                               title: "中译中",
                               body: body.isEmpty ? "这一段已经记录，暂时没有提炼出明确意图。" : body,
                               action: reply,
                               isFinal: true,
                               startSeconds: startSeconds)
        )
    }

    private func loadTranscriptTimeline(for recordingURL: URL) {
        if let speakerURL = speakerTranscriptURL(for: recordingURL),
           let text = try? String(contentsOf: speakerURL, encoding: .utf8) {
            let lines = parseSpeakerTranscript(text)
            if !lines.isEmpty {
                liveTranscriptLines = lines
                liveModeText = "\(lines.count) 段已校正"
                appendRecordingLog("loaded speaker transcript lines=\(lines.count) file=\(speakerURL.path)")
                return
            }
        }

        if let jsonURL = transcriptJSONURL(for: recordingURL),
           let data = try? Data(contentsOf: jsonURL) {
            let lines = parseJSONTranscript(data)
            if !lines.isEmpty {
                liveTranscriptLines = lines
                liveModeText = "\(lines.count) 段已校正"
                appendRecordingLog("loaded json transcript lines=\(lines.count) file=\(jsonURL.path)")
                return
            }
        }

        liveTranscriptLines = [
            TranscriptLine(timeRange: "00:00",
                           speaker: "A",
                           rawSpeaker: "S1",
                           text: "转写完成，但没有找到可用于面板展示的说话人时间线。请打开笔记查看完整内容。",
                           isFinal: false,
                           startSeconds: 0)
        ]
        liveModeText = "待校正"
    }

    private func speakerTranscriptURL(for recordingURL: URL) -> URL? {
        let baseName = recordingURL.deletingPathExtension().lastPathComponent
        let candidates = [
            "/Users/abo/Desktop/录音文档/TXT/\(baseName)_transcript_speaker.txt",
            "/Users/abo/Desktop/录音文档/TXT/\(baseName)_transcript.txt"
        ]
        return candidates
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func transcriptJSONURL(for recordingURL: URL) -> URL? {
        let baseName = recordingURL.deletingPathExtension().lastPathComponent
        let candidates = [
            "/Users/abo/Desktop/录音文档/JSON/\(baseName)_transcript.json"
        ]
        return candidates
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func parseSpeakerTranscript(_ text: String) -> [TranscriptLine] {
        let pattern = #"^\[(.+?)\s*→\s*(.+?)\]\s+\[(.+?)\]\s+(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        return text.components(separatedBy: .newlines).compactMap { line in
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = regex.firstMatch(in: line, range: range),
                  match.numberOfRanges == 5,
                  let startRange = Range(match.range(at: 1), in: line),
                  let endRange = Range(match.range(at: 2), in: line),
                  let speakerRange = Range(match.range(at: 3), in: line),
                  let textRange = Range(match.range(at: 4), in: line) else {
                return nil
            }

            let startText = String(line[startRange])
            let endText = String(line[endRange])
            let rawSpeaker = String(line[speakerRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let body = String(line[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return nil }

            let startSeconds = seconds(from: startText)
            let endSeconds = seconds(from: endText)
            return TranscriptLine(timeRange: "\(formatSeconds(Int(startSeconds)))-\(formatSeconds(Int(endSeconds)))",
                                  speaker: speakerAlias(for: rawSpeaker),
                                  rawSpeaker: rawSpeaker,
                                  text: body,
                                  isFinal: true,
                                  startSeconds: startSeconds)
        }
    }

    private func parseJSONTranscript(_ data: Data) -> [TranscriptLine] {
        guard let decoded = try? JSONDecoder().decode(WhisperTranscript.self, from: data) else {
            return []
        }
        return decoded.segments.compactMap { segment in
            let body = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return nil }
            return TranscriptLine(timeRange: "\(formatSeconds(Int(segment.start)))-\(formatSeconds(Int(segment.end)) )",
                                  speaker: "A",
                                  rawSpeaker: "S1",
                                  text: body,
                                  isFinal: true,
                                  startSeconds: segment.start)
        }
    }

    private func buildTwentySecondCards(from lines: [TranscriptLine]) -> [MeetingSummaryCard] {
        let finalLines = lines.filter { $0.isFinal && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !finalLines.isEmpty else { return [] }

        let grouped = Dictionary(grouping: finalLines) { line in
            max(0, Int(line.startSeconds / 20))
        }

        return grouped.keys.sorted().compactMap { index in
            guard let group = grouped[index], !group.isEmpty else { return nil }
            let start = index * 20
            let end = start + 20
            let linesText = group
                .sorted { $0.startSeconds < $1.startSeconds }
                .map { "\($0.speaker)：\($0.text)" }
                .joined(separator: "\n")
            let clipped = String(linesText.prefix(360))
            return MeetingSummaryCard(window: "\(formatSeconds(start))-\(formatSeconds(end))",
                                      title: "第 \(index + 1) 段理解",
                                      body: clipped,
                                      action: "等待 Hermes 提炼真实意思和建议回应。",
                                      isFinal: true,
                                      startSeconds: Double(start))
        }
    }

    private func refreshSummaryCards(fromHermesAnswer answer: String) {
        var cards = parseHermesRollingCards(answer)
        let finalBody = compactHermesAnswer(answer)
        if !finalBody.isEmpty {
            cards.append(
                MeetingSummaryCard(window: "整场",
                                   title: "Hermes 建议",
                                   body: finalBody,
                                   action: extractSection("建议你这样回", from: answer),
                                   isFinal: true,
                                   startSeconds: Double.greatestFiniteMagnitude)
            )
        }

        if cards.isEmpty {
            cards = buildTwentySecondCards(from: liveTranscriptLines)
        }
        if !cards.isEmpty {
            liveSummaryCards = cards
        }
    }

    private func parseHermesRollingCards(_ answer: String) -> [MeetingSummaryCard] {
        answer.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("-") || trimmed.hasPrefix("•") else { return nil }
            let content = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = content.components(separatedBy: "｜")
            guard parts.count >= 2 else { return nil }

            let window = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard window.contains(":") && window.contains("-") else { return nil }
            let bodyParts = parts.dropFirst()
            var meaning = bodyParts.joined(separator: "\n")
                .replacingOccurrences(of: "意思：", with: "")
                .replacingOccurrences(of: "意思:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            var action: String?
            if let actionRange = meaning.range(of: "你该回应：") ?? meaning.range(of: "你该回应:") {
                action = String(meaning[actionRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                meaning = String(meaning[..<actionRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return MeetingSummaryCard(window: window,
                                      title: "滚动理解",
                                      body: meaning,
                                      action: action,
                                      isFinal: true,
                                      startSeconds: seconds(from: window.components(separatedBy: "-").first ?? "0"))
        }
    }

    private func compactHermesAnswer(_ answer: String) -> String {
        let sections = ["老板真正意思", "他现在需要听到", "TODO"]
        let body = sections.compactMap { title -> String? in
            guard let section = extractSection(title, from: answer), !section.isEmpty else { return nil }
            return "\(title)：\(section)"
        }.joined(separator: "\n\n")
        return String(body.prefix(700))
    }

    private func extractSection(_ title: String, from text: String) -> String? {
        let headings = [
            "20秒滚动理解",
            "老板真正意思",
            "他现在需要听到",
            "建议你这样回",
            "别这样回",
            "TODO",
            "意思",
            "对方需要听到",
            "建议这样回"
        ]
        var isCapturing = false
        var captured: [String] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("\(title)：") || line.hasPrefix("\(title):") {
                isCapturing = true
                let value = line
                    .replacingOccurrences(of: "\(title)：", with: "")
                    .replacingOccurrences(of: "\(title):", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    captured.append(value)
                }
                continue
            }
            if isCapturing && headings.contains(where: { heading in
                line.hasPrefix("\(heading)：") || line.hasPrefix("\(heading):")
            }) {
                break
            }
            if isCapturing && !line.isEmpty {
                captured.append(line)
            }
        }

        let result = captured.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    private func formattedTimelineForPrompt() -> String {
        liveTranscriptLines
            .filter { $0.isFinal }
            .map { "[\($0.timeRange)] [\($0.speaker)/\($0.rawSpeaker)] \($0.text)" }
            .joined(separator: "\n")
    }

    private func speakerAlias(for rawSpeaker: String) -> String {
        let trimmed = rawSpeaker.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: #"^S\d+$"#, options: .regularExpression) != nil,
           let number = Int(trimmed.dropFirst()) {
            let aliases = ["A", "B", "C", "D", "E", "F"]
            if aliases.indices.contains(number - 1) {
                return aliases[number - 1]
            }
        }
        return trimmed
    }

    private func seconds(from text: String) -> Double {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "s", with: "")
            .replacingOccurrences(of: "秒", with: "")
        let timeOnly = cleaned.components(separatedBy: CharacterSet(charactersIn: " -→")).first ?? cleaned
        let parts = timeOnly.split(separator: ":").compactMap { Double($0) }
        if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        }
        return Double(timeOnly) ?? 0
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func finishAudioWriter() async throws {
        guard #available(macOS 15.0, *),
              let audioWriter = audioWriter as? AudioOnlyWriter else { return }
        try await withCheckedThrowingContinuation { continuation in
            audioWriter.finish { result in
                continuation.resume(with: result)
            }
        }
    }

    private func showFinishedAlert(title: String, outputURL: URL?) {
        guard let outputURL else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = outputURL.path
        alert.addButton(withTitle: "在 Finder 显示")
        alert.addButton(withTitle: "好")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([outputURL])
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func appendRecordingLog(_ message: String) {
        let url = URL(fileURLWithPath: "/tmp/macmonitor-recording.log")
        let stamp = ISO8601DateFormatter().string(from: Date())
        guard let data = "\(stamp) \(message)\n".data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: url)
        }
    }

    nonisolated private static func extractOutputURL(from text: String, marker: String) -> URL? {
        for line in text.components(separatedBy: .newlines).reversed() {
            guard let range = line.range(of: marker) else { continue }
            let path = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { continue }
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private func writeHermesAnalysis(_ text: String, beside transcriptURL: URL) -> URL? {
        let baseName = transcriptURL.deletingPathExtension().lastPathComponent
        let outputURL = transcriptURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(baseName)-Hermes回答建议.md")
        let body = """
        # Hermes 回答建议

        来源转写：\(transcriptURL.path)

        \(text)
        """
        do {
            try body.write(to: outputURL, atomically: true, encoding: .utf8)
            return outputURL
        } catch {
            showAlert(title: "建议已生成但保存失败", message: error.localizedDescription)
            return nil
        }
    }
}

extension RecordingController: SCStreamDelegate {}

private struct WhisperTranscript: Decodable {
    let segments: [WhisperSegment]
}

private struct WhisperSegment: Decodable {
    let start: Double
    let end: Double
    let text: String
}

@available(macOS 15.0, *)
private final class AudioOnlyWriter: NSObject, SCStreamOutput, @unchecked Sendable {
    let sampleQueue = DispatchQueue(label: "rybo.Macmonitor.audioOnlyWriter")

    private let writer: AVAssetWriter
    private let systemInput: AVAssetWriterInput
    private let microphoneInput: AVAssetWriterInput
    private var didStartWriting = false
    private var didFinish = false

    init(outputURL: URL) throws {
        try? FileManager.default.removeItem(at: outputURL)
        writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)

        systemInput = AVAssetWriterInput(mediaType: .audio,
                                         outputSettings: Self.audioSettings(channels: 2, bitRate: 128_000))
        microphoneInput = AVAssetWriterInput(mediaType: .audio,
                                             outputSettings: Self.audioSettings(channels: 1, bitRate: 96_000))
        systemInput.expectsMediaDataInRealTime = true
        microphoneInput.expectsMediaDataInRealTime = true

        if writer.canAdd(systemInput) {
            writer.add(systemInput)
        }
        if writer.canAdd(microphoneInput) {
            writer.add(microphoneInput)
        }
    }

    nonisolated func stream(_ stream: SCStream,
                            didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                            of type: SCStreamOutputType) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        append(sampleBuffer, type: type)
    }

    func finish(completion: @escaping (Result<Void, Error>) -> Void) {
        sampleQueue.async {
            guard !self.didFinish else {
                completion(.success(()))
                return
            }
            self.didFinish = true

            guard self.didStartWriting else {
                self.writer.cancelWriting()
                completion(.success(()))
                return
            }

            self.systemInput.markAsFinished()
            self.microphoneInput.markAsFinished()
            self.writer.finishWriting {
                if let error = self.writer.error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    private func append(_ sampleBuffer: CMSampleBuffer, type: SCStreamOutputType) {
        guard !didFinish else { return }
        guard type == .audio || type == .microphone else { return }
        guard writer.status != .failed && writer.status != .cancelled else { return }

        if !didStartWriting {
            didStartWriting = true
            writer.startWriting()
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        }

        let input = type == .microphone ? microphoneInput : systemInput
        guard input.isReadyForMoreMediaData else { return }
        input.append(sampleBuffer)
    }

    private static func audioSettings(channels: Int, bitRate: Int) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: bitRate
        ]
    }
}

private enum RecordingError: LocalizedError {
    case microphoneDenied
    case screenCaptureDenied
    case microphoneRecorderFailed
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "需要允许 MacMonitor Hermes 使用麦克风，才能同时录到你的声音。"
        case .screenCaptureDenied:
            return "需要在“录屏与系统录音”里允许 MacMonitor Hermes。授权后请重新打开 MacMonitor Hermes。"
        case .microphoneRecorderFailed:
            return "麦克风监听启动失败。"
        case .noDisplay:
            return "没有找到可录制的显示器。"
        }
    }
}
