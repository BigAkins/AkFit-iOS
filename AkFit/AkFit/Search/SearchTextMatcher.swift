import Foundation

/// Pure search text helpers shared by Supabase-backed search and type-ahead.
enum SearchTextMatcher {

    /// Normalizes user-entered query text and applies known aliases.
    static func normalizedQuery(_ text: String) -> String {
        applyQueryAliases(normalizeForSearch(text))
    }

    /// Rewrites known query aliases to their canonical normalized forms.
    /// Called AFTER `normalizeForSearch` so the input is already lowercased
    /// with punctuation stripped. Handles cases where normalization alone
    /// can't bridge the gap (e.g. "innout" -> "in n out").
    static func applyQueryAliases(_ normalized: String) -> String {
        // Longest patterns first to avoid partial replacement.
        let aliases: [(from: String, to: String)] = [
            ("in and out", "in n out"),
            ("innout", "in n out"),
        ]
        var result = normalized
        for alias in aliases {
            if result.contains(alias.from) {
                result = result.replacingOccurrences(of: alias.from, with: alias.to)
            }
        }
        return result
    }

    /// Normalizes text for search comparison: lowercased, apostrophes removed,
    /// hyphens/commas/parentheses replaced with spaces, whitespace collapsed.
    /// Mirrors the Postgres `search_text` column transform.
    static func normalizeForSearch(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")   // right single quote (iOS keyboard)
            .replacingOccurrences(of: "\u{2018}", with: "")   // left single quote
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// Reduces a word to a rough stem by stripping common English plural
    /// suffixes. Not a full Porter stemmer; just enough to map
    /// "strawberries" <-> "strawberry", "blueberries" <-> "blueberry", etc.
    static func stemWord(_ word: String) -> String {
        let w = word.lowercased()
        guard w.count > 3 else { return w }
        // -ies -> -y  (strawberries -> strawberry)
        if w.hasSuffix("ies") { return String(w.dropLast(3)) + "y" }
        // -ches, -shes, -xes, -zes, -ses -> drop -es
        if w.hasSuffix("es") {
            let stem = String(w.dropLast(2))
            if stem.hasSuffix("ch") || stem.hasSuffix("sh") ||
               stem.hasSuffix("x") || stem.hasSuffix("z") || stem.hasSuffix("s") {
                return stem
            }
        }
        // trailing -s (but not -ss) -> drop -s
        if w.hasSuffix("s") && !w.hasSuffix("ss") {
            return String(w.dropLast(1))
        }
        return w
    }

    /// Stems every word in a normalized string for comparison.
    static func stemmedForm(_ text: String) -> String {
        text.split(separator: " ").map { stemWord(String($0)) }.joined(separator: " ")
    }

    /// Returns true when every normalized query word matches the term either
    /// directly or through the rough plural stem.
    static func matchesAllQueryWords(term: String, normalizedQuery: String) -> Bool {
        guard !normalizedQuery.isEmpty else { return false }
        let words = normalizedQuery.split(separator: " ").map(String.init)
        let stemmedWords = words.map { stemWord($0) }
        let normalizedTerm = normalizeForSearch(term)
        let stemmedTerm = stemmedForm(normalizedTerm)
        return words.allSatisfy { normalizedTerm.contains($0) } ||
               stemmedWords.allSatisfy { stemmedTerm.contains($0) }
    }

    /// Levenshtein edit distance between two strings. Used for typo tolerance
    /// in type-ahead suggestions. O(n*m) but only called on short food names.
    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        let m = a.count, n = b.count
        if m == 0 { return n }
        if n == 0 { return m }
        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)
        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j-1] + 1, prev[j-1] + cost)
            }
            prev = curr
        }
        return prev[n]
    }

    /// Scores how closely `name` matches `query` (query is already normalized).
    /// Lower = better match. Supports stem-aware comparison so "strawberry"
    /// matches "strawberries" at full quality.
    static func matchScore(name: String, query q: String) -> Int {
        let n = normalizeForSearch(name)
        if n == q { return 0 }

        let nStemmed = stemmedForm(n)
        let qStemmed = stemmedForm(q)
        if nStemmed == qStemmed { return 0 }

        if n.hasPrefix(q) || nStemmed.hasPrefix(qStemmed) { return 1 }

        let qWords = q.split(separator: " ").map(String.init)
        let nWords = n.split(separator: " ").map(String.init)
        let qStems = qWords.map { stemWord($0) }
        let nStems = nWords.map { stemWord($0) }

        if qWords.count <= 1 {
            let qStem = qStems[0]
            if nWords.first == q || nStems.first == qStem    { return 2 }
            if nWords.contains(where: { $0.hasPrefix(q) })   { return 3 }
            if nStems.contains(where: { $0.hasPrefix(qStem) }) { return 3 }
            return 4
        }

        // Multi-word: check if every query word is a prefix of some name word
        // (with stem-aware fallback).
        let allWordPrefixes = qWords.indices.allSatisfy { i in
            nWords.contains(where: { $0.hasPrefix(qWords[i]) }) ||
            nStems.contains(where: { $0.hasPrefix(qStems[i]) })
        }
        if allWordPrefixes {
            if let fq = qWords.first, let fn = nWords.first,
               fn.hasPrefix(fq) || stemWord(fn).hasPrefix(stemWord(fq)) {
                return 1
            }
            return 2
        }
        return 3
    }

    static func isPlainFoodQuery(_ normalizedQuery: String) -> Bool {
        let words = normalizedQuery.split(separator: " ").map(String.init)
        return words.count <= 2 && words.allSatisfy { $0.allSatisfy(\.isLetter) }
    }

    /// Words that indicate a dessert or processed item. When the user's query
    /// is a plain food word (e.g. "strawberry") these results should rank below
    /// the whole-food match.
    private static let dessertKeywords: Set<String> = [
        "milkshake", "shake", "ice cream", "smoothie", "cake", "pie",
        "cookie", "brownie", "muffin", "donut", "pastry", "candy",
        "frosting", "sundae", "parfait",
    ]

    /// Returns `true` when a normalized food name looks like a dessert or
    /// processed item; used to add a ranking penalty for plain food queries.
    static func isDessertOrProcessed(_ normalizedName: String) -> Bool {
        dessertKeywords.contains(where: { normalizedName.contains($0) })
    }

    /// Returns up to `limit` suggestion terms that match `query`, ranked by
    /// match quality. This is the former SearchView type-ahead behavior as a
    /// pure helper so it can be unit-tested without UI state.
    static func suggestions(for query: String, in suggestionPool: [String], limit: Int = 6) -> [String] {
        let normalized = normalizedQuery(query)
        guard normalized.count >= 1 else { return [] }

        let words = normalized.split(separator: " ").map(String.init)
        let penalizeDesserts = isPlainFoodQuery(normalized)

        // Substring + stem matching (primary)
        var matches = suggestionPool.filter { term in
            matchesAllQueryWords(term: term, normalizedQuery: normalized)
        }

        // Fuzzy fallback: if fewer than 3 substring matches, try edit distance
        // on each word of the food name. Only for queries >= 3 chars to avoid
        // noise on very short inputs.
        if matches.count < 3 && normalized.count >= 3 {
            let fuzzy = suggestionPool.filter { term in
                guard !matches.contains(term) else { return false }
                let nWords = normalizeForSearch(term).split(separator: " ").map(String.init)
                return words.allSatisfy { qw in
                    nWords.contains { nw in
                        // Allow edit distance <= 2, but scale: for short words (<=4 chars) only allow 1
                        let maxDist = qw.count <= 4 ? 1 : 2
                        return editDistance(qw, nw) <= maxDist ||
                               editDistance(stemWord(qw), stemWord(nw)) <= maxDist
                    }
                }
            }
            matches.append(contentsOf: fuzzy)
        }

        return matches
            .sorted { a, b in
                var sa = matchScore(name: a, query: normalized)
                var sb = matchScore(name: b, query: normalized)
                if penalizeDesserts {
                    let na = normalizeForSearch(a)
                    let nb = normalizeForSearch(b)
                    if isDessertOrProcessed(na) { sa += 1 }
                    if isDessertOrProcessed(nb) { sb += 1 }
                }
                if sa != sb { return sa < sb }
                return a.count < b.count
            }
            .prefix(limit)
            .map { $0 }
    }
}
