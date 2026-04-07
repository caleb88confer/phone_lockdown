# Phase 2: Test Coverage & Data Encryption — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add unit tests for critical blocking/DNS logic and migrate SharedPreferences to encrypted storage.

**Architecture:** Tests are pure unit tests with no Android/device dependencies — Kotlin tests use JUnit 5 on JVM, Dart tests use `flutter_test` with mocked SharedPreferences and platform channels. Encryption is handled by extracting a `PrefsHelper` utility that centralizes `getSharedPreferences` calls, then swapping the implementation to `EncryptedSharedPreferences` with a one-time migration.

**Tech Stack:** JUnit 5, flutter_test, shared_preferences (mock), `androidx.security:security-crypto`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `android/app/src/test/kotlin/com/example/phone_lockdown/DnsPacketParserTest.kt` | Unit tests for DNS packet parsing |
| Create | `android/app/src/test/kotlin/com/example/phone_lockdown/DomainMatcherTest.kt` | Unit tests for domain matching |
| Create | `test/services/profile_manager_test.dart` | Unit tests for ProfileManager |
| Create | `test/services/app_blocker_service_test.dart` | Unit tests for AppBlockerService |
| Create | `android/app/src/main/kotlin/com/example/phone_lockdown/PrefsHelper.kt` | Centralized encrypted SharedPreferences access |
| Modify | `android/app/build.gradle.kts:42-45` | Add security-crypto + JUnit 5 dependencies |
| Modify | `android/app/src/main/kotlin/com/example/phone_lockdown/MainActivity.kt` | Use `PrefsHelper` instead of direct `getSharedPreferences` |
| Modify | `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt:318-321` | Use `PrefsHelper` |
| Modify | `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownAccessibilityService.kt:87-91` | Use `PrefsHelper` |
| Modify | `android/app/src/main/kotlin/com/example/phone_lockdown/FailsafeAlarmReceiver.kt:26` | Use `PrefsHelper` |
| Modify | `android/app/src/main/kotlin/com/example/phone_lockdown/ServiceMonitorWorker.kt:26` | Use `PrefsHelper` |

---

### Task 1: Kotlin Test Infrastructure + DnsPacketParser Tests

**Files:**
- Modify: `android/app/build.gradle.kts:42-45`
- Create: `android/app/src/test/kotlin/com/example/phone_lockdown/DnsPacketParserTest.kt`

- [ ] **Step 1: Add JUnit 5 test dependencies to build.gradle.kts**

In `android/app/build.gradle.kts`, replace the `dependencies` block (lines 42-45):

```kotlin
dependencies {
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.core:core-ktx:1.12.0")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.2")
}
```

Also add `useJUnitPlatform()` inside the `android` block, after `buildTypes`:

```kotlin
    testOptions {
        unitTests.all {
            it.useJUnitPlatform()
        }
    }
```

- [ ] **Step 2: Create DnsPacketParserTest.kt**

Create `android/app/src/test/kotlin/com/example/phone_lockdown/DnsPacketParserTest.kt`:

```kotlin
package com.example.phone_lockdown

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class DnsPacketParserTest {

    /**
     * Builds a minimal valid DNS query packet for a given domain.
     * Format: 12-byte header + QNAME labels + null terminator + QTYPE(A) + QCLASS(IN)
     */
    private fun buildDnsQuery(domain: String, transactionId: Short = 0x1234): ByteArray {
        val labels = domain.split(".")
        // Calculate QNAME size: each label has 1 length byte + label bytes, plus 1 null terminator
        val qnameSize = labels.sumOf { 1 + it.length } + 1
        val packet = ByteArray(12 + qnameSize + 4) // header + QNAME + QTYPE + QCLASS

        // Transaction ID (bytes 0-1)
        packet[0] = (transactionId.toInt() shr 8).toByte()
        packet[1] = (transactionId.toInt() and 0xFF).toByte()

        // Flags: QR=0 (query), RD=1 (byte 2 = 0x01)
        packet[2] = 0x01
        packet[3] = 0x00

        // QDCOUNT = 1
        packet[4] = 0x00
        packet[5] = 0x01

        // ANCOUNT, NSCOUNT, ARCOUNT = 0 (bytes 6-11 already zero)

        // QNAME
        var offset = 12
        for (label in labels) {
            packet[offset++] = label.length.toByte()
            for (ch in label) {
                packet[offset++] = ch.code.toByte()
            }
        }
        packet[offset++] = 0x00 // root label

        // QTYPE = A (1)
        packet[offset++] = 0x00
        packet[offset++] = 0x01

        // QCLASS = IN (1)
        packet[offset++] = 0x00
        packet[offset] = 0x01

        return packet
    }

    @Test
    fun `isQuery returns true for standard query`() {
        val query = buildDnsQuery("example.com")
        assertTrue(DnsPacketParser.isQuery(query))
    }

    @Test
    fun `isQuery returns false for response`() {
        val query = buildDnsQuery("example.com")
        // Set QR bit (bit 7 of byte 2)
        query[2] = (query[2].toInt() or 0x80).toByte()
        assertFalse(DnsPacketParser.isQuery(query))
    }

    @Test
    fun `isQuery returns false for packet shorter than header`() {
        val tooShort = ByteArray(6)
        assertFalse(DnsPacketParser.isQuery(tooShort))
    }

    @Test
    fun `extractDomainFromQuery parses single-level domain`() {
        val query = buildDnsQuery("localhost")
        assertEquals("localhost", DnsPacketParser.extractDomainFromQuery(query))
    }

    @Test
    fun `extractDomainFromQuery parses multi-level domain`() {
        val query = buildDnsQuery("www.example.com")
        assertEquals("www.example.com", DnsPacketParser.extractDomainFromQuery(query))
    }

    @Test
    fun `extractDomainFromQuery returns lowercase`() {
        val query = buildDnsQuery("WWW.Example.COM")
        assertEquals("www.example.com", DnsPacketParser.extractDomainFromQuery(query))
    }

    @Test
    fun `extractDomainFromQuery returns null for response packet`() {
        val query = buildDnsQuery("example.com")
        query[2] = (query[2].toInt() or 0x80).toByte() // set QR bit
        assertNull(DnsPacketParser.extractDomainFromQuery(query))
    }

    @Test
    fun `extractDomainFromQuery returns null for packet too short`() {
        val tooShort = ByteArray(12) // header only, no question section
        assertNull(DnsPacketParser.extractDomainFromQuery(tooShort))
    }

    @Test
    fun `extractDomainFromQuery returns null when qdcount is zero`() {
        val query = buildDnsQuery("example.com")
        query[4] = 0x00
        query[5] = 0x00 // QDCOUNT = 0
        assertNull(DnsPacketParser.extractDomainFromQuery(query))
    }

    @Test
    fun `buildNxdomainResponse sets QR bit and NXDOMAIN rcode`() {
        val query = buildDnsQuery("blocked.com")
        val response = DnsPacketParser.buildNxdomainResponse(query)

        // QR=1, RD=1 -> byte 2 = 0x81
        assertEquals(0x81.toByte(), response[2])
        // RA=1, RCODE=3 -> byte 3 = 0x83
        assertEquals(0x83.toByte(), response[3])
    }

    @Test
    fun `buildNxdomainResponse preserves transaction ID`() {
        val query = buildDnsQuery("blocked.com", transactionId = 0x5678)
        val response = DnsPacketParser.buildNxdomainResponse(query)

        assertEquals(0x56.toByte(), response[0])
        assertEquals(0x78.toByte(), response[1])
    }

    @Test
    fun `buildNxdomainResponse sets QDCOUNT to 1 and answer counts to 0`() {
        val query = buildDnsQuery("blocked.com")
        val response = DnsPacketParser.buildNxdomainResponse(query)

        // QDCOUNT = 1
        assertEquals(0x00.toByte(), response[4])
        assertEquals(0x01.toByte(), response[5])
        // ANCOUNT = 0
        assertEquals(0x00.toByte(), response[6])
        assertEquals(0x00.toByte(), response[7])
        // NSCOUNT = 0
        assertEquals(0x00.toByte(), response[8])
        assertEquals(0x00.toByte(), response[9])
        // ARCOUNT = 0
        assertEquals(0x00.toByte(), response[10])
        assertEquals(0x00.toByte(), response[11])
    }

    @Test
    fun `buildNxdomainResponse returns original packet if too short`() {
        val tooShort = ByteArray(6) { 0x42 }
        val response = DnsPacketParser.buildNxdomainResponse(tooShort)
        assertArrayEquals(tooShort, response)
    }
}
```

- [ ] **Step 3: Run Kotlin tests**

Run:
```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown/android && ./gradlew :app:testDebugUnitTest --tests "com.example.phone_lockdown.DnsPacketParserTest" 2>&1 | tail -10
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown && git add android/app/build.gradle.kts android/app/src/test/kotlin/com/example/phone_lockdown/DnsPacketParserTest.kt && git commit -m "test: add unit tests for DnsPacketParser

Tests cover isQuery(), extractDomainFromQuery(), and buildNxdomainResponse()
including edge cases for malformed packets, response packets, and short input."
```

---

### Task 2: DomainMatcher Tests

**Files:**
- Create: `android/app/src/test/kotlin/com/example/phone_lockdown/DomainMatcherTest.kt`

- [ ] **Step 1: Create DomainMatcherTest.kt**

Create `android/app/src/test/kotlin/com/example/phone_lockdown/DomainMatcherTest.kt`:

```kotlin
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
```

- [ ] **Step 2: Run Kotlin tests**

Run:
```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown/android && ./gradlew :app:testDebugUnitTest --tests "com.example.phone_lockdown.DomainMatcherTest" 2>&1 | tail -10
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown && git add android/app/src/test/kotlin/com/example/phone_lockdown/DomainMatcherTest.kt && git commit -m "test: add unit tests for DomainMatcher

Tests cover exact match, subdomain match, URL parsing with protocols/ports/
query strings, empty input, and case insensitivity."
```

---

### Task 3: Dart Unit Tests for ProfileManager

**Files:**
- Create: `test/services/profile_manager_test.dart`

- [ ] **Step 1: Create profile_manager_test.dart**

Create `test/services/profile_manager_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_lockdown/models/profile.dart';
import 'package:phone_lockdown/services/profile_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Profile JSON round-trip', () {
    test('encodeList and decodeList are inverses', () {
      final profiles = [
        Profile(
          id: 'test-id-1',
          name: 'Work',
          blockedAppPackages: ['com.twitter.android'],
          blockedWebsites: ['twitter.com'],
          unlockCode: 'abc123',
          failsafeMinutes: 60,
        ),
        Profile(
          id: 'test-id-2',
          name: 'Study',
          blockedAppPackages: ['com.instagram.android', 'com.reddit.frontpage'],
          blockedWebsites: ['instagram.com', 'reddit.com'],
          failsafeMinutes: 120,
        ),
      ];

      final encoded = Profile.encodeList(profiles);
      final decoded = Profile.decodeList(encoded);

      expect(decoded.length, 2);
      expect(decoded[0].id, 'test-id-1');
      expect(decoded[0].name, 'Work');
      expect(decoded[0].blockedAppPackages, ['com.twitter.android']);
      expect(decoded[0].blockedWebsites, ['twitter.com']);
      expect(decoded[0].unlockCode, 'abc123');
      expect(decoded[0].failsafeMinutes, 60);
      expect(decoded[1].id, 'test-id-2');
      expect(decoded[1].name, 'Study');
      expect(decoded[1].blockedAppPackages, ['com.instagram.android', 'com.reddit.frontpage']);
      expect(decoded[1].unlockCode, isNull);
    });

    test('Profile.fromJson uses default failsafeMinutes when missing', () {
      final json = {
        'id': 'test-id',
        'name': 'Test',
        'iconCodePoint': 0xe7f5,
        'blockedAppPackages': <String>[],
        'blockedWebsites': <String>[],
      };
      final profile = Profile.fromJson(json);
      expect(profile.failsafeMinutes, 1440);
    });
  });

  group('ProfileManager CRUD', () {
    test('starts with default profile', () async {
      final manager = ProfileManager();
      // Allow async _init() to complete
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(manager.profiles.length, 1);
      expect(manager.profiles.first.name, 'Default');
      expect(manager.currentProfileId, isNotNull);
    });

    test('addProfile creates new profile and sets it current', () async {
      final manager = ProfileManager();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      manager.addProfile(name: 'Work');

      expect(manager.profiles.length, 2);
      expect(manager.profiles.last.name, 'Work');
      expect(manager.currentProfileId, manager.profiles.last.id);
    });

    test('deleteProfile removes profile and falls back to first', () async {
      final manager = ProfileManager();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      manager.addProfile(name: 'Work');
      final workId = manager.profiles.last.id;

      manager.deleteProfile(workId);

      expect(manager.profiles.length, 1);
      expect(manager.profiles.first.name, 'Default');
    });

    test('deleteProfile ensures default profile always exists', () async {
      final manager = ProfileManager();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final defaultId = manager.profiles.first.id;
      manager.deleteProfile(defaultId);

      // Should recreate a default profile
      expect(manager.profiles.length, 1);
      expect(manager.profiles.first.name, 'Default');
    });

    test('updateProfile modifies fields', () async {
      final manager = ProfileManager();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final id = manager.profiles.first.id;
      manager.updateProfile(
        id: id,
        name: 'Updated',
        blockedAppPackages: ['com.test.app'],
        blockedWebsites: ['test.com'],
        failsafeMinutes: 30,
      );

      final updated = manager.profiles.first;
      expect(updated.name, 'Updated');
      expect(updated.blockedAppPackages, ['com.test.app']);
      expect(updated.blockedWebsites, ['test.com']);
      expect(updated.failsafeMinutes, 30);
    });

    test('findProfileByCode returns matching profile', () async {
      final manager = ProfileManager();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final id = manager.profiles.first.id;
      manager.updateProfile(id: id, unlockCode: 'secret-code');

      final found = manager.findProfileByCode('secret-code');
      expect(found, isNotNull);
      expect(found!.id, id);
    });

    test('findProfileByCode returns null for non-existent code', () async {
      final manager = ProfileManager();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(manager.findProfileByCode('non-existent'), isNull);
    });
  });

  group('ProfileManager legacy migration', () {
    test('migrates savedCodeValue to default profile unlockCode', () async {
      SharedPreferences.setMockInitialValues({
        'savedCodeValue': 'legacy-code-123',
      });

      final manager = ProfileManager();
      // Allow _init() + _migrateLegacyCode() to complete
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(manager.profiles.first.unlockCode, 'legacy-code-123');

      // Verify legacy key was removed
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('savedCodeValue'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run Dart tests**

Run:
```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter test test/services/profile_manager_test.dart 2>&1 | tail -15
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown && git add test/services/profile_manager_test.dart && git commit -m "test: add unit tests for ProfileManager

Tests cover JSON round-trip, CRUD operations, default profile enforcement,
profile lookup by unlock code, and legacy code migration."
```

---

### Task 4: Dart Unit Tests for AppBlockerService

**Files:**
- Create: `test/services/app_blocker_service_test.dart`

- [ ] **Step 1: Create app_blocker_service_test.dart**

Create `test/services/app_blocker_service_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_lockdown/models/profile.dart';
import 'package:phone_lockdown/services/app_blocker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Mock the platform channel to prevent MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.phone_lockdown/blocker'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'checkPermissions':
            return {
              'accessibility': true,
              'deviceAdmin': true,
              'vpn': true,
            };
          case 'updateBlockingState':
            return null;
          case 'scheduleFailsafeAlarm':
            return null;
          case 'cancelFailsafeAlarm':
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.phone_lockdown/blocker'),
      null,
    );
  });

  List<Profile> makeProfiles() {
    return [
      Profile(
        id: 'profile-1',
        name: 'Work',
        blockedAppPackages: ['com.twitter.android'],
        blockedWebsites: ['twitter.com'],
        failsafeMinutes: 60,
      ),
      Profile(
        id: 'profile-2',
        name: 'Study',
        blockedAppPackages: ['com.instagram.android'],
        blockedWebsites: ['instagram.com'],
        failsafeMinutes: 120,
      ),
    ];
  }

  group('ActiveLock', () {
    test('toJson and fromJson are inverses', () {
      final lock = ActiveLock(
        profileId: 'test-id',
        lockStartTime: DateTime(2026, 1, 15, 10, 30),
        failsafeMinutes: 60,
      );

      final json = lock.toJson();
      final restored = ActiveLock.fromJson(json);

      expect(restored.profileId, 'test-id');
      expect(restored.lockStartTime, DateTime(2026, 1, 15, 10, 30));
      expect(restored.failsafeMinutes, 60);
    });

    test('isExpired returns true when time has passed', () {
      final lock = ActiveLock(
        profileId: 'test-id',
        lockStartTime: DateTime.now().subtract(const Duration(hours: 2)),
        failsafeMinutes: 60, // expired 1 hour ago
      );

      expect(lock.isExpired, isTrue);
      expect(lock.remaining, Duration.zero);
    });

    test('isExpired returns false when time remains', () {
      final lock = ActiveLock(
        profileId: 'test-id',
        lockStartTime: DateTime.now(),
        failsafeMinutes: 60,
      );

      expect(lock.isExpired, isFalse);
      expect(lock.remaining.inMinutes, greaterThan(0));
    });
  });

  group('AppBlockerService activation', () {
    test('activateProfile adds lock and reports blocking', () async {
      final service = AppBlockerService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      final result = await service.activateProfile(
        profiles[0],
        allProfiles: profiles,
      );

      expect(result, isTrue);
      expect(service.isBlocking, isTrue);
      expect(service.activeProfileIds, contains('profile-1'));
    });

    test('deactivateProfile removes lock', () async {
      final service = AppBlockerService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      await service.activateProfile(profiles[0], allProfiles: profiles);
      final result = await service.deactivateProfile(
        'profile-1',
        allProfiles: profiles,
      );

      expect(result, isTrue);
      expect(service.isBlocking, isFalse);
      expect(service.activeProfileIds, isEmpty);
    });

    test('multiple profiles stack — blocking continues until all deactivated', () async {
      final service = AppBlockerService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      await service.activateProfile(profiles[0], allProfiles: profiles);
      await service.activateProfile(profiles[1], allProfiles: profiles);

      expect(service.activeProfileIds.length, 2);

      await service.deactivateProfile('profile-1', allProfiles: profiles);
      expect(service.isBlocking, isTrue); // still blocking from profile-2

      await service.deactivateProfile('profile-2', allProfiles: profiles);
      expect(service.isBlocking, isFalse);
    });

    test('deactivateProfile returns false for non-existent profile', () async {
      final service = AppBlockerService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      final result = await service.deactivateProfile(
        'non-existent',
        allProfiles: profiles,
      );

      expect(result, isFalse);
    });
  });

  group('AppBlockerService persistence', () {
    test('saves and restores active locks across instances', () async {
      final service1 = AppBlockerService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      await service1.activateProfile(profiles[0], allProfiles: profiles);

      // Create second instance — should load saved state
      final service2 = AppBlockerService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(service2.isBlocking, isTrue);
      expect(service2.activeProfileIds, contains('profile-1'));
    });

    test('restoreTimers removes expired locks', () async {
      // Set up an already-expired lock in SharedPreferences
      final expiredLock = ActiveLock(
        profileId: 'expired-profile',
        lockStartTime: DateTime.now().subtract(const Duration(hours: 48)),
        failsafeMinutes: 60,
      );
      SharedPreferences.setMockInitialValues({
        'activeLocks': jsonEncode([expiredLock.toJson()]),
      });

      final service = AppBlockerService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // The expired lock should have been filtered out during _loadBlockingState
      expect(service.isBlocking, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run Dart tests**

Run:
```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter test test/services/app_blocker_service_test.dart 2>&1 | tail -15
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown && git add test/services/app_blocker_service_test.dart && git commit -m "test: add unit tests for AppBlockerService

Tests cover ActiveLock serialization and expiry, profile activation/
deactivation, stacking multiple profiles, persistence across instances,
and expired lock cleanup on restore."
```

---

### Task 5: Create PrefsHelper for Centralized Encrypted SharedPreferences

**Files:**
- Modify: `android/app/build.gradle.kts:42-45`
- Create: `android/app/src/main/kotlin/com/example/phone_lockdown/PrefsHelper.kt`

- [ ] **Step 1: Add security-crypto dependency**

In `android/app/build.gradle.kts`, add to the `dependencies` block:

```kotlin
dependencies {
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.2")
}
```

- [ ] **Step 2: Create PrefsHelper.kt**

Create `android/app/src/main/kotlin/com/example/phone_lockdown/PrefsHelper.kt`:

```kotlin
package com.example.phone_lockdown

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Centralized access to encrypted SharedPreferences.
 * On first use after upgrade, migrates existing plain-text prefs to encrypted storage.
 */
object PrefsHelper {

    private const val TAG = "PrefsHelper"
    private const val PLAIN_PREFS_NAME = "lockdown_prefs"
    private const val ENCRYPTED_PREFS_NAME = "lockdown_prefs_encrypted"
    private const val MIGRATION_KEY = "prefsMigrated"

    @Volatile
    private var cachedPrefs: SharedPreferences? = null

    fun getPrefs(context: Context): SharedPreferences {
        cachedPrefs?.let { return it }

        synchronized(this) {
            cachedPrefs?.let { return it }

            val appContext = context.applicationContext
            val masterKey = MasterKey.Builder(appContext)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            val encryptedPrefs = EncryptedSharedPreferences.create(
                appContext,
                ENCRYPTED_PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )

            if (!encryptedPrefs.getBoolean(MIGRATION_KEY, false)) {
                migrateFromPlainPrefs(appContext, encryptedPrefs)
            }

            cachedPrefs = encryptedPrefs
            return encryptedPrefs
        }
    }

    private fun migrateFromPlainPrefs(context: Context, encryptedPrefs: SharedPreferences) {
        val plainPrefs = context.getSharedPreferences(PLAIN_PREFS_NAME, Context.MODE_PRIVATE)
        val allEntries = plainPrefs.all

        if (allEntries.isEmpty()) {
            encryptedPrefs.edit().putBoolean(MIGRATION_KEY, true).apply()
            return
        }

        Log.i(TAG, "Migrating ${allEntries.size} entries from plain to encrypted prefs")

        val editor = encryptedPrefs.edit()
        for ((key, value) in allEntries) {
            when (value) {
                is Boolean -> editor.putBoolean(key, value)
                is String -> editor.putString(key, value)
                is Int -> editor.putInt(key, value)
                is Long -> editor.putLong(key, value)
                is Float -> editor.putFloat(key, value)
                is Set<*> -> {
                    @Suppress("UNCHECKED_CAST")
                    editor.putStringSet(key, value as Set<String>)
                }
            }
        }
        editor.putBoolean(MIGRATION_KEY, true)
        editor.apply()

        // Delete plain-text prefs file
        plainPrefs.edit().clear().apply()
        Log.i(TAG, "Migration complete, plain prefs cleared")
    }
}
```

- [ ] **Step 3: Verify build**

Run:
```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown/android && ./gradlew assembleDebug 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 4: Commit**

```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown && git add android/app/build.gradle.kts android/app/src/main/kotlin/com/example/phone_lockdown/PrefsHelper.kt && git commit -m "feat: add PrefsHelper with EncryptedSharedPreferences and migration

Centralizes SharedPreferences access through encrypted storage. On first
use after upgrade, migrates all plain-text prefs to AES-256 encrypted
storage and clears the old file."
```

---

### Task 6: Migrate All Kotlin Files to Use PrefsHelper

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/MainActivity.kt:129,189,228`
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt:318-321`
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownAccessibilityService.kt:87-91`
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/FailsafeAlarmReceiver.kt:26`
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/ServiceMonitorWorker.kt:26`

- [ ] **Step 1: Update MainActivity.kt**

Replace all three occurrences of `getSharedPreferences("lockdown_prefs", Context.MODE_PRIVATE)` with `PrefsHelper.getPrefs(this)`:

Line 129 in `updateBlockingState()`:
```kotlin
        val prefs = PrefsHelper.getPrefs(this)
```

Line 189 in `scheduleFailsafeAlarm()`:
```kotlin
        val prefs = PrefsHelper.getPrefs(this)
```

Line 228 in `cancelFailsafeAlarm()`:
```kotlin
        val prefs = PrefsHelper.getPrefs(this)
```

- [ ] **Step 2: Update LockdownVpnService.kt**

Replace line 319 in `loadStateFromPrefs()`:

```kotlin
    private fun loadStateFromPrefs() {
        val prefs = PrefsHelper.getPrefs(this)
        blockedWebsites = prefs.getStringSet("blockedWebsites", emptySet()) ?: emptySet()
    }
```

- [ ] **Step 3: Update LockdownAccessibilityService.kt**

Replace line 88 in `loadStateFromPrefs()`:

```kotlin
    private fun loadStateFromPrefs() {
        val prefs = PrefsHelper.getPrefs(this)
        setBlockingActiveSilently(prefs.getBoolean("isBlocking", false))
        blockedPackages = prefs.getStringSet("blockedPackages", emptySet()) ?: emptySet()
        blockedWebsites = prefs.getStringSet("blockedWebsites", emptySet()) ?: emptySet()
    }
```

- [ ] **Step 4: Update FailsafeAlarmReceiver.kt**

Replace line 26 in `deactivateProfile()`:

```kotlin
            val prefs = PrefsHelper.getPrefs(context)
```

- [ ] **Step 5: Update ServiceMonitorWorker.kt**

Replace line 26 in `doWork()`:

```kotlin
        val prefs = PrefsHelper.getPrefs(applicationContext)
```

- [ ] **Step 6: Verify build**

Run:
```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown/android && ./gradlew assembleDebug 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 7: Run existing Kotlin tests**

Run:
```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown/android && ./gradlew :app:testDebugUnitTest 2>&1 | tail -10
```

Expected: All tests still pass (test code doesn't use SharedPreferences directly).

- [ ] **Step 8: Commit**

```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown && git add android/app/src/main/kotlin/com/example/phone_lockdown/MainActivity.kt android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt android/app/src/main/kotlin/com/example/phone_lockdown/LockdownAccessibilityService.kt android/app/src/main/kotlin/com/example/phone_lockdown/FailsafeAlarmReceiver.kt android/app/src/main/kotlin/com/example/phone_lockdown/ServiceMonitorWorker.kt && git commit -m "refactor: migrate all SharedPreferences usage to PrefsHelper

All 5 Kotlin files that accessed lockdown_prefs now go through
PrefsHelper.getPrefs(), which returns EncryptedSharedPreferences.
Existing plain-text data is automatically migrated on first access."
```

---

### Task 7: Deploy and Push

- [ ] **Step 1: Run all tests**

```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter test 2>&1 | tail -10
cd /Users/calebconfer/Desktop/Projects/phone_lockdown/android && ./gradlew :app:testDebugUnitTest 2>&1 | tail -10
```

Expected: All tests pass.

- [ ] **Step 2: Build and install on connected device (if available)**

```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown/android && ./gradlew installDebug 2>&1 | tail -5
```

- [ ] **Step 3: Push to GitHub**

```bash
cd /Users/calebconfer/Desktop/Projects/phone_lockdown && git push
```
