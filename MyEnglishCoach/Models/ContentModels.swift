import Foundation

enum ContentCategory: String, Codable, CaseIterable, Identifiable {
    case irregularVerb
    case phrasalVerb
    case academic
    case trades
    case core

    var id: String { rawValue }

    var title: String {
        switch self {
        case .irregularVerb: "不规则动词"
        case .phrasalVerb: "动词短语"
        case .academic: "学术英语"
        case .trades: "工科/入学英语"
        case .core: "核心词汇"
        }
    }

    var symbol: String {
        switch self {
        case .irregularVerb: "arrow.triangle.2.circlepath"
        case .phrasalVerb: "text.word.spacing"
        case .academic: "book.closed"
        case .trades: "wrench.and.screwdriver"
        case .core: "textformat.abc"
        }
    }
}

enum ContentType: String, Codable, CaseIterable {
    case vocab
    case sentence
    case recitation
}

enum PracticeKind: String, Codable, CaseIterable {
    case vocabSpell
    case vocabToChinese
    case verbForm
    case phrasalGap
    case sentence
    case recitation

    var title: String {
        switch self {
        case .vocabSpell: "拼写"
        case .vocabToChinese: "英译中"
        case .verbForm: "动词变形"
        case .phrasalGap: "短语填空"
        case .sentence: "造句翻译"
        case .recitation: "口语背诵"
        }
    }

    var contentType: ContentType {
        switch self {
        case .vocabSpell, .vocabToChinese, .verbForm, .phrasalGap: .vocab
        case .sentence: .sentence
        case .recitation: .recitation
        }
    }
}

enum VerbFormKind: String, Codable, CaseIterable {
    case past
    case pastParticiple
    case gerund

    var promptLabel: String {
        switch self {
        case .past: "过去式"
        case .pastParticiple: "过去分词"
        case .gerund: "动名词 / 现在分词"
        }
    }
}

struct VocabItem: Identifiable, Codable, Hashable {
    let id: String
    let english: String
    let chinese: String
    let phonetic: String
    let category: ContentCategory
    let past: String?
    let pastParticiple: String?
    let gerund: String?
    let exampleEn: String
    let exampleZh: String
    let gapSentence: String?
    let gapAnswer: String?
    let accepted: [String]
    let notes: String?

    var allAcceptedEnglish: [String] {
        ([english] + accepted).map { $0.lowercased() }
    }

    func form(for kind: VerbFormKind) -> String? {
        switch kind {
        case .past: past
        case .pastParticiple: pastParticiple
        case .gerund: gerund
        }
    }
}

struct SentenceItem: Identifiable, Codable, Hashable {
    let id: String
    let chinese: String
    let english: String
    let focus: String
    let focusZh: String
    let track: ContentCategory
    let accepted: [String]
}

struct RecitationItem: Identifiable, Codable, Hashable {
    let id: String
    let chinese: String
    let english: String
    let track: ContentCategory
    let tip: String
}

enum StudyStage: String, Hashable {
    case fresh
    case review
    case rollback

    var badgeTitle: String {
        switch self {
        case .fresh: "新学"
        case .review: "复习"
        case .rollback: "回滚"
        }
    }
}

struct PracticeTask: Identifiable, Hashable {
    let id: String
    let kind: PracticeKind
    let contentId: String
    let prompt: String
    let expected: String
    let accepted: [String]
    let hint: String
    let subtitle: String
    let exampleEn: String
    let exampleZh: String
    let choices: [String]
    let stage: StudyStage

    var isNew: Bool { stage == .fresh }
}
