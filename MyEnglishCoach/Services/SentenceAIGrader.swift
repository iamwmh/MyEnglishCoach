import Foundation
import FoundationModels
import NaturalLanguage

@Generable(description: "Detailed grade for a Chinese-to-English sentence translation")
struct TranslationGrade {
    @Guide(description: "Integer score from 0 to 100", .range(0...100))
    var score: Int

    @Guide(description: "True only if the English actually translates the Chinese and is acceptable")
    var isAcceptable: Bool

    @Guide(description: "Does the English translate the Chinese source?", .anyOf(["aligned", "partial", "unrelated"]))
    var relevanceToChinese: String

    @Guide(description: "Relationship to the source Chinese after back-translation", .anyOf(["equivalent", "weaker", "incorrect"]))
    var relationToSample: String

    @Guide(description: "One-sentence overall verdict in Simplified Chinese")
    var feedback: String

    @Guide(description: "Meaning check by comparing back-translated Chinese with the source, in Simplified Chinese")
    var meaningComment: String

    @Guide(description: "Word-choice notes only, never grammar such as missing 主语. Empty if wording is fine.", .count(0...4))
    var wordIssues: [String]

    @Guide(description: "Clause structure or word order only. Do not repeat feedback. Imperatives do not need a subject.")
    var structureComment: String

    @Guide(description: "Exactly four distinct lines: 意思：, 语法：, 用词：, 句式：", .count(4...4))
    var scoringSteps: [String]

    @Guide(description: "What the student already did well, in Simplified Chinese", .count(0...3))
    var strengths: [String]
}

enum SentenceAIGrader {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    static func grade(
        chinese: String,
        expected: String,
        accepted: [String],
        answer rawAnswer: String,
        grammarFocus: String = ""
    ) async -> CheckResult {
        let exact = AnswerChecker.check(
            answer: rawAnswer,
            expected: expected,
            accepted: accepted,
            kind: .sentence
        )
        if exact.score >= 100 {
            return applyingSpelling(withExactRationale(exact, chinese: chinese), answer: rawAnswer, expected: expected, accepted: accepted)
        }
        if rawAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return exact
        }

        let meaning = await ChineseMeaningAligner.align(
            originalChinese: chinese,
            studentEnglish: rawAnswer,
            sampleEnglish: expected,
            accepted: accepted
        )
        if meaning.level == .unrelated {
            return unrelatedResult(chinese: chinese, expected: expected, answer: rawAnswer, meaning: meaning)
        }

        guard SystemLanguageModel.default.isAvailable else {
            return applyingSpelling(
                polishedResult(
                    meaning: meaning,
                    chinese: chinese,
                    answer: rawAnswer,
                    expected: expected,
                    accepted: accepted,
                    grammarFocus: grammarFocus,
                    grade: nil
                ),
                answer: rawAnswer,
                expected: expected,
                accepted: accepted
            )
        }

        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let alternatives = accepted.isEmpty ? "（无）" : accepted.joined(separator: " | ")
            let focus = grammarFocus.isEmpty ? "（未指定）" : grammarFocus
            let backZH = meaning.backTranslatedChinese.isEmpty ? "（回译未能生成）" : meaning.backTranslatedChinese
            let prompt = """
            意思已经用回译核对过，判定为 \(meaning.level.label)，不得因为和学生参考英文用词不同而改成 unrelated。
            若判定为 partial，说明学生英文少了原句的分句或要点，不能给过关分，也不要夸准确。
            待译中文：\(chinese)
            学生英文回译成的中文：\(backZH)
            参考译文（只供句式点评，不是唯一答案，不要用来判定对错）：\(expected)
            其他说法（同样只是样本）：\(alternatives)
            本句语法重点：\(focus)
            学生英文：\(rawAnswer)
            请分别写互不重复的评语：总评、用词、句式、四条得分过程。
            如果学生写的是 Please + 动词 的祈使句，不要说缺少主语。
            意思分必须按回译结果给。
            """
            let options = GenerationOptions(sampling: .greedy, temperature: 0.1, maximumResponseTokens: 480)
            let response = try await session.respond(
                to: prompt,
                generating: TranslationGrade.self,
                options: options
            )
            return applyingSpelling(
                polishedResult(
                    meaning: meaning,
                    chinese: chinese,
                    answer: rawAnswer,
                    expected: expected,
                    accepted: accepted,
                    grammarFocus: grammarFocus,
                    grade: response.content
                ),
                answer: rawAnswer,
                expected: expected,
                accepted: accepted
            )
        } catch {
            return applyingSpelling(
                polishedResult(
                    meaning: meaning,
                    chinese: chinese,
                    answer: rawAnswer,
                    expected: expected,
                    accepted: accepted,
                    grammarFocus: grammarFocus,
                    grade: nil
                ),
                answer: rawAnswer,
                expected: expected,
                accepted: accepted
            )
        }
    }

    private static let instructions = """
    You are an English writing coach for a student aiming at BCIT Category 3.

    Meaning has ALREADY been decided by back-translating the student's English into Chinese \
    and comparing that Chinese with the source Chinese. Trust that result.
    NEVER mark a sentence unrelated just because it does not match the sample English.
    If the back-translation match is partial, the English is INCOMPLETE: a clause or key fact is missing.
    Then isAcceptable = false, score 40-68, and do NOT say the translation is accurate or complete.
    Name the missing Chinese facts. Synonyms are correct only when the same facts are all present.

    The sample English is only a style reference. It is NOT the answer key.

    English imperatives are complete without a subject:
    "Please read ..." and "Read ..." are correct. Do NOT say 缺少主语. Do NOT ask to add 主语. \
    A before-clause like "before you start work" already has its own subject.

    Grade in four parts, then combine. Do NOT deduct spelling in this numeric score; \
    a separate spellchecker will subtract 8 points per misspelling afterwards.
    1) Meaning vs the Chinese (40 points). Use the back-translation match already given. If aligned, give 32-40.
    2) Grammar and completeness (25 points). Imperative without a subject scores full or near-full.
    3) Word choice, not spelling (20 points). Synonyms that keep the Chinese meaning are full marks. \
       If the student used a real but wrong word (annual vs manual), mention that here only.
    4) Sentence structure (15 points). Different word order from the sample is fine if the Chinese meaning is kept.

    Each comment field MUST be different. Do not copy the same sentence into feedback, wordIssues, \
    structureComment, and scoringSteps.
    Write ALL comments in Simplified Chinese.
    Quote the student's actual words in 「」.
    scoringSteps MUST be four distinct lines: "意思：x/40，…", "语法：x/25，…", "用词：x/20，…", "句式：x/15，…".
    wordIssues is only for words. If there is no word problem, return an empty list.
    """

    private static func unrelatedResult(chinese: String, expected: String, answer: String, meaning: MeaningAlignment) -> CheckResult {
        let quoted = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let back = meaning.backTranslatedChinese
        let backLine = back.isEmpty
            ? "无法把这句英文回译成与原句对应的中文。"
            : "回译成中文是「\(back)」，和待译中文「\(chinese)」不是同一件事。"
        return CheckResult(
            isCorrect: false,
            score: 8,
            quality: 0,
            normalizedAnswer: AnswerChecker.normalize(answer, chinese: false),
            normalizedExpected: expected,
            feedback: "这句英文没有翻译给定的中文。",
            rationale: ScoringRationale(
                relationToSample: "unrelated",
                meaningComment: "待译中文是「\(chinese)」。你写的是「\(quoted)」。\(backLine)",
                wordIssues: [
                    "评分先把英文回译成中文，再和待译中文比意思，而不是和参考英文比用词。"
                ],
                structureComment: "句式是否完整此时不计分：因为内容已经跑题。",
                scoringSteps: [
                    "回译对照：与待译中文无对应关系",
                    "意思：0/40",
                    "语法、用词、句式：跑题后不再加分，合计 8 分"
                ],
                strengths: [],
                backTranslatedChinese: back
            ),
            originalAnswer: quoted
        )
    }

    private static func polishedResult(
        meaning: MeaningAlignment,
        chinese: String,
        answer: String,
        expected: String,
        accepted: [String],
        grammarFocus: String,
        grade: TranslationGrade?
    ) -> CheckResult {
        if grade?.relevanceToChinese == "unrelated", meaning.level != .unrelated {
            return polishedResult(
                meaning: meaning,
                chinese: chinese,
                answer: answer,
                expected: expected,
                accepted: accepted,
                grammarFocus: grammarFocus,
                grade: nil
            )
        }

        let grammar = GradeCommentPolisher.grammarNote(for: answer)
        let nearMisses = GradeCommentPolisher.nearMissWordNotes(
            answer: answer,
            expected: expected,
            accepted: accepted
        )
        var wordIssues = GradeCommentPolisher.uniqued(
            (grade?.wordIssues ?? []).map {
                GradeCommentPolisher.stripFalseSubjectClaims($0, answer: answer)
            } + meaningWordIssues(meaning) + nearMisses
        )
        wordIssues.removeAll {
            $0.isEmpty
                || GradeCommentPolisher.claimsMissingSubject($0)
                || $0.contains("参考译文没有")
        }

        let wordPoints: Double
        let wordStep: String
        if !nearMisses.isEmpty {
            wordPoints = 12
            wordStep = "有近形词用错"
        } else if meaning.level == .aligned {
            wordPoints = 18
            wordStep = "用词达意，不要求与参考译文相同"
        } else if meaning.level == .partial {
            wordPoints = 12
            wordStep = "部分要点还没有用上"
        } else {
            wordPoints = 0
            wordStep = "跑题后用词不计分"
        }

        var structure = GradeCommentPolisher.stripFalseSubjectClaims(
            grade?.structureComment ?? "",
            answer: answer
        )
        if structure.isEmpty
            || GradeCommentPolisher.claimsMissingSubject(structure)
            || (meaning.level == .partial && looksLikePraise(structure))
        {
            if meaning.level == .partial, !meaning.missing.isEmpty {
                structure = "原句还有分句没有译完，当前英文不能算完整。"
            } else {
                structure = GradeCommentPolisher.structureNote(for: answer, grammarFocus: grammarFocus)
            }
        }

        var feedback = GradeCommentPolisher.stripFalseSubjectClaims(
            grade?.feedback ?? "",
            answer: answer
        )
        if feedback.isEmpty
            || GradeCommentPolisher.claimsMissingSubject(feedback)
            || GradeCommentPolisher.isNearDuplicate(feedback, structure)
            || wordIssues.contains(where: { GradeCommentPolisher.isNearDuplicate(feedback, $0) })
            || (meaning.level == .partial && looksLikePraise(feedback))
        {
            if meaning.level == .partial {
                feedback = meaning.missing.isEmpty
                    ? "只译出了部分意思，原句还有要点没有写出来。"
                    : "只译出了部分意思，还缺：\(meaning.missing.prefix(2).joined(separator: "；"))。"
            } else if !nearMisses.isEmpty, meaning.level == .aligned {
                feedback = "意思正确，可以过关。请再核对个别用词。"
            } else if meaning.level == .aligned {
                feedback = "意思正确，可以过关。不要求和参考译文用同一个词。"
            } else {
                feedback = "请看回译对照，先保证英文是在翻译这句中文。"
            }
        }

        wordIssues.removeAll {
            GradeCommentPolisher.isNearDuplicate($0, structure)
                || GradeCommentPolisher.isNearDuplicate($0, feedback)
        }

        var strengths = GradeCommentPolisher.uniqued(
            (grade?.strengths ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        strengths.removeAll {
            $0.isEmpty
                || GradeCommentPolisher.claimsMissingSubject($0)
                || GradeCommentPolisher.isNearDuplicate($0, feedback)
                || GradeCommentPolisher.isNearDuplicate($0, structure)
        }
        if !nearMisses.isEmpty {
            strengths.removeAll { $0.contains("正确的词") || $0.contains("用词正确") || $0.contains("正确的词汇") }
        }
        if meaning.level == .partial {
            strengths.removeAll { looksLikePraise($0) }
        }
        if meaning.level == .aligned, strengths.isEmpty {
            strengths = ["回译后与待译中文说的是同一件事。"]
        }

        let structurePoints: Double
        let structureStep: String
        switch meaning.level {
        case .aligned:
            structurePoints = 12
            structureStep = GradeCommentPolisher.looksLikeImperative(answer)
                ? "祈使句清楚，不要求与样本同词序"
                : "句式清楚，不按参考译文字面给分"
        case .partial:
            structurePoints = 8
            structureStep = "句式大体能看懂"
        case .unrelated:
            structurePoints = 0
            structureStep = "跑题后句式不计分"
        }

        var score: Double
        if let grade, grade.relevanceToChinese != "unrelated" {
            score = Double(min(100, max(0, grade.score)))
            if meaning.level == .aligned {
                score = max(score, meaning.meaningPoints + grammar.points + wordPoints + structurePoints)
                score = min(100, score)
            } else if meaning.level == .partial {
                score = min(score, 72)
            }
        } else {
            score = min(100, meaning.meaningPoints + grammar.points + wordPoints + structurePoints)
        }
        if meaning.level == .partial {
            score = min(score, meaning.meaningPoints + grammar.points + wordPoints + structurePoints, 64)
        }
        if !nearMisses.isEmpty {
            score = max(0, min(score, 90) - 6)
        }

        var relation = meaning.relation
        if !nearMisses.isEmpty, meaning.level == .aligned {
            relation = "weaker"
        }

        let isCorrect = meaning.level == .aligned && score >= 75
        let quality: Int
        switch score {
        case 92...: quality = 5
        case 80..<92: quality = 4
        case 70..<80: quality = isCorrect ? 3 : 2
        case 50..<70: quality = 2
        default: quality = 1
        }

        let meaningStep = meaning.level == .aligned
            ? "回译与原句说的是同一件事"
            : "同一话题，但要点还不完整"

        let steps = GradeCommentPolisher.uniqued([
            meaning.backTranslatedChinese.isEmpty
                ? "回译对照：本次未能生成中文回译，改用语义要点判断"
                : "回译对照：学生英文 →「\(meaning.backTranslatedChinese)」",
            "意思：\(Int(meaning.meaningPoints))/40，\(meaningStep)",
            "语法：\(Int(grammar.points))/25，\(grammar.comment)",
            "用词：\(Int(wordPoints))/20，\(wordStep)",
            "句式：\(Int(structurePoints))/15，\(structureStep)"
        ])

        return CheckResult(
            isCorrect: isCorrect,
            score: score,
            quality: isCorrect ? quality : min(quality, 2),
            normalizedAnswer: AnswerChecker.normalize(answer, chinese: false),
            normalizedExpected: expected,
            feedback: feedback,
            rationale: ScoringRationale(
                relationToSample: relation,
                meaningComment: meaning.comment,
                wordIssues: wordIssues,
                structureComment: structure,
                scoringSteps: steps,
                strengths: strengths,
                backTranslatedChinese: meaning.backTranslatedChinese
            ),
            originalAnswer: answer.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func meaningWordIssues(_ meaning: MeaningAlignment) -> [String] {
        var issues: [String] = []
        if !meaning.missing.isEmpty {
            issues.append("缺少原句要点：\(meaning.missing.prefix(6).joined(separator: "、"))。")
        }
        if !meaning.extra.isEmpty {
            issues.append("回译后多出了原句没有的内容：\(meaning.extra.prefix(6).joined(separator: "、"))。")
        }
        return issues
    }

    private static func looksLikePraise(_ text: String) -> Bool {
        ["准确", "过关", "完整", "意思正确", "同一件事", "非常", "保留了原句", "可以过关"].contains { text.contains($0) }
    }

    private static func applyingSpelling(
        _ result: CheckResult,
        answer: String,
        expected: String,
        accepted: [String]
    ) -> CheckResult {
        if result.rationale?.isUnrelatedToSource == true { return result }
        let findings = EnglishSpellingChecker.findings(
            in: answer,
            allowedFromReference: [expected] + accepted
        )
        guard !findings.isEmpty else { return result }

        let penalty = Double(min(24, findings.count * 8))
        let newScore = max(0, result.score - penalty)
        let lines = findings.map(\.line)
        var rationale = result.rationale ?? ScoringRationale(
            relationToSample: result.isCorrect ? "weaker" : "incorrect",
            meaningComment: result.feedback,
            wordIssues: [],
            structureComment: "",
            scoringSteps: [],
            strengths: []
        )
        rationale.spellingIssues = lines
        if rationale.relationToSample == "equivalent" {
            rationale.relationToSample = "weaker"
        }
        if !rationale.scoringSteps.contains(where: { $0.contains("拼写") }) {
            rationale.scoringSteps.append("拼写：-\(Int(penalty)) 分，共 \(findings.count) 处")
        }
        rationale.scoringSteps = GradeCommentPolisher.uniqued(rationale.scoringSteps)
        var feedback = result.feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        if !feedback.contains("拼写") {
            let note = findings.count == 1
                ? "有 1 处拼写错误，已扣 \(Int(penalty)) 分。"
                : "有 \(findings.count) 处拼写错误，已扣 \(Int(penalty)) 分。"
            feedback = feedback.isEmpty ? note : "\(feedback) \(note)"
        }
        let isCorrect = result.isCorrect && newScore >= 75
        let quality: Int
        switch newScore {
        case 92...: quality = 5
        case 80..<92: quality = 4
        case 70..<80: quality = isCorrect ? 3 : 2
        case 50..<70: quality = 2
        default: quality = 1
        }
        return CheckResult(
            isCorrect: isCorrect,
            score: newScore,
            quality: quality,
            normalizedAnswer: result.normalizedAnswer,
            normalizedExpected: result.normalizedExpected,
            feedback: feedback,
            rationale: rationale,
            originalAnswer: result.originalAnswer.isEmpty ? answer : result.originalAnswer
        )
    }

    private static func withExactRationale(_ result: CheckResult, chinese: String) -> CheckResult {
        var copy = result
        copy.rationale = ScoringRationale(
            relationToSample: "equivalent",
            meaningComment: "英文与待译中文「\(chinese)」对应，并与参考译文一致。参考译文仍不是唯一合法说法。",
            wordIssues: [],
            structureComment: "句式清楚。",
            scoringSteps: ["意思 40/40", "语法 25/25", "用词 20/20", "句式 15/15，合计 100"],
            strengths: ["和待译中文意思一致。"]
        )
        return copy
    }
}

private extension MeaningAlignment.Level {
    var label: String {
        switch self {
        case .aligned: "aligned"
        case .partial: "partial"
        case .unrelated: "unrelated"
        }
    }
}
