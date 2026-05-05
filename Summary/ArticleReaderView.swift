//
//  ArticleReaderView.swift
//  Summary
//

import SwiftUI

struct ArticleReaderView: View {
    @Environment(SnippetStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let article: Article

    enum Phase: Equatable {
        case idle           // article visible, ready to pinch
        case pinching       // user pinching; pill appearing
        case reading        // article shimmering, dot descending
        case morphing       // article fading, summary card emerging
        case composing      // card visible, summary streaming in
        case summarized     // summary done; pinch out to dismiss
    }

    @State private var phase: Phase = .idle
    @State private var pinchAmount: CGFloat = 0
    @State private var passedThreshold: Bool = false
    @State private var readingProgress: Double = 0
    @State private var morphProgress: CGFloat = 0
    @State private var generationProgress: Double = 0
    @State private var showSavedToast: Bool = false
    @State private var toastMessage: String = "Saved to snippets"
    @State private var showSnippets: Bool = false
    @State private var commitTask: Task<Void, Never>? = nil

    private let commitThreshold: CGFloat = 0.5
    private let pinchSensitivity: CGFloat = 1.4
    private let readingDuration: Double = 3.0

    private var canSummarize: Bool { article.paragraphs.count >= 3 }
    private var pinchEnabled: Bool {
        canSummarize && (phase == .idle || phase == .pinching || phase == .summarized)
    }

    private var isShimmering: Bool {
        phase == .reading
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .opacity(topBarOpacity)
                    .allowsHitTesting(phase == .idle)

                ZStack(alignment: .topLeading) {
                    articleScroll
                        .opacity(articleOpacity)
                        .blur(radius: articleBlur)
                        .scaleEffect(articleScale, anchor: .center)
                        .accessibilityAction(named: "Summarize article") {
                            guard canSummarize, phase == .idle else { return }
                            commit()
                        }

                    GeometryReader { proxy in
                        if phase == .reading {
                            LeadingDot()
                                .position(
                                    x: 18,
                                    y: dotY(in: proxy.size.height)
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.6)))
                                .animation(.easeInOut(duration: 0.25), value: phase)
                                .allowsHitTesting(false)
                        }
                    }

                    SummaryCardView(
                        article: article,
                        isArmed: false,
                        generationProgress: generationProgress
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 80)
                    .opacity(cardOpacity)
                    .scaleEffect(cardScale, anchor: .center)
                    .blur(radius: cardBlur)
                    .allowsHitTesting(phase == .summarized)
                    .accessibilityAction(named: "Expand summary") {
                        guard phase == .summarized else { return }
                        dismissSummary()
                    }
                }
                .contentShape(Rectangle())
                .simultaneousGesture(pinchEnabled ? pinchGesture : nil)
            }
            .animation(.easeInOut(duration: 0.35), value: phase)

            VStack {
                Spacer().frame(height: 8)
                StatusPillView(label: pillLabel, isActive: phase != .idle && phase != .summarized)
                    .opacity(pillOpacity)
                    .scaleEffect(pillScale, anchor: .top)
                    .animation(.easeInOut(duration: 0.25), value: phase)
                Spacer()
            }
            .allowsHitTesting(false)
            .padding(.top, 4)

            VStack {
                Spacer()
                if showSavedToast {
                    SavedToastView(message: toastMessage)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .allowsHitTesting(false)
        }
        .sheet(isPresented: $showSnippets) {
            SnippetsSheetView()
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Text(article.source.uppercased())
                .font(.caption)
                .tracking(1.2)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                showSnippets = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bookmark")
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .padding(6)

                    if store.snippets.count > 0 {
                        Text("\(store.snippets.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor))
                            .offset(x: 4, y: -2)
                    }
                }
            }
            .accessibilityLabel("Snippets — \(store.snippets.count) saved")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var topBarOpacity: Double {
        switch phase {
        case .idle: return 1
        case .pinching: return Double(1 - pinchAmount * 0.4)
        case .reading: return 0.5
        case .morphing, .composing, .summarized: return 0
        }
    }

    // MARK: - Article scroll

    private var articleScroll: some View {
        ScrollView {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isShimmering)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                articleBodyContent(t: t)
                    .padding(.leading, 36)   // space for the scanning dot
                    .padding(.trailing, 20)
                    .padding(.bottom, 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .scrollDisabled(phase != .idle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(article.title). \(article.paragraphs.joined(separator: " "))")
    }

    @ViewBuilder
    private func articleBodyContent(t: TimeInterval) -> some View {
        if isShimmering {
            // Drive both shaders from a single time uniform. Modulo-wrapped to keep
            // Float precision sharp even after long sessions.
            let shaderTime = Float(t.truncatingRemainder(dividingBy: 1000))

            rawArticleBody
                .foregroundStyle(.primary)
                .visualEffect { content, geometry in
                    content
                        .distortionEffect(
                            ShaderLibrary.textRipple(
                                .float(shaderTime),
                                .float2(Float(geometry.size.width),
                                        Float(geometry.size.height))
                            ),
                            maxSampleOffset: CGSize(width: 12, height: 12)
                        )
                        .colorEffect(
                            ShaderLibrary.rippleShimmer(
                                .float(shaderTime),
                                .float2(Float(geometry.size.width),
                                        Float(geometry.size.height))
                            )
                        )
                }
        } else {
            rawArticleBody
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private var rawArticleBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            ParagraphView(text: article.title, style: .title)
                .padding(.top, 12)

            ForEach(Array(article.paragraphs.enumerated()), id: \.offset) { _, text in
                ParagraphView(text: text, style: .body)
            }
        }
    }

    private func dotY(in viewportHeight: CGFloat) -> CGFloat {
        let topInset: CGFloat = 28
        let bottomInset: CGFloat = 60
        let usable = max(0, viewportHeight - topInset - bottomInset)
        return topInset + CGFloat(readingProgress) * usable
    }

    // MARK: - Computed visuals

    private var articleOpacity: Double {
        switch phase {
        case .idle: return 1
        case .pinching: return 1 - 0.05 * Double(pinchAmount)
        case .reading: return 1
        case .morphing: return 1 - 0.85 * Double(morphProgress)
        case .composing, .summarized: return 0.15
        }
    }

    private var articleBlur: CGFloat {
        switch phase {
        case .morphing: return 5 * morphProgress
        case .composing, .summarized: return 5
        default: return 0
        }
    }

    private var articleScale: CGFloat {
        switch phase {
        case .pinching: return 1 - 0.025 * pinchAmount
        case .reading: return 1
        case .morphing: return 1 - 0.04 * morphProgress
        case .composing, .summarized: return 0.96
        case .idle: return 1
        }
    }

    private var cardOpacity: Double {
        switch phase {
        case .morphing: return Double(morphProgress)
        case .composing, .summarized: return 1
        default: return 0
        }
    }

    private var cardScale: CGFloat {
        switch phase {
        case .morphing: return 0.7 + 0.3 * morphProgress
        case .composing, .summarized: return 1
        default: return 0.7
        }
    }

    private var cardBlur: CGFloat {
        switch phase {
        case .morphing: return 8 * (1 - morphProgress)
        default: return 0
        }
    }

    private var pillOpacity: Double {
        switch phase {
        case .idle: return 0
        case .pinching: return min(1, max(0, Double(pinchAmount) * 1.6))
        case .reading, .morphing, .composing: return 1
        case .summarized: return 0
        }
    }

    private var pillScale: CGFloat {
        phase == .pinching ? (0.9 + 0.1 * pinchAmount) : 1.0
    }

    private var pillLabel: String {
        switch phase {
        case .idle: return "Summarising article"
        case .pinching:
            return passedThreshold ? "Release to summarise" : "Keep pinching"
        case .reading: return "Reading article"
        case .morphing, .composing: return "Composing summary"
        case .summarized: return "Done"
        }
    }

    // MARK: - Gesture

    private var pinchGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.001)
            .onChanged { value in
                let m = value.magnification
                if phase == .summarized {
                    handleDismissalPinch(magnification: m)
                } else {
                    handleSummarisingPinch(magnification: m)
                }
            }
            .onEnded { _ in
                if phase == .summarized {
                    if pinchAmount >= commitThreshold {
                        dismissSummary()
                    } else {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                            pinchAmount = 0
                        }
                    }
                } else if phase == .pinching {
                    if pinchAmount >= commitThreshold {
                        commit()
                    } else {
                        cancelPinch()
                    }
                }
            }
    }

    private func handleSummarisingPinch(magnification m: CGFloat) {
        guard m <= 1 else { return }
        if phase == .idle { phase = .pinching }

        let target = max(0, min(1, (1 - m) * pinchSensitivity))
        let previous = pinchAmount

        withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.86)) {
            pinchAmount = target
        }

        if !passedThreshold && previous < commitThreshold && target >= commitThreshold {
            Haptics.soft()
            passedThreshold = true
        } else if passedThreshold && target < commitThreshold {
            passedThreshold = false
        }
    }

    private func handleDismissalPinch(magnification m: CGFloat) {
        guard m >= 1 else { return }
        let target = max(0, min(1, (m - 1) * pinchSensitivity))
        withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.86)) {
            pinchAmount = target
        }
    }

    // MARK: - State transitions

    private func commit() {
        Haptics.success()
        commitTask?.cancel()
        commitTask = Task { @MainActor in
            await runCommitSequence()
        }
    }

    private func runCommitSequence() async {
        snap {
            readingProgress = 0
            morphProgress = 0
            generationProgress = 0
        }
        passedThreshold = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            pinchAmount = 0
        }
        phase = .reading

        guard await sleepCheck(.milliseconds(220)) else { return }

        if reduceMotion {
            withAnimation(.linear(duration: 0.6)) { readingProgress = 1 }
            guard await sleepCheck(.milliseconds(620)) else { return }
        } else {
            withAnimation(.linear(duration: readingDuration)) { readingProgress = 1 }
            guard await sleepCheck(.milliseconds(UInt64(readingDuration * 1000) + 80)) else { return }
        }

        guard await sleepCheck(.milliseconds(180)) else { return }

        phase = .morphing
        let morphCurve: Animation = reduceMotion
            ? .linear(duration: 0.3)
            : .spring(response: 0.55, dampingFraction: 0.82)
        withAnimation(morphCurve) {
            morphProgress = 1
        }
        guard await sleepCheck(.milliseconds(reduceMotion ? 320 : 580)) else { return }

        phase = .composing
        if reduceMotion {
            withAnimation(.linear(duration: 0.3)) { generationProgress = 1 }
            guard await sleepCheck(.milliseconds(320)) else { return }
        } else {
            withAnimation(.easeOut(duration: 1.2)) { generationProgress = 1 }
            guard await sleepCheck(.milliseconds(1240)) else { return }
        }

        let result = store.add(from: article)
        toastMessage = result == .alreadyExists ? "Already in snippets" : "Saved to snippets"
        phase = .summarized

        withAnimation(reduceMotion ? .linear(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.7)) {
            showSavedToast = true
        }
        guard await sleepCheck(.milliseconds(1800)) else { return }
        withAnimation(.easeOut(duration: 0.3)) { showSavedToast = false }
    }

    private func cancelPinch() {
        Haptics.light()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            pinchAmount = 0
        }
        passedThreshold = false
        phase = .idle
    }

    private func dismissSummary() {
        Haptics.soft()
        commitTask?.cancel()

        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            pinchAmount = 0
            morphProgress = 0
        }
        phase = .idle
        snap {
            readingProgress = 0
            generationProgress = 0
        }
    }

    // MARK: - Helpers

    @discardableResult
    private func sleepCheck(_ duration: Duration) async -> Bool {
        do { try await Task.sleep(for: duration) } catch { return false }
        return !Task.isCancelled
    }

    private func snap(_ change: () -> Void) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t, change)
    }
}

// MARK: - Paragraph

private struct ParagraphView: View {
    enum Style { case title, body }

    let text: String
    let style: Style

    var body: some View {
        switch style {
        case .title:
            Text(text)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .body:
            Text(text)
                .font(.system(size: 17))
                .lineSpacing(7)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Leading dot

private struct LeadingDot: View {
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.22))
                .blur(radius: 10)
                .frame(width: 36, height: 36)

            Circle()
                .fill(Color.accentColor.opacity(0.55))
                .blur(radius: 4)
                .frame(width: 16, height: 16)

            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
                .shadow(color: .accentColor.opacity(0.9), radius: 3)
        }
        .scaleEffect(pulse ? 1.18 : 0.9)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Status pill

private struct StatusPillView: View {
    let label: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeat(.continuous), isActive: isActive)

            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: label)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }
}

// MARK: - Toast

private struct SavedToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule().strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }
}

#Preview {
    ArticleReaderView(article: .sample)
        .environment(SnippetStore())
}
