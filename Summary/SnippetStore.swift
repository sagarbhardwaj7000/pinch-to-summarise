//
//  SnippetStore.swift
//  Summary
//

import Foundation
import Observation

@MainActor
@Observable
final class SnippetStore {
    private(set) var snippets: [Snippet] = []

    private let storageKey = "snippets.v1"

    init() { load() }

    enum AddResult { case added, alreadyExists }

    @discardableResult
    func add(from article: Article) -> AddResult {
        if let url = article.url, snippets.contains(where: { $0.url == url }) {
            return .alreadyExists
        }
        let snippet = Snippet(
            title: article.title,
            source: article.source,
            summaryLines: article.summaryLines,
            url: article.url,
            savedAt: Date()
        )
        snippets.insert(snippet, at: 0)
        save()
        return .added
    }

    func remove(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        save()
    }

    func contains(url: String?) -> Bool {
        guard let url else { return false }
        return snippets.contains { $0.url == url }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snippets) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Snippet].self, from: data) else {
            return
        }
        snippets = decoded
    }
}
