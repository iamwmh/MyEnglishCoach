import Foundation

struct ContentStore {
    let words: [VocabItem]
    let sentences: [SentenceItem]
    let recitations: [RecitationItem]
    let wordMap: [String: VocabItem]
    let sentenceMap: [String: SentenceItem]
    let recitationMap: [String: RecitationItem]
    let wordsByCategory: [ContentCategory: [VocabItem]]

    static let shared: ContentStore = {
        do {
            return try ContentStore.load()
        } catch {
            assertionFailure("课程内容加载失败: \(error)")
            return ContentStore(words: [], sentences: [], recitations: [])
        }
    }()

    init(words: [VocabItem], sentences: [SentenceItem], recitations: [RecitationItem]) {
        self.words = words
        self.sentences = sentences
        self.recitations = recitations
        wordMap = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
        sentenceMap = Dictionary(uniqueKeysWithValues: sentences.map { ($0.id, $0) })
        recitationMap = Dictionary(uniqueKeysWithValues: recitations.map { ($0.id, $0) })
        var grouped: [ContentCategory: [VocabItem]] = [:]
        grouped.reserveCapacity(ContentCategory.allCases.count)
        for word in words {
            grouped[word.category, default: []].append(word)
        }
        wordsByCategory = grouped
    }

    func words(in category: ContentCategory) -> [VocabItem] {
        wordsByCategory[category] ?? []
    }

    private static func load() throws -> ContentStore {
        let words = try decode(VocabFile.self, resource: "vocabulary").words
        let sentences = try decode(SentenceFile.self, resource: "sentences").sentences
        let recitations = try decode(RecitationFile.self, resource: "recitations").passages
        return ContentStore(words: words, sentences: sentences, recitations: recitations)
    }

    private static func decode<T: Decodable>(_ type: T.Type, resource: String) throws -> T {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            throw LoadError.missing(resource)
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    enum LoadError: Error {
        case missing(String)
    }

    private struct VocabFile: Decodable { let words: [VocabItem] }
    private struct SentenceFile: Decodable { let sentences: [SentenceItem] }
    private struct RecitationFile: Decodable { let passages: [RecitationItem] }
}
