# CLAUDE.md

## Post-Change Workflow

After making changes:

1. **Push to GitHub** — Always commit and push changes to the GitHub repo after making modifications.
2. **Deploy to Android device** — Check if an Android device is connected (`adb devices`). If a device is connected, build and install the app on it (`cd android && ./gradlew installDebug`).
