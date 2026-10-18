import SwiftUI

struct RecitationHubView: View {
    @Environment(StudyStore.self) private var store
    @State private var plan: DailyPlan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("每天 5–10 句。先看中文，再录音。系统把口语转成英文，对照标准句评分。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)

                    if let plan {
                        NavigationLink {
                            PracticeSessionView(title: "口语背诵", subtitle: "中文提示 · 录音评分", tasks: plan.recitationTasks)
                        } label: {
                            Label("开始今日背诵（\(plan.recitationTasks.count) 句）", systemImage: "mic.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryCoachButtonStyle())
                    }

                    let total = store.content.recitations.count
                    let learned = store.introducedCount(of: .recitation)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("背诵库")
                            .font(.headline)
                            .foregroundStyle(AppTheme.navy)
                        ProgressView(value: Double(learned), total: Double(max(total, 1)))
                            .tint(AppTheme.gold)
                        Text("已引入 \(learned) / \(total) 句。低分句子会插入稍后重读，并缩短下次复习间隔。")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(16)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("评分说明")
                            .font(.headline)
                        Text("80 分以上视为过关。识别结果会忽略标点，按单词重合度与拼写距离综合给分。请对着标准句完整说完，不要只说关键词。")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(16)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
                }
                .padding(20)
            }
            .paperBackground()
            .navigationTitle("每日背诵")
            .onAppear { plan = store.planToday() }
            .onChange(of: store.lastRefresh) { _, _ in plan = store.planToday() }
        }
    }
}
