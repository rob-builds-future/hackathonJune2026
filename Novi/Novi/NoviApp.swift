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
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [JournalEntryRecord.self, VocabularyItemRecord.self, WordRecord.self])
    }
}
