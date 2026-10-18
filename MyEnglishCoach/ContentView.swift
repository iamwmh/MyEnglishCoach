import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "sun.horizon.fill")
                }
            VocabularyHubView()
                .tabItem {
                    Label("单词", systemImage: "character.book.closed.fill")
                }
            WritingHubView()
                .tabItem {
                    Label("写作", systemImage: "pencil.and.scribble")
                }
            RecitationHubView()
                .tabItem {
                    Label("背诵", systemImage: "mic.fill")
                }
            ProgressDashboardView()
                .tabItem {
                    Label("进度", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
        .tint(AppTheme.navy)
    }
}

#Preview {
    let persistence = PersistenceController.preview
    ContentView()
        .environment(\.managedObjectContext, persistence.container.viewContext)
        .environment(StudyStore(context: persistence.container.viewContext, content: .shared))
}
