//
//  SnippetsSheetView.swift
//  Summary
//

import SwiftUI

struct SnippetsSheetView: View {
    @Environment(SnippetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Snippet?

    var body: some View {
        NavigationStack {
            Group {
                if store.snippets.isEmpty {
                    ContentUnavailableView(
                        "No snippets yet",
                        systemImage: "bookmark",
                        description: Text("Pinch any article to save its summary here.")
                    )
                } else {
                    List {
                        ForEach(store.snippets) { snippet in
                            SnippetRow(snippet: snippet)
                                .contentShape(Rectangle())
                                .onTapGesture { selected = snippet }
                                .contextMenu {
                                    if let urlString = snippet.url, let url = URL(string: urlString) {
                                        Link(destination: url) {
                                            Label("Open original article", systemImage: "safari")
                                        }
                                        ShareLink(item: url) {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                    }
                                    Button(role: .destructive) {
                                        store.remove(snippet)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete { indexSet in
                            indexSet.map { store.snippets[$0] }.forEach(store.remove)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Snippets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selected) { snippet in
                SnippetDetailView(snippet: snippet)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

private struct SnippetRow: View {
    let snippet: Snippet

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snippet.source.uppercased())
                .font(.caption2)
                .tracking(1.1)
                .foregroundStyle(.secondary)

            Text(snippet.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(snippet.summaryLines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.top, 2)

            Text(snippet.savedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(.vertical, 8)
    }
}

private struct SnippetDetailView: View {
    let snippet: Snippet

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(snippet.source.uppercased())
                    .font(.caption)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                Text(snippet.title)
                    .font(.system(.title2, design: .serif, weight: .semibold))

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(snippet.summaryLines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(.tint).frame(width: 5, height: 5).padding(.top, 8)
                            Text(line)
                                .font(.body)
                                .lineSpacing(5)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                if let urlString = snippet.url, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Label("Open original article", systemImage: "safari")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.top, 8)
                }
            }
            .padding(20)
        }
    }
}

#Preview {
    SnippetsSheetView()
        .environment(SnippetStore())
}
