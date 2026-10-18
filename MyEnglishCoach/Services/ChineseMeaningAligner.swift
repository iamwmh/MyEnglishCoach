import Foundation
import FoundationModels
import NaturalLanguage
import Translation

@Generable(description: "English rewritten as Simplified Chinese")
struct StudentEnglishBackTranslation {
    @Guide(description: "One natural Simplified Chinese sentence with the same facts as the English, no extra meaning")
    var chinese: String
}

struct MeaningAlignment {
    enum Level {
        case aligned
        case partial
        case unrelated
    }

    let level: Level
    let backTranslatedChinese: String
    let similarity: Double
    let meaningPoints: Double
    let missing: [String]
    let extra: [String]

    var relation: String {
        switch level {
        case .aligned: "equivalent"
        case .partial: "weaker"
        case .unrelated: "unrelated"
        }
    }

    var comment: String {
        if backTranslatedChinese.isEmpty {
            switch level {
            case .aligned:
                return "未能生成回译，但英文要点已经覆盖待译中文，因此按语义给分，不和参考译文字面比对。"
            case .partial:
                return "未能生成回译，英文只覆盖了待译中文的部分要点。"
            case .unrelated:
                return "英文回译后与待译中文对不上，不能算这句的译文。"
            }
        }
        switch level {
        case .aligned:
            return "把你的英文回译成中文是「\(backTranslatedChinese)」。待译中文是原句。两句说的是同一件事，用词不同也可以。"
        case .partial:
            let gap = missing.isEmpty
                ? "和原句是同一话题，但还有要点没有写出来。"
                : "和原句是同一话题，但没有译出：\(missing.prefix(3).joined(separator: "；"))。"
            return "把你的英文回译成中文是「\(backTranslatedChinese)」。\(gap)"
        case .unrelated:
            return "把你的英文回译成中文是「\(backTranslatedChinese)」。这和待译中文不是同一件事。"
        }
    }
}

enum ChineseMeaningAligner {
    static func align(originalChinese: String, studentEnglish: String, sampleEnglish: String, accepted: [String]) async -> MeaningAlignment {
        let backZH = await backTranslate(studentEnglish)
        if let backZH, looksLikeChinese(backZH) {
            return compareChinese(original: originalChinese, backTranslated: backZH)
        }

        // Last resort only if on-device translation is unavailable: same-topic English
        // is treated as aligned. The score is NOT the sample-English overlap percentage.
        if englishSharesTopic(sampleEnglish, accepted: accepted, answer: studentEnglish) {
            let completeness = englishCompleteness(answer: studentEnglish, expected: sampleEnglish, accepted: accepted)
            if completeness < 0.72 {
                return MeaningAlignment(
                    level: .partial,
                    backTranslatedChinese: "",
                    similarity: completeness,
                    meaningPoints: 18,
                    missing: ["英文明显短于原句，后半句要点没有写出"],
                    extra: []
                )
            }
            return MeaningAlignment(
                level: .aligned,
                backTranslatedChinese: "",
                similarity: 0.82,
                meaningPoints: 34,
                missing: [],
                extra: []
            )
        }
        return MeaningAlignment(
            level: .unrelated,
            backTranslatedChinese: "",
            similarity: 0,
            meaningPoints: 0,
            missing: [],
            extra: []
        )
    }

    static func backTranslate(_ english: String) async -> String? {
        let trimmed = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let fromModel = await fromLanguageModel(trimmed), looksLikeChinese(fromModel) {
            return sanitizeChinese(fromModel)
        }
        if let fromSystem = await fromTranslationFramework(trimmed), looksLikeChinese(fromSystem) {
            return sanitizeChinese(fromSystem)
        }
        return nil
    }

    private static func fromLanguageModel(_ english: String) async -> String? {
        guard SystemLanguageModel.default.isAvailable else { return nil }
        do {
            let session = LanguageModelSession(instructions: """
                Translate English into one Simplified Chinese sentence.
                Keep the same facts. Do not add politeness or details that are not in the English.
                Do not use a textbook answer. Output only the Chinese sentence.
                """)
            let options = GenerationOptions(sampling: .greedy, temperature: 0.1, maximumResponseTokens: 120)
            let response = try await session.respond(
                to: english,
                generating: StudentEnglishBackTranslation.self,
                options: options
            )
            return response.content.chinese
        } catch {
            return nil
        }
    }

    private static func fromTranslationFramework(_ english: String) async -> String? {
        do {
            let session = TranslationSession(
                installedSource: Locale.Language(identifier: "en"),
                target: Locale.Language(identifier: "zh-Hans")
            )
            let response = try await session.translate(english)
            return response.targetText
        } catch {
            return nil
        }
    }

    static func compareChinese(original: String, backTranslated: String) -> MeaningAlignment {
        let sourceTokens = chineseContentTokens(original)
        let backTokens = chineseContentTokens(backTranslated)
        let paired = pairTokens(sourceTokens, backTokens)
        let tokenRecall = sourceTokens.isEmpty ? 1 : Double(paired.matched) / Double(sourceTokens.count)
        let charRecall = characterRecall(source: original, cover: backTranslated)
        let clauses = clauseCoverage(original: original, backTranslated: backTranslated)
        let similarity = min(1, (tokenRecall * 0.45) + (charRecall * 0.55))
        let incomplete = clauses.total >= 2 && clauses.covered < clauses.total
        let completeEnough = charRecall >= 0.78 && tokenRecall >= 0.72 && !incomplete

        let level: MeaningAlignment.Level
        if completeEnough {
            level = .aligned
        } else if charRecall >= 0.28 || tokenRecall >= 0.28 || clauses.covered >= 1 {
            level = .partial
        } else {
            level = .unrelated
        }

        let points: Double
        switch level {
        case .aligned:
            points = min(40, (32 + charRecall * 8).rounded())
        case .partial:
            points = min(24, max(10, (charRecall * 36).rounded()))
        case .unrelated:
            points = 0
        }

        let missing: [String]
        if incomplete {
            missing = clauses.missing.map { "「\($0)」" }
        } else if level == .aligned {
            missing = []
        } else {
            missing = paired.missing
        }

        return MeaningAlignment(
            level: level,
            backTranslatedChinese: backTranslated,
            similarity: similarity,
            meaningPoints: points,
            missing: missing,
            extra: level == .aligned ? [] : paired.extra
        )
    }

    private static func englishSharesTopic(_ expected: String, accepted: [String], answer: String) -> Bool {
        let anchors = ([expected] + accepted).filter { !$0.isEmpty }
        guard !anchors.isEmpty else { return false }
        let overlap = anchors.map { contentOverlap(answer, $0) }.max() ?? 0
        let lexical = anchors.map {
            AnswerChecker.similarity(
                AnswerChecker.normalize(answer, chinese: false),
                AnswerChecker.normalize($0, chinese: false)
            )
        }.max() ?? 0
        if overlap >= 2 { return true }
        if lexical >= 0.42 { return true }
        return false
    }

    private static func englishCompleteness(answer: String, expected: String, accepted: [String]) -> Double {
        let answerCount = Double(max(contentTokens(answer).count, 1))
        let expectedCount = Double(([expected] + accepted).map { contentTokens($0).count }.max() ?? 1)
        return min(1, answerCount / max(expectedCount, 1))
    }

    private static func characterRecall(source: String, cover: String) -> Double {
        let src = Set(chineseCharacters(source).filter { !chineseStops.contains(String($0)) })
        let cov = Set(chineseCharacters(cover).filter { !chineseStops.contains(String($0)) })
        guard !src.isEmpty else { return 1 }
        return Double(src.intersection(cov).count) / Double(src.count)
    }

    private static func clauseCoverage(original: String, backTranslated: String) -> (covered: Int, total: Int, missing: [String]) {
        let clauses = splitClauses(original)
        guard clauses.count >= 2 else {
            return (1, 1, [])
        }
        var covered = 0
        var missing: [String] = []
        for clause in clauses {
            if characterRecall(source: clause, cover: backTranslated) >= 0.55 {
                covered += 1
            } else {
                missing.append(clause)
            }
        }
        return (covered, clauses.count, missing)
    }

    private static func splitClauses(_ text: String) -> [String] {
        var working = text
        for connector in ["但是", "可是", "而且", "所以", "因为", "然而"] {
            working = working.replacingOccurrences(of: connector, with: "，\(connector)")
        }
        if !working.contains("但是"), !working.contains("可是") {
            working = working.replacingOccurrences(of: "但", with: "，但")
        }
        let parts = working
            .components(separatedBy: CharacterSet(charactersIn: "，,；;。"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .filter { chineseCharacters($0).count >= 3 }
        return parts
    }

    private static func contentOverlap(_ a: String, _ b: String) -> Int {
        contentTokens(a).intersection(contentTokens(b)).count
    }

    private static func contentTokens(_ text: String) -> Set<String> {
        Set(
            AnswerChecker.normalize(text, chinese: false)
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
                .filter { $0.count >= 3 && !englishStops.contains($0) }
        )
    }

    private static let englishStops: Set<String> = [
        "the", "a", "an", "is", "are", "was", "were", "be", "been", "being", "to", "of", "and", "or",
        "but", "in", "on", "at", "for", "with", "as", "by", "from", "that", "this", "it", "its",
        "you", "your", "must", "not", "no", "do", "does", "did", "can", "cannot", "please", "will"
    ]

    private static let chineseStops: Set<String> = [
        "请", "的", "了", "着", "过", "吗", "呢", "吧", "啊", "嘛", "呀", "地", "得", "个", "一下", "进行"
    ]

    private static let synonymRoot: [String: String] = {
        let groups: [[String]] = [
            ["手册", "说明书", "说明", "指南", "指引", "指示", "须知"],
            ["开始", "着手", "开工", "启动"],
            ["工作", "作业", "干活"],
            ["阅读", "查阅", "看", "读"],
            ["损坏", "破损", "损坏的", "坏"],
            ["更换", "替换", "换掉", "换"],
            ["停止", "停下", "中止", "停"],
            ["立即", "马上", "立刻"],
            ["必须", "务必", "应该"],
            ["使用", "用"],
            ["设备", "器材", "装备"],
            ["工地", "现场", "工地现场"],
            ["工人", "员工", "人员"],
            ["防护", "保护", "劳保"],
            ["禁止", "不可", "不准", "不要"]
        ]
        var map: [String: String] = [:]
        for group in groups {
            guard let root = group.first else { continue }
            for word in group { map[word] = root }
        }
        return map
    }()

    private static func chineseContentTokens(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.simplifiedChinese)
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range]).trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
            if token.isEmpty { return true }
            if chineseStops.contains(token) { return true }
            if token.unicodeScalars.allSatisfy({ CharacterSet.punctuationCharacters.contains($0) }) { return true }
            tokens.append(canonical(token))
            return true
        }
        if tokens.isEmpty {
            tokens = Array(chineseCharacters(text)).map(String.init)
        }
        return tokens
    }

    private static func pairTokens(_ source: [String], _ other: [String]) -> (matched: Int, missing: [String], extra: [String]) {
        var unused = other
        var missing: [String] = []
        var matched = 0
        for token in source {
            if let idx = unused.firstIndex(where: { tokensLooselyMatch(token, $0) }) {
                unused.remove(at: idx)
                matched += 1
            } else {
                missing.append(token)
            }
        }
        return (matched, missing, unused)
    }

    private static func tokensLooselyMatch(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if canonical(a) == canonical(b) { return true }
        if a.count >= 2, b.count >= 2, a.contains(b) || b.contains(a) { return true }
        return false
    }

    private static func canonical(_ token: String) -> String {
        synonymRoot[token] ?? token
    }

    private static func chineseCharacterSimilarity(_ a: String, _ b: String) -> Double {
        let aChars = Set(chineseCharacters(a).filter { !chineseStops.contains(String($0)) })
        let bChars = Set(chineseCharacters(b).filter { !chineseStops.contains(String($0)) })
        guard !aChars.isEmpty, !bChars.isEmpty else { return 0 }
        let inter = Double(aChars.intersection(bChars).count)
        let union = Double(aChars.union(bChars).count)
        return union == 0 ? 0 : inter / union
    }

    private static func chineseCharacters(_ text: String) -> [Character] {
        text.filter { char in
            char.unicodeScalars.contains { scalar in
                scalar.value >= 0x4E00 && scalar.value <= 0x9FFF
            }
        }
    }

    private static func looksLikeChinese(_ text: String) -> Bool {
        chineseCharacters(text).count >= 2
    }

    private static func sanitizeChinese(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters).union(.init(charactersIn: "「」\"'")))
    }
}
