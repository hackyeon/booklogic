# Permission Inventory

## Android Source Manifest

| Permission | Declared In | Direct Or SDK | Reason | User Notice | Status |
| --- | --- | --- | --- | --- | --- |
| `android.permission.INTERNET` | `android/app/src/debug/AndroidManifest.xml`, `android/app/src/profile/AndroidManifest.xml` | Flutter debug/profile tooling | Development hot reload and debugging. | No release user notice. | Debug/profile only in source. |

No dangerous permissions are directly declared in `android/app/src/main/AndroidManifest.xml`.

Google Mobile Ads may add network or advertising-related permissions through the merged release manifest. The merged manifest must be reviewed during release build QA before store submission.

## iOS Info.plist Usage Descriptions

No `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSContactsUsageDescription`, `NSCalendarsUsageDescription`, or `NSUserTrackingUsageDescription` keys are currently declared in `ios/Runner/Info.plist`.

Tracking and App Privacy answers still require manual policy review because Google Mobile Ads and UMP are included.
