//
//  ContentView.swift
//  Novi
//
//  Two-pane screen: write on the left, see the live translation and the
//  generated lesson on the right.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = LessonViewModel()

    var body: some View {
        HSplitView {
            JournalInputView(viewModel: viewModel)
                .frame(minWidth: 320, idealWidth: 420)

            TranslationOutputView(viewModel: viewModel)
                .frame(minWidth: 320, idealWidth: 460)
        }
        .frame(minWidth: 760, minHeight: 520)
        .onChange(of: viewModel.journalEntry) {
            viewModel.scheduleLiveTranslation()
        }
        .onChange(of: viewModel.sourceLanguage) {
            viewModel.scheduleLiveTranslation()
        }
        .onChange(of: viewModel.targetLanguage) {
            viewModel.scheduleLiveTranslation()
        }
        .onDisappear { viewModel.cancelLiveTranslation() }
    }
}

#Preview {
    ContentView()
}
