# Option E: Accessibility-Service-Only Website Blocking

## Overview

Replace the VPN-based DNS interception with URL monitoring via the existing `LockdownAccessibilityService`. The accessibility service already blocks apps by watching window changes — extend it to also read browser URL bars and block navigation to banned domains.

## Why

The current VPN approach has two fundamental problems:

1. **Slow browsing** — Every DNS query goes through a custom packet handler with per-query thread pool creation, 1500ms timeouts, output lock contention, and excessive byte array copies. Cold-cache page loads can take minutes.
2. **Trivially bypassed** — Android mandates a VPN notification with a one-tap disconnect button. Users can disable blocking in a single tap.

## How It Works

1. Listen for `TYPE_WINDOW_CONTENT_CHANGED` events from known browser packages
2. Traverse the accessibility node tree to find the URL bar node
3. Read the current URL text
4. If it matches a blocked domain via `DomainMatcher`, fire `GLOBAL_ACTION_HOME`

## Scope of Changes

### New / Modified

- **`LockdownAccessibilityService.kt`** — Add `TYPE_WINDOW_CONTENT_CHANGED` handling, URL bar node traversal, browser package detection
- **`accessibility_service_config.xml`** — Add `typeWindowContentChanged` to event types, add browser packages to filter (or monitor all packages)
- **`DomainMatcher.kt`** — No changes needed, reuse existing matching logic

### Removed (VPN subsystem)

- `LockdownVpnService.kt`
- `VpnPacketHandler.kt`
- `DnsPacketParser.kt`
- `DnsCache.kt`
- `VpnController.kt`
- VPN-related method channel calls (`prepareVpn`, `startVpn`, `stopVpn`, `isVpnActive`)
- VPN permission handling in `MainActivity.kt` and `MethodChannelHandler.kt`
- `BlockingStateManager.kt` — Remove VPN auto-start logic
- `AndroidManifest.xml` — Remove `VpnService` declaration and `BIND_VPN_SERVICE` permission
- Dart side — Remove VPN permission checks, VPN start/stop calls in `PlatformChannelService` and `AppBlockerService`

### Browser Package List (Initial)

- `com.android.chrome`
- `org.mozilla.firefox`
- `com.brave.browser`
- `com.opera.browser`
- `com.microsoft.emmx` (Edge)
- `com.samsung.android.app.sbrowser` (Samsung Internet)
- `com.duckduckgo.mobile.browser`

### URL Bar Node Discovery

Each browser has a different accessibility node ID for its URL bar. Strategy:

- Traverse the node tree looking for a focused/clickable `EditText` or node with `viewIdResourceName` containing common patterns (`url_bar`, `url_field`, `search_bar`, `mozac_browser_toolbar_url_view`, etc.)
- Fall back to searching for nodes with text matching URL-like patterns (contains `.com`, `.org`, `https://`, etc.)
- Cache discovered node IDs per package to avoid repeated traversal

## Tradeoffs

| Pro | Con |
|-----|-----|
| Zero network performance overhead | Only blocks known browsers |
| Harder to bypass (Settings > Accessibility) | Doesn't catch in-app webviews (Twitter, Reddit) |
| Lower battery usage | Must maintain browser list + URL node IDs |
| Simpler codebase (~100 LOC vs ~500 LOC) | Browser updates could change node tree structure |
| No VPN permission dialog needed | Slight delay between page load and block (user may see flash of content) |

## Future Hardening (Optional)

- **Accessibility service disable detection (borrowed from Tier 2 parental control apps)** — Detect when the accessibility service gets disabled during an active lock and aggressively re-prompt. The existing `ServiceMonitorWorker` already checks every 15 minutes, but this could be made more frequent or replaced with a lightweight foreground service that detects disablement within seconds and shows a persistent high-priority notification guiding the user to re-enable.
- **Lightweight VPN as second layer** — Add back a streamlined DNS-only VPN (with performance fixes) as a supplementary blocker for webviews and non-browser apps. Accessibility service acts as backstop if VPN is disconnected.
- **Browser app blocking** — If an unknown browser is installed during lockdown, block the entire app via the existing app-blocking mechanism.
