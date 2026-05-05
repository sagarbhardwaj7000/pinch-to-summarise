//
//  SummaryCardView.swift
//  Summary
//

import SwiftUI

struct SummaryCardView: View {
    let article: Article
    var isArmed: Bool = false
    /// 0 = not generated yet (skeleton), 1 = fully generated.
    var generationProgress: Double = 0

    @State private var skeletonPulse: Double = 1.0
    @State private var caretBlink: Bool = false

    private var isGenerating: Bool {
        generationProgress > 0 && generationProgress < 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(article.source.uppercased())
                    .font(.caption2)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                if isGenerating {
                    Text("· generating")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .transition(.opacity)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse, options: .repeat(.continuous), isActive: isGenerating)
            }

            Text(article.title)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(article.summaryLines.enumerated()), id: \.offset) { index, line in
                    SummaryLineView(
                        line: line,
                        lineIndex: index,
                        totalLines: article.summaryLines.count,
                        generationProgress: generationProgress,
                        skeletonPulse: skeletonPulse,
                        caretOn: caretBlink
                    )
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isArmed ? Color.accentColor.opacity(0.6) : Color(.separator).opacity(0.5),
                    lineWidth: 0.75
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                skeletonPulse = 0.55
            }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                caretBlink = true
            }
        }
    }
}

private struct SummaryLineView: View {
    let line: String
    let lineIndex: Int
    let totalLines: Int
    let generationProgress: Double
    let skeletonPulse: Double
    let caretOn: Bool

    enum LineState: Equatable {
        case notStarted
        case streaming(visibleText: String)
        case complete
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(.tint)
                .frame(width: 5, height: 5)
                .padding(.top, 8)
                .opacity(state == .notStarted ? 0.35 : 1)

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .notStarted:
            Text(line)
                .font(.system(size: 16))
                .lineSpacing(5)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .redacted(reason: .placeholder)
                .opacity(skeletonPulse)
        case .streaming(let visibleText):
            Text(streamingAttributed(visibleText))
                .font(.system(size: 16))
                .lineSpacing(5)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        case .complete:
            Text(line)
                .font(.system(size: 16))
                .lineSpacing(5)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var state: LineState {
        let lineStart = Double(lineIndex) / Double(totalLines) * 0.85
        let lineEnd = Double(lineIndex + 1) / Double(totalLines)
        let local = (generationProgress - lineStart) / max(0.001, lineEnd - lineStart)

        if local <= 0 {
            return .notStarted
        } else if local >= 1 {
            return .complete
        } else {
            let words = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            let count = max(1, Int(ceil(Double(words.count) * local)))
            let visible = words.prefix(count).joined(separator: " ")
            return .streaming(visibleText: visible)
        }
    }

    private func streamingAttributed(_ text: String) -> AttributedString {
        let body = AttributedString(text + " ")
        var caret = AttributedString("▍")
        caret.foregroundColor = Color.accentColor.opacity(caretOn ? 0.95 : 0.35)
        return body + caret
    }
}

#Preview("Generated") {
    SummaryCardView(article: .sample, generationProgress: 1)
        .padding()
        .background(Color(.systemBackground))
}

#Preview("Skeleton") {
    SummaryCardView(article: .sample, generationProgress: 0)
        .padding()
        .background(Color(.systemBackground))
}

#Preview("Mid-generation") {
    SummaryCardView(article: .sample, generationProgress: 0.4)
        .padding()
        .background(Color(.systemBackground))
}
