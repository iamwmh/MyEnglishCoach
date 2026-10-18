import Foundation

enum GradeCommentPolisher {
    static func looksLikeImperative(_ answer: String) -> Bool {
        let words = tokens(answer)
        guard let first = words.first else { return false }
        if pleaseStarters.contains(first) { return true }
        return imperativeVerbs.contains(first)
    }

    static func claimsMissingSubject(_ text: String) -> Bool {
        let compact = compactText(text)
        let needles = ["缺少主语", "没有主语", "缺少主词", "添加主语", "加上主语", "需要主语", "加主语", "补主语"]
        return needles.contains { compact.contains($0) }
    }

    static func stripFalseSubjectClaims(_ text: String, answer: String) -> String {
        guard looksLikeImperative(answer), claimsMissingSubject(text) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    static func uniqued(_ items: [String]) -> [String] {
        var kept: [String] = []
        for raw in items {
            let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.isEmpty else { continue }
            if kept.contains(where: { isNearDuplicate($0, item) }) { continue }
            kept.append(item)
        }
        return kept
    }

    static func isNearDuplicate(_ a: String, _ b: String) -> Bool {
        let left = compactText(a)
        let right = compactText(b)
        if left.isEmpty || right.isEmpty { return false }
        if left == right { return true }
        if left.count >= 8, right.count >= 8, left.contains(right) || right.contains(left) {
            return true
        }
        return AnswerChecker.similarity(left, right) >= 0.78
    }

    static func nearMissWordNotes(answer: String, expected: String, accepted: [String]) -> [String] {
        let student = Set(contentTokens(answer))
        let reference = Set(([expected] + accepted).flatMap(contentTokens))
        guard !student.isEmpty, !reference.isEmpty else { return [] }

        var notes: [String] = []
        var usedReference = Set<String>()
        for word in student.sorted() {
            if reference.contains(word) { continue }
            guard word.count >= 5 else { continue }
            var best: (token: String, distance: Int)?
            for candidate in reference where candidate.count >= 4 && !usedReference.contains(candidate) {
                let distance = editDistance(word, candidate)
                let allowed = word.count >= 6 ? 2 : 1
                if distance == 0 || distance > allowed { continue }
                if best == nil || distance < best!.distance {
                    best = (candidate, distance)
                }
            }
            if let best {
                usedReference.insert(best.token)
                notes.append("「\(word)」用错了，这里更可能是「\(best.token)」。")
            }
        }
        return notes
    }

    static func grammarNote(for answer: String) -> (points: Double, comment: String) {
        let words = tokens(answer)
        if words.count < 3 {
            return (8, "句子过短，信息不全")
        }
        if looksLikeImperative(answer) {
            if words.count < 5 {
                return (16, "已是祈使句，但还可以写完整一些")
            }
            return (23, "祈使句完整。Please + 动词即可，不必加主语")
        }
        if words.count < 5 {
            return (16, "基本成句，可以再写完整一些")
        }
        return (22, "句子完整")
    }

    static func structureNote(for answer: String, grammarFocus: String) -> String {
        if looksLikeImperative(answer) {
            let focus = grammarFocus.isEmpty ? "" : "本句语法点是\(grammarFocus)。"
            return "\(focus)这是祈使句，不必写出主语 you。before 从句里有主语即可。"
        }
        if grammarFocus.isEmpty {
            return "句式清楚即可，不要求和参考译文同一词序。"
        }
        return "本句可关注：\(grammarFocus)。不要求和参考译文同一句式。"
    }

    private static let pleaseStarters: Set<String> = ["please", "kindly"]
    private static let imperativeVerbs: Set<String> = [
        "read", "wear", "check", "use", "stop", "keep", "put", "take", "make", "ensure",
        "report", "replace", "remove", "turn", "lock", "follow", "wait", "ask", "call",
        "clean", "inspect", "complete", "sign", "write", "open", "close", "hold", "leave",
        "stay", "move", "shut", "switch", "press", "pull", "push", "do", "dont", "don't",
        "never", "always", "remember", "avoid", "begin", "start", "finish"
    ]
    private static let contentStops: Set<String> = [
        "the", "a", "an", "is", "are", "was", "were", "be", "been", "being", "to", "of", "and",
        "or", "but", "in", "on", "at", "for", "with", "as", "by", "from", "that", "this", "it",
        "its", "you", "your", "must", "not", "no", "do", "does", "did", "can", "cannot",
        "please", "will", "before", "after", "when"
    ]

    private static func tokens(_ text: String) -> [String] {
        AnswerChecker.normalize(text, chinese: false)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func contentTokens(_ text: String) -> [String] {
        tokens(text).filter { $0.count >= 3 && !contentStops.contains($0) }
    }

    private static func compactText(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func editDistance(_ a: String, _ b: String) -> Int {
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
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[bChars.count]
    }
}
