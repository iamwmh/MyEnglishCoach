import SwiftUI
import CoreData

@main
struct MyEnglishCoachApp: App {
    private let persistenceController: PersistenceController
    @State private var studyStore: StudyStore

    init() {
        let controller = PersistenceController.shared
        persistenceController = controller
        _studyStore = State(initialValue: StudyStore(context: controller.container.viewContext))
        AppTheme.configureInputAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(studyStore)
        }
    }
}
