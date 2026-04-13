package app.phonelockdown

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class BrowserUrlExtractorTest {

    @Test
    fun `picks known-id text over fallback`() {
        val picked = BrowserUrlExtractor.pickUrl(
            knownIdTexts = listOf("youtube.com"),
            fallbackTexts = listOf("other.com"),
        )
        assertEquals("youtube.com", picked)
    }

    @Test
    fun `falls back to EditText text when known-id empty`() {
        val picked = BrowserUrlExtractor.pickUrl(
            knownIdTexts = emptyList(),
            fallbackTexts = listOf("https://example.com/search"),
        )
        assertEquals("https://example.com/search", picked)
    }

    @Test
    fun `returns null when no candidates look like URLs`() {
        val picked = BrowserUrlExtractor.pickUrl(
            knownIdTexts = listOf("Search or type URL"),
            fallbackTexts = listOf("Some page heading"),
        )
        assertNull(picked)
    }

    @Test
    fun `skips empty and whitespace candidates`() {
        val picked = BrowserUrlExtractor.pickUrl(
            knownIdTexts = listOf("", "   ", null),
            fallbackTexts = listOf("youtube.com"),
        )
        assertEquals("youtube.com", picked)
    }

    @Test
    fun `trims candidate whitespace`() {
        val picked = BrowserUrlExtractor.pickUrl(
            knownIdTexts = listOf("  https://youtube.com/watch  "),
            fallbackTexts = emptyList(),
        )
        assertEquals("https://youtube.com/watch", picked)
    }

    @Test
    fun `requires a dot in the extracted domain`() {
        val picked = BrowserUrlExtractor.pickUrl(
            knownIdTexts = listOf("localhost"),
            fallbackTexts = listOf("news.ycombinator.com"),
        )
        assertEquals("news.ycombinator.com", picked)
    }

    @Test
    fun `returns null when everything is null or empty`() {
        val picked = BrowserUrlExtractor.pickUrl(
            knownIdTexts = listOf(null),
            fallbackTexts = listOf(null, ""),
        )
        assertNull(picked)
    }

    @Test
    fun `prefers first URL-like known-id text even if later ones look cleaner`() {
        val picked = BrowserUrlExtractor.pickUrl(
            knownIdTexts = listOf("m.youtube.com/watch", "youtube.com"),
            fallbackTexts = emptyList(),
        )
        assertEquals("m.youtube.com/watch", picked)
    }
}
