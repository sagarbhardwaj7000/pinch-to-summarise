//
//  SummaryApp.swift
//  Summary
//

import SwiftUI

@main
struct SummaryApp: App {
    @State private var snippetStore = SnippetStore()

    var body: some Scene {
        WindowGroup {
            ArticleReaderView(article: .sample)
                .environment(snippetStore)
        }
    }
}
