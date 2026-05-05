# Pinch-to-Summarise

An iOS reading interaction prototype where pinching on an article triggers a Metal-shader "AI reading" sequence and streams a summary out of the text itself.

> Most reading apps put summarisation behind a "Summarise" button. This puts the entire act of comprehension into a single gesture: the gesture *is* the summary.

The pause between the pinch and the answer is not loading — it's comprehension, made observable.

## How it works

1. **Pinch in** on the article body. A glass status pill fades in: `Keep pinching` → `Release to summarise` past a 50% threshold (with a soft commit haptic).
2. **Release** past the threshold → success haptic, the pill switches to `Reading article`.
3. **Reading state** — a stitched Metal shader pipeline runs for ~3 seconds:
   - `rippleShimmer` (`.colorEffect`) — a diagonal cyan / blue / white shimmer band that sweeps top-right → bottom-left across the whole article body, with edge-faded wraparound so the cycle is seamless.
   - `textRipple` (`.distortionEffect`) — a localised force wave that lifts each line as the front passes, with a small damped wake. Each line settles back; the article doesn't bob ambiently.
   - A blue glowing dot descends the left column over the same window, indicating reading progress.
4. **Morph** — the article fades and blurs, the summary card grows out from the centre.
5. **Compose** — three summary lines stream in word-by-word, like an LLM response, with a blinking accent caret on the active line.
6. **Save** — the snippet is appended to a persistent library; a `Saved to snippets` toast confirms.

Pinch outward on the summary card to dismiss back to the article.

## Tech

- SwiftUI (iOS 17+; built against iOS 26 SDK)
- Two stitched Metal shaders applied via `.colorEffect` / `.distortionEffect` inside `.visualEffect`
- `MagnifyGesture` driving a six-state phase machine (`idle` → `pinching` → `reading` → `morphing` → `composing` → `summarised`)
- `@Observable` snippet store with `UserDefaults` persistence
- Layered haptic choreography (soft / light / success)
- Reduce-Motion alternative path that swaps the shader sequence for a linear cross-fade

## Running it

Open `Summary.xcodeproj` in Xcode 16+ and run on an iOS 17+ simulator or device.

If Xcode prompts for the Metal toolchain on first build:

```sh
xcodebuild -downloadComponent MetalToolchain
```

## Project layout

```
Summary/
├── Summary/
│   ├── ArticleReaderView.swift   – main view, phase machine, gesture
│   ├── SummaryCardView.swift     – frosted card + streaming lines
│   ├── SnippetsSheetView.swift   – library sheet
│   ├── Models.swift              – Article + Snippet + sample article
│   ├── SnippetStore.swift        – @Observable persistence
│   ├── Haptics.swift             – feedback generators
│   ├── Shaders.metal             – rippleShimmer + textRipple
│   └── SummaryApp.swift          – entry point
└── Summary.xcodeproj
```

## Tags & branches

- **`v1-soft-ripple`** — the calibrated soft force-wave version this README describes.
- **`main`** — stable.
- **`experiments`** — playground for future variants.

## Tuning knobs

The two shader feel-knobs live in `Shaders.metal`:

- `cycleDur` (1.4s) — full sweep period, shared by both shaders.
- `crestWidth` (0.11) in `textRipple` — narrower = sharper push, wider = softer rise.
- `perpAmp` multiplier (`6.0`) — overall lift strength.
- Layer widths in `rippleShimmer` (`wWhite` / `wBlue` / `wCyan`) — control how thin the bright band reads.

The interaction-level knobs live in `ArticleReaderView`:

- `commitThreshold` (0.5) — fraction of pinch needed to commit.
- `pinchSensitivity` (1.4) — how much the user needs to physically pinch to fully arm.
- `readingDuration` (3.0s) — how long the dot takes to descend.

## Status

Prototype. Behaviour and timings are tuned for an iPhone-class device; tablet / large screens haven't been calibrated.
