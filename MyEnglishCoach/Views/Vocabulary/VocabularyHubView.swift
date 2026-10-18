import SwiftUI

struct VocabularyHubView: View {
    @Environment(StudyStore.self) private var store
    @State private var plan: DailyPlan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("入学单词量 + 不规则动词 + 动词短语。到期的卡片会优先出现。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)

                    if let plan {
                        NavigationLink {
                            PracticeSessionView(title: "单词训练", subtitle: "拼写 / 互译 / 变形 / 短语", tasks: plan.vocabTasks)
                        } label: {
                            Label("开始今日单词（\(plan.vocabTasks.count) 题）", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryCoachButtonStyle())
                    }

                    ForEach(ContentCategory.allCases) { category in
                        let words = store.content.words(in: category)
                        let learned = learnedCount(in: category)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(category.title, systemImage: category.symbol)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.navy)
                                Spacer()
                                Text("\(learned)/\(words.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.muted)
                            }
                            ProgressView(value: Double(learned), total: Double(max(words.count, 1)))
                                .tint(AppTheme.gold)
                            Text(blurb(for: category))
                                .font(.footnote)
                                .foregroundStyle(AppTheme.muted)
                        }
                        .padding(16)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
                    }
                }
                .padding(20)
            }
            .paperBackground()
            .navigationTitle("背单词")
            .onAppear { plan = store.planToday() }
            .onChange(of: store.lastRefresh) { _, _ in plan = store.planToday() }
        }
    }

    private func learnedCount(in category: ContentCategory) -> Int {
        let ids = Set(store.content.words(in: category).map(\.id))
        return store.allCards().filter { card in
            card.contentTypeValue == .vocab && card.isIntroduced && ids.contains(card.stableContentID)
        }.count
    }

    private func blurb(for category: ContentCategory) -> String {
        switch category {
        case .irregularVerb: "重点练过去式、过去分词和动名词，避免只记原形。"
        case .phrasalVerb: "工地和课堂都高频：look up、carry out、put off 等。"
        case .academic: "对准 English Studies 12：论证、证据、段落与过渡词。"
        case .trades: "对准 Trades Entry：安全、规格、图纸、测评与入学用语。"
        case .core: "高中到入学常用词，按词频优先，保证达到 50% English 12 所需词汇量。"
        }
    }
}
