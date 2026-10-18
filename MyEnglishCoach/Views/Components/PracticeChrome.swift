import PencilKit
import SwiftUI

enum AnswerInputMode: String, CaseIterable, Identifiable {
    case keyboard
    case pencil

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyboard: "键盘"
        case .pencil: "手写 / Apple Pencil"
        }
    }

    var symbol: String {
        switch self {
        case .keyboard: "keyboard"
        case .pencil: "pencil.tip"
        }
    }
}

struct AnswerInputPanel: View {
    let placeholder: String
    @Binding var typedAnswer: String
    @Binding var drawing: PKDrawing
    @Binding var mode: AnswerInputMode
    var recognizedText: String = ""
    @FocusState.Binding var isFieldFocused: Bool
    var onKeyboardSubmit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("输入方式", selection: $mode) {
                ForEach(AnswerInputMode.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if mode == .keyboard {
                TextField(placeholder, text: $typedAnswer, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { onKeyboardSubmit?() }
                    .foregroundStyle(AppTheme.ink)
                    .tint(AppTheme.navy)
                    .scrollContentBackground(.hidden)
                    .padding(14)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.navy.opacity(0.12), lineWidth: 1)
                    )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Text("手写区")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                        Spacer(minLength: 8)
                        Button {
                            drawing = PKDrawing()
                        } label: {
                            Label("清除", systemImage: "eraser.fill")
                                .font(.body.weight(.semibold))
                                .frame(minWidth: 112, minHeight: 44)
                                .padding(.horizontal, 8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.navy)
                        .background(AppTheme.goldSoft)
                        .clipShape(Capsule())
                        .accessibilityLabel("清除手写")
                    }

                    PencilCanvasView(drawing: $drawing)
                        .frame(minHeight: 168)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.navy.opacity(0.12), lineWidth: 1)
                        )

                    if recognizedText.isEmpty {
                        Text("用手指或 Apple Pencil 书写英语，点检查后自动识别。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    } else {
                        Text("识别结果：\(recognizedText)")
                            .font(.caption.monospaced())
                            .foregroundStyle(AppTheme.navy)
                    }
                }
            }
        }
    }
}

struct ScoreBanner: View {
    let result: CheckResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(result.isCorrect ? "过关" : "再练一遍", systemImage: result.isCorrect ? "checkmark.seal.fill" : "arrow.counterclockwise")
                    .font(.headline)
                    .foregroundStyle(result.isCorrect ? AppTheme.forest : AppTheme.rust)
                Spacer()
                Text("\(Int(result.score)) 分")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.navy)
            }
            Text(result.feedback)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
            if let relation = result.rationale?.relationLabel {
                Text(relation)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(result.rationale?.isUnrelatedToSource == true ? AppTheme.rust : AppTheme.navySoft)
            }
        }
        .padding(16)
        .background((result.isCorrect ? AppTheme.forest : AppTheme.rust).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ScoringRationaleCard: View {
    let rationale: ScoringRationale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("评分依据")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.gold)

            if rationale.isUnrelatedToSource {
                Text("先核对：这句英文是不是在翻译上面的中文。")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.rust)
            }

            if !rationale.backTranslatedChinese.isEmpty {
                rationaleSection("回译对照", "你的英文相当于：「\(rationale.backTranslatedChinese)」")
            }

            rationaleSection("意思", rationale.meaningComment)

            if !rationale.wordIssues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("用词")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.navy)
                    ForEach(Array(rationale.wordIssues.enumerated()), id: \.offset) { _, item in
                        Text("• \(item)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ink)
                    }
                }
            } else {
                rationaleSection("用词", "没有明显用词错误。说法不同不等于错误。")
            }

            rationaleSection("句式", rationale.structureComment)

            if !rationale.spellingIssues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("拼写")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.rust)
                    ForEach(Array(rationale.spellingIssues.enumerated()), id: \.offset) { _, item in
                        Text("• \(item)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ink)
                    }
                }
            } else if !rationale.isUnrelatedToSource {
                rationaleSection("拼写", "没有发现拼写错误。")
            }

            if !rationale.scoringSteps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("得分过程")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.navy)
                    ForEach(Array(rationale.scoringSteps.enumerated()), id: \.offset) { index, item in
                        Text("\(index + 1). \(item)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ink)
                    }
                }
            }

            if !rationale.strengths.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("已经做对的")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.forest)
                    ForEach(Array(rationale.strengths.enumerated()), id: \.offset) { _, item in
                        Text("• \(item)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ink)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.navy.opacity(0.08), lineWidth: 1)
        )
    }

    private func rationaleSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.navy)
            Text(body.isEmpty ? "（无）" : body)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
        }
    }
}

struct NewReviewBadge: View {
    let stage: StudyStage

    var body: some View {
        Text(stage.badgeTitle)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(badgeBackground)
            .foregroundStyle(badgeForeground)
            .clipShape(Capsule())
    }

    private var badgeBackground: Color {
        switch stage {
        case .fresh: AppTheme.gold.opacity(0.2)
        case .review: AppTheme.navy.opacity(0.1)
        case .rollback: AppTheme.rust.opacity(0.12)
        }
    }

    private var badgeForeground: Color {
        switch stage {
        case .fresh: AppTheme.navy
        case .review: AppTheme.navySoft
        case .rollback: AppTheme.rust
        }
    }
}
