package app.phonelockdown

object BrowserUrlExtractor {

    /**
     * Pick the first URL-like candidate from the provided texts.
     * `knownIdTexts` come from an exact view-id lookup and are preferred.
     * `fallbackTexts` come from a generic EditText scan.
     * Returns the cleaned candidate, or null if none look URL-like.
     */
    fun pickUrl(
        knownIdTexts: List<CharSequence?>,
        fallbackTexts: List<CharSequence?>
    ): String? {
        for (raw in knownIdTexts) {
            val picked = asUrlCandidate(raw)
            if (picked != null) return picked
        }
        for (raw in fallbackTexts) {
            val picked = asUrlCandidate(raw)
            if (picked != null) return picked
        }
        return null
    }

    private fun asUrlCandidate(raw: CharSequence?): String? {
        val text = raw?.toString()?.trim().orEmpty()
        if (text.isEmpty()) return null
        val domain = DomainMatcher.extractDomain(text) ?: return null
        if (!domain.contains('.')) return null
        return text
    }
}
