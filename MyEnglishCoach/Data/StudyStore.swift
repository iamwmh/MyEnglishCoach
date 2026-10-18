import Foundation
import CoreData

struct DailyPlan {
    let vocabTasks: [PracticeTask]
    let writingTasks: [PracticeTask]
    let recitationTasks: [PracticeTask]
    let dueReviews: Int
    let newItems: Int

    var totalCount: Int { vocabTasks.count + writingTasks.count + recitationTasks.count }
    var isComplete: Bool { totalCount == 0 }
}

@Observable
final class StudyStore {
    let content: ContentStore
    let context: NSManagedObjectContext

    var lastRefresh: Date = Date()

    init(context: NSManagedObjectContext, content: ContentStore = .shared) {
        self.context = context
        self.content = content
    }

    func planToday() -> DailyPlan {
        let now = Date()
        let dueCards = dueCards(now: now)

        let dueVocab = dueCards.filter { $0.contentTypeValue == .vocab }
        let dueWriting = dueCards.filter { $0.contentTypeValue == .sentence }
        let dueRecitation = dueCards.filter { $0.contentTypeValue == .recitation }

        let newVocab = introduce(from: content.words.map(\.id), type: .vocab, limit: 15)
        let newWriting = introduce(from: content.sentences.map(\.id), type: .sentence, limit: 3)
        let dayNumber = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 5
        let recitationTarget = 5 + (dayNumber % 4)
        let recitationNeeded = max(0, recitationTarget - dueRecitation.count)
        let newRecitation = introduce(from: content.recitations.map(\.id), type: .recitation, limit: recitationNeeded)

        let vocabItems = uniqueContent(dueVocab + newVocab).prefix(28)
        let writingItems = uniqueContent(dueWriting + newWriting).prefix(8)
        let recitationItems = uniqueContent(dueRecitation + newRecitation).prefix(10)

        let vocabTasks = vocabItems.flatMap { card in
            tasks(forVocabID: card.stableContentID, isNew: !hadSuccessfulReview(card))
        }
        let writingTasks = writingItems.compactMap { card -> PracticeTask? in
            guard let item = content.sentenceMap[card.stableContentID] else { return nil }
            return writingTask(item, isNew: !hadSuccessfulReview(card))
        }
        let recitationTasks = recitationItems.compactMap { card -> PracticeTask? in
            guard let item = content.recitationMap[card.stableContentID] else { return nil }
            return recitationTask(item, isNew: !hadSuccessfulReview(card))
        }

        save()
        return DailyPlan(
            vocabTasks: interleaved(vocabTasks),
            writingTasks: Array(writingTasks),
            recitationTasks: Array(recitationTasks),
            dueReviews: dueCards.count,
            newItems: newVocab.count + newWriting.count + newRecitation.count
        )
    }

    func record(task: PracticeTask, result: CheckResult) {
        let card = card(contentId: task.contentId, type: task.kind.contentType, introduceIfNeeded: true)
        card.lastScore = result.score
        SRSEngine.schedule(card: card, quality: result.quality)

        let log = AttemptLog(context: context)
        log.id = UUID()
        log.contentId = task.contentId
        log.kind = task.kind.rawValue
        log.score = result.score
        log.isCorrect = result.isCorrect
        log.timestamp = Date()
        log.userAnswer = result.normalizedAnswer

        let progress = todayProgress()
        if result.isCorrect {
            switch task.kind.contentType {
            case .vocab: progress.vocabCompleted += 1
            case .sentence: progress.writingCompleted += 1
            case .recitation: progress.recitationCompleted += 1
            }
            if card.repetitions <= 1 {
                progress.newItemsIntroduced += 1
            } else {
                progress.reviewsCompleted += 1
            }
        }
        save()
        lastRefresh = Date()
    }

    func todayProgress() -> DailyProgress {
        let start = Calendar.current.startOfDay(for: Date())
        let request = DailyProgress.fetchRequest()
        request.predicate = NSPredicate(format: "day == %@", start as NSDate)
        request.fetchLimit = 1
        if let existing = try? context.fetch(request).first {
            return existing
        }
        let created = DailyProgress(context: context)
        created.day = start
        created.vocabCompleted = 0
        created.writingCompleted = 0
        created.recitationCompleted = 0
        created.newItemsIntroduced = 0
        created.reviewsCompleted = 0
        created.minutesStudied = 0
        return created
    }

    func recentAttempts(days: Int = 14) -> [AttemptLog] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        let request = AttemptLog.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@", start as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func allCards() -> [ReviewCard] {
        let request = ReviewCard.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "nextReview", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func masteryCount(minInterval: Double = 21) -> Int {
        allCards().filter { $0.isIntroduced && $0.intervalDays >= minInterval }.count
    }

    func introducedCount(of type: ContentType) -> Int {
        allCards().filter { $0.isIntroduced && $0.contentTypeValue == type }.count
    }

    func streak() -> Int {
        let request = DailyProgress.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "day", ascending: false)]
        let logs = (try? context.fetch(request)) ?? []
        var streak = 0
        var cursor = Calendar.current.startOfDay(for: Date())
        for log in logs {
            guard let day = log.day else { continue }
            let total = Int(log.vocabCompleted + log.writingCompleted + log.recitationCompleted)
            if Calendar.current.isDate(day, inSameDayAs: cursor) {
                if total > 0 { streak += 1 } else if streak == 0 && Calendar.current.isDateInToday(day) { continue } else { break }
                cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            } else if day > cursor {
                continue
            } else {
                break
            }
        }
        return streak
    }

    private func dueCards(now: Date) -> [ReviewCard] {
        let request = ReviewCard.fetchRequest()
        request.predicate = NSPredicate(format: "isIntroduced == YES AND nextReview <= %@", now as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(key: "intervalDays", ascending: true),
            NSSortDescriptor(key: "nextReview", ascending: true)
        ]
        return (try? context.fetch(request)) ?? []
    }

    private func introduce(from ids: [String], type: ContentType, limit: Int) -> [ReviewCard] {
        guard limit > 0 else { return [] }
        let existing = allCards().filter { $0.contentTypeValue == type }
        let pending = existing.filter { $0.isIntroduced && $0.repetitions == 0 }
        if pending.count >= limit {
            return Array(pending.prefix(limit))
        }
        var introducedIDs = Set(existing.filter(\.isIntroduced).map(\.stableContentID))
        var created = pending
        for id in ids {
            if created.count >= limit { break }
            if introducedIDs.contains(id) { continue }
            let existingCard = card(contentId: id, type: type, introduceIfNeeded: false)
            if existingCard.isIntroduced { continue }
            existingCard.isIntroduced = true
            existingCard.nextReview = Date()
            created.append(existingCard)
            introducedIDs.insert(id)
        }
        return created
    }

    private func card(contentId: String, type: ContentType, introduceIfNeeded: Bool) -> ReviewCard {
        let request = ReviewCard.fetchRequest()
        request.predicate = NSPredicate(format: "contentId == %@ AND contentType == %@", contentId, type.rawValue)
        request.fetchLimit = 1
        if let existing = try? context.fetch(request).first {
            if introduceIfNeeded { existing.isIntroduced = true }
            return existing
        }
        let card = ReviewCard(context: context)
        card.id = UUID()
        card.contentId = contentId
        card.contentType = type.rawValue
        card.easeFactor = 2.5
        card.intervalDays = 0
        card.repetitions = 0
        card.nextReview = Date()
        card.lapses = 0
        card.isIntroduced = introduceIfNeeded
        card.lastQuality = 0
        card.lastScore = 0
        return card
    }

    private func hadSuccessfulReview(_ card: ReviewCard) -> Bool {
        card.repetitions > 0 && card.lastQuality >= 3
    }

    private func uniqueContent(_ cards: [ReviewCard]) -> [ReviewCard] {
        var seen = Set<String>()
        return cards.filter { seen.insert($0.stableContentID).inserted }
    }

    private func interleaved(_ tasks: [PracticeTask]) -> [PracticeTask] {
        var news: [PracticeTask] = []
        var reviews: [PracticeTask] = []
        for task in tasks {
            if task.isNew { news.append(task) } else { reviews.append(task) }
        }
        var mixed: [PracticeTask] = []
        while !news.isEmpty || !reviews.isEmpty {
            if let review = reviews.first {
                mixed.append(review)
                reviews.removeFirst()
            }
            if let fresh = news.first {
                mixed.append(fresh)
                news.removeFirst()
            }
        }
        return mixed
    }

    private func tasks(forVocabID id: String, isNew: Bool) -> [PracticeTask] {
        guard let word = content.wordMap[id] else { return [] }
        var result: [PracticeTask] = []
        result.append(spellTask(word, isNew: isNew))
        if !isNew {
            result.append(toChineseTask(word, isNew: false))
        }
        if word.category == .irregularVerb, let formTask = verbFormTask(word, isNew: isNew) {
            result.append(formTask)
        }
        if word.category == .phrasalVerb, let gap = phrasalTask(word, isNew: isNew) {
            result.append(gap)
        }
        return result
    }

    private func spellTask(_ word: VocabItem, isNew: Bool) -> PracticeTask {
        PracticeTask(
            id: "spell-\(word.id)",
            kind: .vocabSpell,
            contentId: word.id,
            prompt: word.chinese,
            expected: word.english,
            accepted: word.accepted,
            hint: word.phonetic,
            subtitle: word.category.title,
            exampleEn: word.exampleEn,
            exampleZh: word.exampleZh,
            choices: [],
            isNew: isNew
        )
    }

    private func toChineseTask(_ word: VocabItem, isNew: Bool) -> PracticeTask {
        var pool = content.words(in: word.category).filter { $0.id != word.id }
        if pool.count < 3 {
            pool = content.words.filter { $0.id != word.id }
        }
        pool.shuffle()
        var choices = Array(pool.prefix(3).map(\.chinese))
        choices.append(word.chinese)
        choices.shuffle()
        return PracticeTask(
            id: "zh-\(word.id)",
            kind: .vocabToChinese,
            contentId: word.id,
            prompt: word.english,
            expected: word.chinese,
            accepted: [word.chinese],
            hint: word.phonetic,
            subtitle: "选择正确中文",
            exampleEn: word.exampleEn,
            exampleZh: word.exampleZh,
            choices: choices,
            isNew: isNew
        )
    }

    private func verbFormTask(_ word: VocabItem, isNew: Bool) -> PracticeTask? {
        let kinds = VerbFormKind.allCases.filter { word.form(for: $0) != nil }
        guard let kind = kinds.randomElement(), let expected = word.form(for: kind) else { return nil }
        return PracticeTask(
            id: "form-\(word.id)-\(kind.rawValue)",
            kind: .verbForm,
            contentId: word.id,
            prompt: "写出 \(word.english) 的\(kind.promptLabel)",
            expected: expected,
            accepted: expected.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespaces) },
            hint: word.chinese,
            subtitle: "\(word.english) · \(kind.promptLabel)",
            exampleEn: word.exampleEn,
            exampleZh: word.exampleZh,
            choices: [],
            isNew: isNew
        )
    }

    private func phrasalTask(_ word: VocabItem, isNew: Bool) -> PracticeTask? {
        guard let gap = word.gapSentence, let answer = word.gapAnswer else { return nil }
        return PracticeTask(
            id: "gap-\(word.id)",
            kind: .phrasalGap,
            contentId: word.id,
            prompt: gap,
            expected: answer,
            accepted: word.accepted + [word.english],
            hint: word.chinese,
            subtitle: "填入动词短语",
            exampleEn: word.exampleEn,
            exampleZh: word.exampleZh,
            choices: [],
            isNew: isNew
        )
    }

    private func writingTask(_ item: SentenceItem, isNew: Bool) -> PracticeTask {
        PracticeTask(
            id: "sent-\(item.id)",
            kind: .sentence,
            contentId: item.id,
            prompt: item.chinese,
            expected: item.english,
            accepted: item.accepted,
            hint: item.focusZh,
            subtitle: item.focus,
            exampleEn: item.english,
            exampleZh: item.focusZh,
            choices: [],
            isNew: isNew
        )
    }

    private func recitationTask(_ item: RecitationItem, isNew: Bool) -> PracticeTask {
        PracticeTask(
            id: "rec-\(item.id)",
            kind: .recitation,
            contentId: item.id,
            prompt: item.chinese,
            expected: item.english,
            accepted: [item.english],
            hint: item.tip,
            subtitle: item.track.title,
            exampleEn: item.english,
            exampleZh: item.chinese,
            choices: [],
            isNew: isNew
        )
    }

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
        }
    }
}
