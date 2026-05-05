//
//  Models.swift
//  Summary
//

import Foundation

struct Snippet: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var title: String
    var source: String
    var summaryLines: [String]
    var url: String?
    var savedAt: Date
}

struct Article: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var source: String
    var paragraphs: [String]
    var summaryLines: [String]
    var url: String?
}

extension Article {
    static let sample = Article(
        title: "The End of Reading at Length",
        source: "The Atlantic",
        paragraphs: [
            "Somewhere between the rise of the smartphone and the collapse of the magazine subscription, the long-form essay quietly stopped being a habit. Not all at once, and not for everyone. But the shape of attention changed, and with it the shape of the writing that grows in attention's soil.",
            "Reading was once a private kind of patience. You bought a magazine, you sat with it, you turned pages slowly. The medium itself imposed a tempo — and inside that tempo, ideas had room to develop. A two-thousand-word essay was not a chore; it was the smallest unit in which a worthwhile argument could fit.",
            "Now the unit of attention is the swipe. Algorithms are tuned to the eight-second decision: keep scrolling, or stay. Headlines are written for that decision, and increasingly, so are the articles beneath them. The opening paragraph has to do the work the entire piece used to do.",
            "It is tempting to call this decline. It might be more honest to call it a substitution. Long-form is not gone; it has migrated. It lives in podcasts, in newsletters, in YouTube essays that run forty minutes. People still want to spend an hour with an idea — they just want to do it while folding laundry or commuting to work.",
            "But something is lost in the migration, and it is worth naming. Reading at length is not just a delivery method. It is a discipline. The eye moves at the reader's pace, not the speaker's. You can stop, reread, argue with a sentence in the margin. Listening, however attentive, is downstream of someone else's tempo.",
            "The question is not whether long-form survives. It will, in some form. The question is whether the muscle for it survives — the patience to let an argument unfold over twenty minutes of silent reading, with nothing to keep you there but the sentences themselves."
        ],
        summaryLines: [
            "Long-form reading hasn't died — it has migrated to podcasts, newsletters, and video essays.",
            "What's lost isn't the form but the discipline: the reader, not the speaker, sets the tempo.",
            "The open question is whether the patience to read silently for twenty minutes still has a future."
        ],
        url: "https://example.com/end-of-reading-at-length"
    )
}
