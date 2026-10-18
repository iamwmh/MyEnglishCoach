import Foundation

struct ScoringRationale: Equatable {
    var relationToSample: String
    var meaningComment: String
    var wordIssues: [String]
    var structureComment: String
    var scoringSteps: [String]
    var strengths: [String]
    var spellingIssues: [String] = []
    var backTranslatedChinese: String = ""

    var relationLabel: String {
        switch relationToSample {
        case "unrelated": "回译后与待译中文无关，不能算翻译。"
        case "equivalent": "回译后与待译中文意思一致：说法不同也可以是正确答案。"
        case "weaker": "回译后大体对应中文，但有遗漏或不够准确。"
        case "incorrect": "回译后与待译中文差距较大。"
        default: "已用回译对照待译中文，不要求和参考译文逐字相同。"
        }
    }

    var isUnrelatedToSource: Bool { relationToSample == "unrelated" }
}

struct CheckResult: Equatable {
    let isCorrect: Bool
    let score: Double
    let quality: Int
    let normalizedAnswer: String
    let normalizedExpected: String
    let feedback: String
    var rationale: ScoringRationale? = nil
    var originalAnswer: String = ""

    var shownAnswer: String {
        let original = originalAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        return original.isEmpty ? normalizedAnswer : original
    }
}

enum AnswerChecker {
    static func check(answer rawAnswer: String, expected: String, accepted: [String], kind: PracticeKind) -> CheckResult {
        let answer = normalize(rawAnswer, chinese: kind == .vocabToChinese)
        let candidates = ([expected] + accepted).map { normalize($0, chinese: kind == .vocabToChinese) }.filter { !$0.isEmpty }
        let original = rawAnswer.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !answer.isEmpty else {
            return CheckResult(
                isCorrect: false,
                score: 0,
                quality: 0,
                normalizedAnswer: "",
                normalizedExpected: candidates.first ?? "",
                feedback: "没有识别到内容，请再试一次。",
                originalAnswer: original
            )
        }

        if candidates.contains(answer) {
            return CheckResult(
                isCorrect: true,
                score: 100,
                quality: 5,
                normalizedAnswer: answer,
                normalizedExpected: expected,
                feedback: "完全正确。",
                originalAnswer: original
            )
        }

        let best = candidates.map { candidate -> (String, Double) in
            let ratio = similarity(answer, candidate)
            return (candidate, ratio)
        }.max(by: { $0.1 < $1.1 })

        let ratio = best?.1 ?? 0
        let nearest = best?.0 ?? expected
        let percent = (ratio * 100).rounded()

        if kind == .sentence || kind == .recitation {
            if ratio >= 0.92 {
                return CheckResult(isCorrect: true, score: percent, quality: 5, normalizedAnswer: answer, normalizedExpected: nearest, feedback: "非常接近标准表达。", originalAnswer: original)
            }
            if ratio >= 0.80 {
                return CheckResult(isCorrect: true, score: percent, quality: 4, normalizedAnswer: answer, normalizedExpected: nearest, feedback: "意思正确，个别用词或词序可以更地道。", originalAnswer: original)
            }
            if ratio >= 0.62 {
                return CheckResult(isCorrect: false, score: percent, quality: 2, normalizedAnswer: answer, normalizedExpected: nearest, feedback: "部分正确，请对照标准句再练一遍。", originalAnswer: original)
            }
            return CheckResult(isCorrect: false, score: percent, quality: 1, normalizedAnswer: answer, normalizedExpected: nearest, feedback: "差距较大，先看中文提示，再听标准句。", originalAnswer: original)
        }

        if ratio >= 0.90 {
            return CheckResult(isCorrect: true, score: percent, quality: 4, normalizedAnswer: answer, normalizedExpected: nearest, feedback: "几乎正确，注意拼写细节。", originalAnswer: original)
        }
        if ratio >= 0.72 {
            return CheckResult(isCorrect: false, score: percent, quality: 2, normalizedAnswer: answer, normalizedExpected: nearest, feedback: "接近了，再核对字母和词形。", originalAnswer: original)
        }
        return CheckResult(isCorrect: false, score: percent, quality: 1, normalizedAnswer: answer, normalizedExpected: nearest, feedback: "还需要记住这个词形。", originalAnswer: original)
    }

    static func normalize(_ text: String, chinese: Bool) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: "’", with: "'")
        value = value.replacingOccurrences(of: "‘", with: "'")
        value = value.replacingOccurrences(of: "“", with: "\"")
        value = value.replacingOccurrences(of: "”", with: "\"")
        value = value.replacingOccurrences(of: "—", with: "-")
        value = value.replacingOccurrences(of: "–", with: "-")
        if chinese {
            let scalars = value.unicodeScalars.filter { scalar in
                CharacterSet.whitespacesAndNewlines.contains(scalar)
                    || !CharacterSet.punctuationCharacters.contains(scalar)
            }
            value = String(String.UnicodeScalarView(scalars))
        } else {
            // Treat punctuation as a word break so "quotation,do" stays two words.
            value = value.unicodeScalars.map { scalar -> String in
                if CharacterSet.whitespacesAndNewlines.contains(scalar) { return " " }
                if scalar == "'" { return "'" }
                if CharacterSet.alphanumerics.contains(scalar) { return String(scalar) }
                return " "
            }.joined()
        }
        value = value.lowercased()
        while value.contains("  ") {
            value = value.replacingOccurrences(of: "  ", with: " ")
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func similarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1 }
        let aTokens = tokens(a)
        let bTokens = tokens(b)
        if aTokens.count > 1 || bTokens.count > 1 {
            let overlap = Double(Set(aTokens).intersection(Set(bTokens)).count)
            let union = Double(Set(aTokens).union(Set(bTokens)).count)
            let jaccard = union == 0 ? 0 : overlap / union
            let lev = levenshteinRatio(a, b)
            return max(jaccard, lev)
        }
        return levenshteinRatio(a, b)
    }

    private static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace }).map(String.init).filter { !$0.isEmpty }
    }

    private static func levenshteinRatio(_ a: String, _ b: String) -> Double {
        let distance = Double(levenshtein(a, b))
        let longest = Double(max(a.count, b.count))
        guard longest > 0 else { return 1 }
        return max(0, 1 - distance / longest)
    }

    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        if aChars.isEmpty { return bChars.count }
        if bChars.isEmpty { return aChars.count }

        var previous = Array(0...bChars.count)
        var current = Array(repeating: 0, count: bChars.count + 1)

        for i in 1...aChars.count {
            current[0] = i
            for j in 1...bChars.count {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
            }
            previous = current
        }
        return previous[bChars.count]
    }
}
