//
//  NoviApp.swift
//  Novi
//
//  Created by Arjang Khademi on 06.06.26.
//

import SwiftUI
import SwiftData

@main
struct NoviApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: JournalEntryRecord.self,
                VocabularyItemRecord.self,
                WordRecord.self
            )
            DemoDataSeeder.seedIfNeeded(in: modelContainer)
        } catch {
            fatalError("Could not create model container: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .modelContainer(modelContainer)
    }
}
