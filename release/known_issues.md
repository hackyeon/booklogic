# Known Issues

## Release Blocker

- Production privacy policy URL is not configured in the app.
- Android release signing is not ready; release currently references debug signing in source configuration.
- Production AdMob App IDs and interstitial ad unit IDs have not been supplied for release validation.

## Known Limitation

- Level 401 and above are intentionally unsupported.
- The app saves level progress, tutorial progress, and settings, but not the in-progress board arrangement.
- Rewarded hint ads are not included in this release.
- BGM is not included in this release.
- Haptic strength and availability may vary by device.
- If an interstitial ad is not loaded or fails to show, the next level proceeds without an ad.

## Follow-up Candidate

- Store-ready custom app icon and launch screen visual review.
- Production privacy policy URL and store data disclosure completion.
- Real-device accessibility and low-performance profile-mode QA.
- Release signing setup through untracked local files or CI secrets.
