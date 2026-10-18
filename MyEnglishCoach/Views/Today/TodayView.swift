import SwiftUI

struct TodayView: View {
    @Environment(StudyStore.self) private var store
    @State private var plan: DailyPlan?
    @State private var showCurriculum = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let plan {
                        missionCard(plan)
                        moduleCard(
                            title: "背单词",
                            detail: "拼写、中英互译、不规则动词变形、动词短语",
                            count: plan.vocabTasks.count,
                            symbol: "character.book.closed.fill",
                            destination: PracticeSessionView(
                                title: "今日单词",
                                subtitle: "新学与到期复习混合进行",
                                tasks: plan.vocabTasks
                            )
                        )
                        moduleCard(
                            title: "语法写作",
                            detail: "中文译英文，键盘或手写造句",
                            count: plan.writingTasks.count,
                            symbol: "pencil.and.scribble",
                            destination: PracticeSessionView(
                                title: "今日造句",
                                subtitle: "对准英语 12 / 工科说明文表达",
                                tasks: plan.writingTasks
                            )
                        )
                        moduleCard(
                            title: "每日背诵",
                            detail: "中文提示，录音识别并评分，约 5–10 句",
                            count: plan.recitationTasks.count,
                            symbol: "mic.fill",
                            destination: PracticeSessionView(
                                title: "今日背诵",
                                subtitle: "先看中文，再开口；错过的句子会回滚",
                                tasks: plan.recitationTasks
                            )
                        )
                    }
                }
                .padding(20)
            }
            .paperBackground()
            .navigationTitle("今日训练")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("入学目标") { showCurriculum = true }
                }
            }
            .sheet(isPresented: $showCurriculum) {
                CurriculumSheet()
            }
            .onAppear { refresh() }
            .onChange(of: store.lastRefresh) { _, _ in refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("通往 BCIT Category 3")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.gold)
            Text("英语教练")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text("English Studies 12（50%）或同等水平，或 BCIT English Trades Entry Assessment。按遗忘曲线把新内容和旧内容不断回滚。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private func missionCard(_ plan: DailyPlan) -> some View {
        let progress = store.todayProgress()
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("今日任务", systemImage: "sun.horizon.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.navy)
                Spacer()
                Text("连续 \(store.streak()) 天")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.gold)
            }
            HStack(spacing: 12) {
                stat("到期复习", "\(plan.dueReviews)")
                stat("新内容", "\(plan.newItems)")
                stat("已完成", "\(progress.vocabCompleted + progress.writingCompleted + progress.recitationCompleted)")
            }
            Text("先处理到期复习，再混入少量新词和新句，避免只学新的、把旧的忘掉。")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
        }
        .padding(18)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        .shadow(color: AppTheme.navy.opacity(0.06), radius: 12, y: 4)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func moduleCard<D: View>(title: String, detail: String, count: Int, symbol: String, destination: D) -> some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(AppTheme.navy)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.sky)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(count)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.navy)
                    Text("题")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
            }
            .padding(16)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func refresh() {
        plan = store.planToday()
    }
}

struct CurriculumSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("目标", "BCIT Category 3：English Studies 12（50%）或同等课程，或通过 BCIT English Trades Entry Assessment。")
                    section("单词", "在入学常用词汇量上，突出不规则动词（过去式、过去分词、动名词）和动词短语。练习含拼写、中英互译。")
                    section("语法与写作", "把中文句子译成英文。可用键盘，也可用手指或 Apple Pencil 手写识别。")
                    section("每日背诵", "每天 5–10 句。先看中文提示，录音后由系统识别并评分。")
                    section("遗忘曲线", "答对：1 天 → 6 天 → 之后按熟悉度拉长间隔。答错：当天回滚再练，并缩短下次复习时间。新内容和旧内容混合出现。")
                }
                .padding(20)
            }
            .paperBackground()
            .navigationTitle("训练说明")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.navy)
            Text(body)
                .font(.body)
                .foregroundStyle(AppTheme.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
