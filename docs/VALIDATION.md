# Validation for 0.3.0

Local build host: Linux ARM64, Flutter 3.50.0, Dart 3.14.0, Java 21, Android SDK 36. Android x64 build tools ran through QEMU. This is a build environment, not an Android device.

| Check | Result |
| --- | --- |
| Flutter analysis | No issues |
| Flutter controller/widget tests | 18 passed |
| Kotlin tests | 24 passed |
| Android lint | 0 errors, 18 warnings |
| APK signature | Valid; same development certificate as 0.2 |
| Bundled model | SHA-256 matched; uncompressed asset |
| Network permissions | No INTERNET or network-state permission |
| Native libraries | ELF and ZIP alignment at least 16 KB |

The remaining lint warnings concern dependency/target SDK versions, resource qualifiers, backup rules and Kotlin convenience APIs. Lint checks were not disabled.

The screenshots and animation in the README were captured from the actual Flutter screens with bundled fonts. Golden screenshots were produced on Linux ARM64; font rasterisation on other host architectures may differ. Widget interactions, failure recovery and 320-pixel layouts at 1.4 text scale were tested.

The model previously executed on a real host image using LiteRT. That is a model smoke test, not an Android benchmark. The model, camera analysis and risk evaluator did not change in this version.

Physical camera use, overlays above third-party applications, cutouts/rotation, battery cost and haptics must still be checked on a phone. See [DEVICE_TEST_PLAN.md](DEVICE_TEST_PLAN.md).
