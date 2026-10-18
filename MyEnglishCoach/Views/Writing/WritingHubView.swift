import SwiftUI

struct WritingHubView: View {
    @Environment(StudyStore.self) private var store
    @State private var plan: DailyPlan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("把中文译成完整英语句子。可用软键盘，也可用 Apple Pencil 书写后识别。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)

                    if let plan {
                        NavigationLink {
                            PracticeSessionView(title: "造句翻译", subtitle: "中译英 · 语法点会在答案里点明", tasks: plan.writingTasks)
                        } label: {
                            Label("开始今日造句（\(plan.writingTasks.count) 题）", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryCoachButtonStyle())
                    }

                    let total = store.content.sentences.count
                    let learned = store.introducedCount(of: .sentence)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("句库进度")
                            .font(.headline)
                            .foregroundStyle(AppTheme.navy)
                        ProgressView(value: Double(learned), total: Double(max(total, 1)))
                            .tint(AppTheme.navy)
                        Text("已引入 \(learned) / \(total) 句。错过的句子会在 8 小时内回滚。")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(16)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("本库语法重点")
                            .font(.headline)
                        ForEach(["祈使句与安全指令", "情态动词 must / should", "动词短语与不规则过去式", "although / therefore / in contrast", "被动语态 may be accepted"], id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle")
                                .foregroundStyle(AppTheme.ink)
                        }
                    }
                    .padding(16)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
                }
                .padding(20)
            }
            .paperBackground()
            .navigationTitle("语法写作")
            .onAppear { plan = store.planToday() }
            .onChange(of: store.lastRefresh) { _, _ in plan = store.planToday() }
        }
    }
}
