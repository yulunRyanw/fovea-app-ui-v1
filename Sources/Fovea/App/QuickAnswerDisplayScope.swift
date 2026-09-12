import Foundation

/// How much of a conversation the QuickAnswer window shows at once.
///
/// This is a DISPLAY bound and nothing else. It never truncates what the model
/// is given, never changes the native thread, never limits what may be asked
/// next and never removes a saved row: everything earlier stays in Codex and in
/// History, reachable through "continue in Codex" and through History itself.
enum QuickAnswerDisplayScope {
    /// The choices offered in the existing QuickAnswer settings.
    static let options = [3, 5, 10]
    static let defaultPairLimit = 3
    static let preferenceKey = "settings.quickAnswer.displayPairLimit"

    /// One pair is one question and its answer. Tool activity, progress and
    /// additions that belong to the SAME native turn are not counted again,
    /// because they are not separate cards.
    static func pairLimit(defaults: UserDefaults = .standard) -> Int {
        let saved = defaults.integer(forKey: preferenceKey)
        return options.contains(saved) ? saved : defaultPairLimit
    }

    static func setPairLimit(_ limit: Int, defaults: UserDefaults = .standard) {
        guard options.contains(limit) else { return }
        defaults.set(limit, forKey: preferenceKey)
    }

    /// Which of `count` ordered cards stay on screen.
    ///
    /// - `anchor`: a record the user opened deliberately from History. While it
    ///   is set the window stays on THAT record instead of following the tail,
    ///   so an unrelated new turn elsewhere in the conversation cannot replace
    ///   what the user asked to see.
    /// - `pinned`: cards the bound may not evict — the one being read or
    ///   selected in, one holding a request the user still has to answer, and
    ///   the questions this window itself sent after an anchored record.
    ///
    /// The result is always in conversation order and never empty for a
    /// non-empty conversation: a limit is a window onto the tail, not a licence
    /// to remove what somebody is using.
    static func visibleIndices(
        count: Int,
        limit: Int,
        anchor: Int? = nil,
        pinned: Set<Int> = []
    ) -> [Int] {
        guard count > 0 else { return [] }
        let bound = max(1, limit)
        var kept: Set<Int>
        if let anchor, anchor >= 0, anchor < count {
            kept = [anchor]
        } else {
            kept = Set(max(0, count - bound) ..< count)
        }
        kept.formUnion(pinned.filter { $0 >= 0 && $0 < count })
        return kept.sorted()
    }

    /// Native turns a window that shows `limit` pairs may open a NEW card for.
    ///
    /// A projection carries the whole thread. Building a card, a renderer and a
    /// durable row for a turn the window will not show is the "import it all,
    /// then hide it" cost the display bound exists to avoid, so a turn older
    /// than the bound is left where it already is — in Codex, and in the rows
    /// the import already saved. Turns a card ALREADY stands for are always
    /// updated, wherever they sit in the thread.
    static func projectableTurnIDs(_ orderedTurnIDs: [String], limit: Int) -> Set<String> {
        Set(orderedTurnIDs.suffix(max(1, limit)))
    }
}
