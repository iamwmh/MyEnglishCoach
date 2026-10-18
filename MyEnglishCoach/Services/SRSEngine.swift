import Foundation
import CoreData

/// SM-2 spaced repetition, adapted for daily English practice.
enum SRSEngine {
    static func schedule(card: ReviewCard, quality: Int, now: Date = Date()) {
        let q = max(0, min(5, quality))
        card.lastQuality = Int16(q)
        card.lastReviewed = now
        card.isIntroduced = true

        if q < 3 {
            card.repetitions = 0
            card.intervalDays = 1
            card.lapses += 1
            card.easeFactor = max(1.3, card.easeFactor - 0.2)
            card.nextReview = Calendar.current.date(byAdding: .hour, value: 8, to: now) ?? now
            return
        }

        let ease = card.easeFactor + (0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02))
        card.easeFactor = max(1.3, ease)
        card.repetitions += 1

        switch card.repetitions {
        case 1:
            card.intervalDays = 1
        case 2:
            card.intervalDays = 6
        default:
            card.intervalDays = max(1, (card.intervalDays * card.easeFactor).rounded())
        }

        let days = max(1, Int(card.intervalDays.rounded()))
        card.nextReview = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
    }

    static func masteryLabel(for card: ReviewCard) -> String {
        if !card.isIntroduced { return "未学" }
        if card.intervalDays >= 21 { return "已巩固" }
        if card.intervalDays >= 6 { return "复习中" }
        return "新学"
    }
}

extension ReviewCard {
    var contentTypeValue: ContentType {
        ContentType(rawValue: contentType ?? "") ?? .vocab
    }

    var stableContentID: String {
        contentId ?? ""
    }
}
