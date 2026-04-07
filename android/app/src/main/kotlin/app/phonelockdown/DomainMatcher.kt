package app.phonelockdown

object DomainMatcher {

    /**
     * Checks if a URL text matches any of the blocked domains.
     * Supports subdomain matching: "m.youtube.com" matches blocked domain "youtube.com".
     */
    fun matches(urlText: String, blockedDomains: Set<String>): Boolean {
        val domain = extractDomain(urlText) ?: return false

        for (blocked in blockedDomains) {
            if (domain == blocked || domain.endsWith(".$blocked")) {
                return true
            }
        }
        return false
    }

    /**
     * Extracts the domain from a URL string or bare domain text.
     * Handles: "https://www.example.com/path", "example.com", "www.example.com"
     */
    fun extractDomain(urlText: String): String? {
        val text = urlText.trim().lowercase()
        if (text.isEmpty()) return null

        // Remove protocol if present
        val withoutProtocol = when {
            text.startsWith("https://") -> text.removePrefix("https://")
            text.startsWith("http://") -> text.removePrefix("http://")
            else -> text
        }

        // Take only the host part (before any path, query, or fragment)
        val host = withoutProtocol.split("/").firstOrNull()?.split("?")?.firstOrNull()
            ?.split("#")?.firstOrNull() ?: return null

        // Remove port if present
        val domain = host.split(":").firstOrNull() ?: return null

        return domain.ifEmpty { null }
    }
}
