# Changelog

## 0.3.0 — Dot matrix

- Rebuilt home, introduction, permissions, settings and appearance screens around quiet typography and a native dot field.
- Added dense polar dots with inward falloff, a soft outer glow, density/point-size controls and configurable appearance timing.
- Cached Android overlay artwork; animated opacity/translation only. Kept touch-through behaviour and system opacity limits.
- Pinned the visual preview above scrolling controls and kept DEMO accessible at the bottom.
- Added short screen transitions and reduced-motion support throughout the interface.
- Migrated the previous Signal style to Matrix while retaining detector settings.
- Added dot-field geometry/migration tests and small-screen appearance coverage.
- Prepared a public source repository with screenshots, an actual Flutter animation capture and model documentation.

The detector model, CameraX analysis and risk evaluator are unchanged.

## 0.2.0

First-run introduction, configurable semicircle, persistent appearance settings and optional home metrics.

## 0.1.0

Initial Flutter/Kotlin app, camera foreground service, local EfficientDet-Lite0 inference, risk evaluation and native overlay.
