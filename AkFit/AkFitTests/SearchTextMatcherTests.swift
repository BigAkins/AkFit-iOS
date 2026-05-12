import Testing
@testable import AkFit

struct SearchTextMatcherTests {

    @Test func normalizedQuery_removesApostrophesAndSplitsHyphens() {
        #expect(SearchTextMatcher.normalizedQuery("McDonald's") == "mcdonalds")
        #expect(SearchTextMatcher.normalizedQuery("Dave\u{2019}s Hot-Chicken") == "daves hot chicken")
    }

    @Test func normalizedQuery_handlesRestaurantAliases() {
        #expect(SearchTextMatcher.normalizedQuery("Chick-fil-A") == "chick fil a")
        #expect(SearchTextMatcher.normalizedQuery("chick fil a") == "chick fil a")
        #expect(SearchTextMatcher.normalizedQuery("In-N-Out") == "in n out")
        #expect(SearchTextMatcher.normalizedQuery("innout") == "in n out")
    }

    @Test func stemWord_handlesSimplePlurals() {
        #expect(SearchTextMatcher.stemWord("strawberries") == "strawberry")
        #expect(SearchTextMatcher.stemWord("blueberries") == "blueberry")
        #expect(SearchTextMatcher.stemWord("eggs") == "egg")
        #expect(SearchTextMatcher.stemWord("glass") == "glass")
    }

    @Test func suggestions_matchHyphenatedRestaurantQueries() {
        let pool = [
            "Chicken Breast, cooked",
            "Chick-fil-A Chicken Sandwich",
            "In-N-Out Burger",
        ]

        #expect(SearchTextMatcher.suggestions(for: "chick fil a", in: pool).first == "Chick-fil-A Chicken Sandwich")
        #expect(SearchTextMatcher.suggestions(for: "innout", in: pool).first == "In-N-Out Burger")
        #expect(SearchTextMatcher.suggestions(for: "In-N-Out", in: pool).first == "In-N-Out Burger")
    }

    @Test func suggestions_matchSimplePluralForms() {
        let pool = [
            "Strawberries",
            "Strawberry Milkshake",
            "Blueberries",
        ]

        let matches = SearchTextMatcher.suggestions(for: "strawberry", in: pool)

        #expect(matches.contains("Strawberries"))
        #expect(matches.contains("Strawberry Milkshake"))
    }

    @Test func suggestions_rankWholeFoodBeforeDessertForPlainQuery() {
        let pool = [
            "Strawberry Milkshake",
            "Strawberry",
            "Strawberry Ice Cream",
        ]

        let matches = SearchTextMatcher.suggestions(for: "strawberry", in: pool)

        #expect(matches.first == "Strawberry")
    }

    @Test func suggestions_returnEmptyForObviousNonMatch() {
        let pool = [
            "Chicken Breast, cooked",
            "Greek Yogurt, plain nonfat",
            "In-N-Out Burger",
        ]

        #expect(SearchTextMatcher.suggestions(for: "zzzz", in: pool).isEmpty)
    }
}
