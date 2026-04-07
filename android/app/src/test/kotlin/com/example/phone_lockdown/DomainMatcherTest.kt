package com.example.phone_lockdown

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class DomainMatcherTest {

    @Test
    fun `matches exact domain`() {
        val blocked = setOf("youtube.com")
        assertTrue(DomainMatcher.matches("youtube.com", blocked))
    }

    @Test
    fun `matches subdomain`() {
        val blocked = setOf("youtube.com")
        assertTrue(DomainMatcher.matches("m.youtube.com", blocked))
    }

    @Test
    fun `matches deep subdomain`() {
        val blocked = setOf("youtube.com")
        assertTrue(DomainMatcher.matches("a.b.c.youtube.com", blocked))
    }

    @Test
    fun `does not match unrelated domain`() {
        val blocked = setOf("youtube.com")
        assertFalse(DomainMatcher.matches("google.com", blocked))
    }

    @Test
    fun `does not match partial domain name`() {
        val blocked = setOf("tube.com")
        assertFalse(DomainMatcher.matches("youtube.com", blocked))
    }

    @Test
    fun `matches with URL protocol`() {
        val blocked = setOf("youtube.com")
        assertTrue(DomainMatcher.matches("https://youtube.com/watch", blocked))
    }

    @Test
    fun `matches with http protocol`() {
        val blocked = setOf("youtube.com")
        assertTrue(DomainMatcher.matches("http://m.youtube.com/path", blocked))
    }

    @Test
    fun `returns false for empty input`() {
        val blocked = setOf("youtube.com")
        assertFalse(DomainMatcher.matches("", blocked))
    }

    @Test
    fun `returns false for empty blocked set`() {
        assertFalse(DomainMatcher.matches("youtube.com", emptySet()))
    }

    @Test
    fun `extractDomain handles URL with port`() {
        assertEquals("example.com", DomainMatcher.extractDomain("https://example.com:8080/path"))
    }

    @Test
    fun `extractDomain handles URL with query and fragment`() {
        assertEquals("example.com", DomainMatcher.extractDomain("https://example.com/path?q=1#section"))
    }

    @Test
    fun `extractDomain handles bare domain`() {
        assertEquals("example.com", DomainMatcher.extractDomain("example.com"))
    }

    @Test
    fun `extractDomain returns null for empty string`() {
        assertNull(DomainMatcher.extractDomain(""))
    }

    @Test
    fun `extractDomain returns null for whitespace`() {
        assertNull(DomainMatcher.extractDomain("   "))
    }

    @Test
    fun `extractDomain lowercases input`() {
        assertEquals("example.com", DomainMatcher.extractDomain("HTTPS://EXAMPLE.COM"))
    }
}
