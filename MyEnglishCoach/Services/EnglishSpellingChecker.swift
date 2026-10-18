import UIKit

struct SpellingFinding: Equatable {
    let word: String
    let suggestion: String?

    var line: String {
        if let suggestion, !suggestion.isEmpty, suggestion.caseInsensitiveCompare(word) != .orderedSame {
            return "「\(word)」拼写错误，应为「\(suggestion)」。"
        }
        return "「\(word)」拼写不正确。"
    }
}

enum EnglishSpellingChecker {
    private static let extraAllowed = [
        "ppe", "hvac", "bcit", "whmis", "sds", "msds", "csa", "rfi", "id", "mm",
        "lockout", "tagout", "journeyman"
    ]

    static func findings(in text: String, allowedFromReference references: [String]) -> [SpellingFinding] {
        let allow = allowedWords(from: references)
        // Commas/semicolons without a following space must not glue two words together.
        let text = AnswerChecker.normalize(text, chinese: false)
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let checker = UITextChecker()
        var cursor = 0
        var seen = Set<String>()
        var found: [SpellingFinding] = []

        while cursor < fullRange.length {
            let misspelled = checker.rangeOfMisspelledWord(
                in: text,
                range: NSRange(location: cursor, length: fullRange.length - cursor),
                startingAt: cursor,
                wrap: false,
                language: "en_US"
            )
            if misspelled.location == NSNotFound { break }
            let word = nsText.substring(with: misspelled)
            cursor = misspelled.location + misspelled.length
            let key = word.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            if allow.contains(key) { continue }
            if !looksLikeEnglishWord(word) { continue }
            if isAcceptedInUSOrGB(word) { continue }

            let guesses = checker.guesses(forWordRange: misspelled, in: text, language: "en_US")
                ?? checker.guesses(forWordRange: misspelled, in: text, language: "en_GB")
            found.append(SpellingFinding(word: word, suggestion: guesses?.first))
        }
        return found
    }

    private static func allowedWords(from references: [String]) -> Set<String> {
        var words = Set(extraAllowed)
        for reference in references {
            let tokens = reference.split { !$0.isLetter && $0 != "'" }.map { String($0).lowercased() }
            tokens.filter { $0.count > 1 }.forEach { words.insert($0) }
        }
        return words
    }

    private static func looksLikeEnglishWord(_ word: String) -> Bool {
        let letters = word.filter(\.isLetter)
        guard letters.count >= 2 else { return false }
        return letters.allSatisfy(\.isASCII)
    }

    private static func isAcceptedInUSOrGB(_ word: String) -> Bool {
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: (word as NSString).length)
        for language in ["en_US", "en_GB"] {
            let miss = checker.rangeOfMisspelledWord(
                in: word,
                range: range,
                startingAt: 0,
                wrap: false,
                language: language
            )
            if miss.location == NSNotFound { return true }
        }
        return false
    }
}
