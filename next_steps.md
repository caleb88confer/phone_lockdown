# Phone Lockdown — Next Steps

## 1. App Blocking Enforcement (Android)

The toggle UI and state persistence work, but no apps are actually blocked yet. This requires native Android work:

### 1a. AccessibilityService
- Register a custom `AccessibilityService` in `AndroidManifest.xml`
- The service listens for `TYPE_WINDOW_STATE_CHANGED` events to detect when a blocked app comes to the foreground
- When a blocked package is detected, overlay a full-screen blocking UI (or redirect to Phone Lockdown)
- User must manually enable this service in Android Settings > Accessibility

### 1b. Usage Stats Permission
- Request `android.permission.PACKAGE_USAGE_STATS` (special permission)
- Required to query which app is currently in the foreground via `UsageStatsManager`
- User must grant this in Android Settings > Special app access

### 1c. Platform Channel
- Create a `MethodChannel` between Flutter and native Kotlin code
- Flutter sends: blocked package list, blocking on/off state
- Kotlin side: starts/stops the AccessibilityService, passes the blocked list to it

### 1d. Overlay / System Alert Window
- Request `SYSTEM_ALERT_WINDOW` permission to draw over other apps
- Display a blocking screen that the user cannot dismiss while blocking is active
- Alternative: use the AccessibilityService to press the Home button when a blocked app opens

## 2. Website Blocking Enforcement

The data model and UI for blocked websites are in place, but enforcement is not yet implemented. Options:

### 2a. Local VPN Approach (Recommended)
- Use Android's `VpnService` API to create a local (on-device) VPN
- Inspect DNS queries and block requests to domains in the blocked list
- No external server needed — all traffic stays on-device
- Packages like `tun2socks` or writing a custom DNS filter on the TUN interface
- User must approve the VPN connection

### 2b. DNS-Based Approach (Alternative)
- Set a custom DNS resolver (e.g., via Private DNS settings) that blocks listed domains
- Less control but simpler to implement
- May require guiding the user through manual DNS configuration

### 2c. Accessibility + Browser Detection (Simpler Fallback)
- Detect when a browser app opens (Chrome, Firefox, etc.) via the AccessibilityService
- Read the URL bar content using accessibility node inspection
- If the URL matches a blocked website, overlay a blocking screen or redirect
- Simpler but only works with known browsers and can break with UI changes

## 3. App Picker (Installed Apps List)

The "Configure Blocked Apps" button in profile editing is a placeholder. Needs:

- A platform channel to call Android `PackageManager.getInstalledApplications()`
- Return list of: package name, app label, icon (as bytes or asset URI)
- Flutter UI: searchable list of installed apps with checkboxes
- Save selected package names to the profile's `blockedAppPackages`

## 4. Tamper Resistance

Without protections, the user can simply uninstall the app or disable the AccessibilityService:

- **Device Admin**: Register as a device administrator to prevent uninstall while active
- **Service monitoring**: Periodically check that the AccessibilityService is still enabled; notify or re-prompt if disabled
- **Pin the blocking overlay**: Use `FLAG_NOT_TOUCH_MODAL` and `FLAG_NOT_FOCUSABLE` carefully so the blocking screen cannot be swiped away

## 5. Polish & UX

- **Onboarding flow**: Guide new users through registering a code and granting permissions
- **Code management**: Show which code is registered (partial preview), allow changing it
- **Notification**: Show a persistent notification while blocking is active
- **Scheduling**: Allow time-based blocking (e.g., block from 9 PM to 7 AM)
- **Widget**: Home screen widget showing current blocking status
