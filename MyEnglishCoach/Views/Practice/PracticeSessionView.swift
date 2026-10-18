import PencilKit
import SwiftUI

struct PracticeSessionView: View {
    let title: String
    let subtitle: String
    let tasks: [PracticeTask]

    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [PracticeTask] = []
    @State private var index = 0
    @State private var typedAnswer = ""
    @State private var drawing = PKDrawing()
    @State private var inputMode: AnswerInputMode = .keyboard
    @State private var recognizedText = ""
    @State private var currentResult: CheckResult?
    @State private var isChecking = false
    @State private var showAnswer = false
    @State private var speaker = VoiceSpeaker()
    @State private var speech = SpeechPracticeController()
    @State private var completed = 0
    @State private var correctCount = 0
    @State private var sessionFinished = false
    @FocusState private var isAnswerFocused: Bool

    private var current: PracticeTask? {
        guard queue.indices.contains(index) else { return nil }
        return queue[index]
    }

    var body: some View {
        Group {
            if sessionFinished || queue.isEmpty {
                finishedState
            } else if let task = current {
                taskState(task)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .paperBackground()
        .onAppear {
            if queue.isEmpty {
                queue = tasks
            }
        }
        .onDisappear {
            speaker.stop()
            speech.cancel()
        }
    }

    private var finishedState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "flag.checkered")
                .font(.system(size: 42))
                .foregroundStyle(AppTheme.gold)
            Text(queue.isEmpty ? "今天这一项暂时没有到期内容" : "本组训练完成")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text(queue.isEmpty ? subtitle : "答对 \(correctCount) / \(max(completed, 1))。错过的项目会按遗忘曲线提前回滚。")
                .font(.body)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button("返回") { dismiss() }
                .buttonStyle(PrimaryCoachButtonStyle())
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private func taskState(_ task: PracticeTask) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    progressHeader
                    promptCard(task)

                    if task.kind == .vocabToChinese {
                        choiceGrid(task)
                    } else if task.kind == .recitation {
                        recitationPanel(task)
                    } else {
                        AnswerInputPanel(
                            placeholder: placeholder(for: task),
                            typedAnswer: $typedAnswer,
                            drawing: $drawing,
                            mode: $inputMode,
                            recognizedText: recognizedText,
                            isFieldFocused: $isAnswerFocused,
                            onKeyboardSubmit: { Task { await check(task) } }
                        )
                    }

                    if let currentResult {
                        ScoreBanner(result: currentResult)
                        if let rationale = currentResult.rationale {
                            ScoringRationaleCard(rationale: rationale)
                        }
                    }
                    if showAnswer {
                        answerCard(task, result: currentResult)
                    }
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)

            if showsPinnedAction(for: task) {
                pinnedActionBar(task)
            }
        }
        .onChange(of: inputMode) { _, newMode in
            if newMode == .pencil {
                isAnswerFocused = false
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("收起键盘") {
                    isAnswerFocused = false
                }
                Spacer()
                if currentResult == nil {
                    Button("检查") {
                        Task { await check(task) }
                    }
                    .fontWeight(.semibold)
                    .disabled(isChecking)
                }
            }
        }
    }

    private func promptCard(_ task: PracticeTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(task.kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.gold)
                NewReviewBadge(stage: task.stage)
                Spacer()
                Text(task.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Text(task.prompt)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if task.kind != .recitation {
                Button {
                    speaker.speak(task.kind == .vocabToChinese ? task.prompt : task.expected)
                } label: {
                    Label("听标准发音", systemImage: "speaker.wave.2.fill")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.navy)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        .shadow(color: AppTheme.navy.opacity(0.06), radius: 10, y: 4)
    }

    private func showsPinnedAction(for task: PracticeTask) -> Bool {
        if currentResult != nil { return true }
        return task.kind != .vocabToChinese && task.kind != .recitation
    }

    private func pinnedActionBar(_ task: PracticeTask) -> some View {
        VStack(spacing: 0) {
            Divider()
            Group {
                if let currentResult {
                    Button(index + 1 >= queue.count ? "完成" : "下一题") {
                        advance(from: task, result: currentResult)
                    }
                    .buttonStyle(PrimaryCoachButtonStyle())
                } else {
                    Button(isChecking ? checkingTitle(for: task) : "检查") {
                        Task { await check(task) }
                    }
                    .buttonStyle(PrimaryCoachButtonStyle())
                    .disabled(isChecking)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(AppTheme.paper.ignoresSafeArea(edges: .bottom))
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
            ProgressView(value: Double(index + (currentResult == nil ? 0 : 1)), total: Double(max(queue.count, 1)))
                .tint(AppTheme.navy)
            Text("第 \(min(index + 1, queue.count)) / \(queue.count) 题")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.navy)
        }
    }

    private func choiceGrid(_ task: PracticeTask) -> some View {
        VStack(spacing: 10) {
            ForEach(task.choices, id: \.self) { choice in
                Button {
                    typedAnswer = choice
                    Task { await check(task, forcedAnswer: choice) }
                } label: {
                    Text(choice)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(AppTheme.card)
                        .foregroundStyle(AppTheme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(currentResult != nil)
            }
        }
    }

    private func recitationPanel(_ task: PracticeTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(task.hint)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
            HStack(spacing: 10) {
                Button {
                    speaker.speak(task.expected)
                } label: {
                    Label("先听示范", systemImage: "ear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryCoachButtonStyle())

                Button {
                    Task { await toggleRecording() }
                } label: {
                    Label(recordButtonTitle, systemImage: speech.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryCoachButtonStyle())
                .disabled(isChecking)
            }
            if let message = speech.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.rust)
            }
            if !speech.lastTranscript.isEmpty {
                Text("识别：\(speech.lastTranscript)")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.navy)
            }
        }
    }

    private func answerCard(_ task: PracticeTask, result: CheckResult?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标准答案")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.gold)
            Text(task.expected)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            if let result, !result.shownAnswer.isEmpty {
                Text("你的回答：\(result.shownAnswer)")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }
            Button {
                speaker.speak(task.expected)
            } label: {
                Label("再听一遍", systemImage: "speaker.wave.2")
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.sky.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var recordButtonTitle: String {
        if speech.isRecording { return "停止并评分" }
        if showAnswer { return "再录一遍" }
        return "开始录音"
    }

    private func checkingTitle(for task: PracticeTask) -> String {
        if task.kind == .sentence { return "智能评分中…" }
        if inputMode == .pencil { return "识别中…" }
        return "检查中…"
    }

    private func placeholder(for task: PracticeTask) -> String {
        switch task.kind {
        case .vocabSpell: "输入英语单词"
        case .verbForm: "输入对应词形"
        case .phrasalGap: "输入动词短语，如 look up"
        case .sentence: "把中文译成完整英语句子"
        default: "输入答案"
        }
    }

    private func check(_ task: PracticeTask, forcedAnswer: String? = nil, replacingExisting: Bool = false) async {
        guard currentResult == nil || replacingExisting else { return }
        let isRetry = currentResult != nil
        isChecking = true
        defer { isChecking = false }
        var answer = forcedAnswer ?? typedAnswer
        if forcedAnswer == nil, inputMode == .pencil {
            recognizedText = await HandwritingRecognizer.recognize(drawing)
            answer = recognizedText
        }
        let result: CheckResult
        if task.kind == .sentence {
            result = await SentenceAIGrader.grade(
                chinese: task.prompt,
                expected: task.expected,
                accepted: task.accepted,
                answer: answer,
                grammarFocus: task.hint.isEmpty ? task.subtitle : task.hint
            )
        } else {
            result = AnswerChecker.check(answer: answer, expected: task.expected, accepted: task.accepted, kind: task.kind)
        }
        currentResult = result
        showAnswer = true
        isAnswerFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        store.record(task: task, result: result)
        if !isRetry {
            completed += 1
            if result.isCorrect { correctCount += 1 }
        } else if result.isCorrect {
            correctCount = min(completed, correctCount + 1)
        }
    }

    private func toggleRecording() async {
        do {
            if speech.isRecording {
                let transcript = try await speech.stopAndTranscribe()
                if let task = current {
                    await check(task, forcedAnswer: transcript, replacingExisting: task.kind == .recitation)
                }
            } else {
                speaker.stop()
                try await speech.start()
            }
        } catch {
            speech.errorMessage = error.localizedDescription
        }
    }

    private func advance(from task: PracticeTask, result: CheckResult) {
        if !result.isCorrect {
            let retryIndex = min(index + 2, queue.count)
            var retry = task
            retry = PracticeTask(
                id: task.id + "-retry-\(UUID().uuidString)",
                kind: task.kind,
                contentId: task.contentId,
                prompt: task.prompt,
                expected: task.expected,
                accepted: task.accepted,
                hint: task.hint,
                subtitle: "回滚复习",
                exampleEn: task.exampleEn,
                exampleZh: task.exampleZh,
                choices: task.choices,
                stage: .rollback
            )
            queue.insert(retry, at: retryIndex)
        }

        typedAnswer = ""
        drawing = PKDrawing()
        recognizedText = ""
        currentResult = nil
        showAnswer = false
        isAnswerFocused = false
        speech.lastTranscript = ""
        speech.errorMessage = nil

        if index + 1 >= queue.count {
            sessionFinished = true
        } else {
            index += 1
        }
    }
}

struct PrimaryCoachButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(configuration.isPressed ? AppTheme.navyButtonPressed : AppTheme.navyButton)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SecondaryCoachButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppTheme.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.goldSoft.opacity(configuration.isPressed ? 0.5 : 0.85))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
