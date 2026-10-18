import Charts
import SwiftUI

struct ProgressDashboardView: View {
    @Environment(StudyStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    overview
                    weeklyChart
                    categoryBreakdown
                    forgettingNote
                }
                .padding(20)
            }
            .paperBackground()
            .navigationTitle("进度")
        }
    }

    private var overview: some View {
        let progress = store.todayProgress()
        return VStack(alignment: .leading, spacing: 12) {
            Text("学习概况")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)
            HStack(spacing: 10) {
                metric("连续天数", "\(store.streak())")
                metric("已巩固", "\(store.masteryCount())")
                metric("今日完成", "\(progress.vocabCompleted + progress.writingCompleted + progress.recitationCompleted)")
            }
            HStack(spacing: 10) {
                metric("单词已引入", "\(store.introducedCount(of: .vocab))/\(store.content.words.count)")
                metric("句子", "\(store.introducedCount(of: .sentence))/\(store.content.sentences.count)")
                metric("背诵", "\(store.introducedCount(of: .recitation))/\(store.content.recitations.count)")
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var weeklyChart: some View {
        let days = lastDays(14)
        return VStack(alignment: .leading, spacing: 10) {
            Text("近 14 天练习次数")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)
            Chart(days, id: \.day) { item in
                BarMark(
                    x: .value("日", item.day, unit: .day),
                    y: .value("次", item.count)
                )
                .foregroundStyle(AppTheme.navy)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("词汇板块")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)
            ForEach(ContentCategory.allCases) { category in
                let total = store.content.words(in: category).count
                let learned = store.allCards().filter { card in
                    card.contentTypeValue == .vocab &&
                    card.isIntroduced &&
                    store.content.wordMap[card.stableContentID]?.category == category
                }.count
                HStack {
                    Text(category.title)
                    Spacer()
                    Text("\(learned)/\(total)")
                        .foregroundStyle(AppTheme.muted)
                }
                .font(.subheadline)
                ProgressView(value: Double(learned), total: Double(max(total, 1)))
                    .tint(AppTheme.gold)
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }

    private var forgettingNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("遗忘曲线如何排课")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)
            Text("答对质量高：间隔约 1 天、6 天，再按熟悉度延长。答错：8 小时后回滚，并降低容易度。已巩固指间隔达到 21 天以上的卡片。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }

    private func lastDays(_ count: Int) -> [DayCount] {
        let attempts = store.recentAttempts(days: count)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<count).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let count = attempts.filter { log in
                guard let stamp = log.timestamp else { return false }
                return calendar.isDate(stamp, inSameDayAs: day)
            }.count
            return DayCount(day: day, count: count)
        }
    }
}

private struct DayCount {
    let day: Date
    let count: Int
}
