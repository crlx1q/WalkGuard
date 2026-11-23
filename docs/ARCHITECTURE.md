# Architecture

Flutter owns navigation, onboarding and settings. Kotlin owns permissions, service lifetime, camera frames, inference, risk and the system overlay. UI status comes from native events, never from a simulated success state.

## Detection

CameraX uses keep-only-latest analysis, a single executor and one persistent LiteRT CPU interpreter. RGBA frames are cropped, rotated and letterboxed to the model's 320×320 input; boxes are mapped back to the analysed image. Every ImageProxy is closed. The bundled quantised model and labels are verified by hash in the APK checker.

RiskEvaluator applies class/confidence/region thresholds and repeated IoU-matched detections. Critical risk requires repeated growth with stable motion. It does not estimate distance or authorise crossing a road. Four-second haptic cooldown and hide hysteresis limit repeated alerts.

## Service lifetime

A visible Activity and explicit user action are required to start the camera foreground service. It is not sticky. Locking, screen-off, permission loss, camera errors and critical thermal status stop the service. Session generation tokens reject late callbacks after stopping.

## Dot-field rendering

The Matrix design is a deterministic polar grid. Up to 24 inward rows fade by a power curve; angular fading removes hard side endpoints. Dot spacing follows a density setting. Small translucent discs create the outer bloom. A fine segmented edge joins the silhouette without a thick painted arc.

Android builds one transparent bitmap when width or settings change. Risk updates reuse it; the appearance animator changes window-view opacity and a six-dp translation. There is no continuous particle simulation or permanent animation loop. Close releases the bitmap. The transparent overlay stays below Android's touch-obscuring opacity threshold and never takes focus or touches.

Flutter uses the same geometric construction for the labelled preview. A RepaintBoundary isolates it from the rest of the UI. Its settings preview is pinned while controls scroll. Page transitions use a short fade and horizontal movement; system reduced motion and the app switch both disable them.

The first frame of a warning appears inside the dot field. The analyzer crops out model padding, preserves the camera aspect ratio and limits subsequent preview updates to two per second. The UI receives at most one pending analysis update, and frames displayed by the overlay are released through Android's normal bitmap lifecycle.

## Settings compatibility

Existing settings remain intact. The former `SIGNAL` visual maps to `MATRIX`; detector sensitivity, mode and timing do not change during migration. Density and appearance timing have bounded defaults. Version 0.3.1 enables the camera preview for existing installs once on upgrade. Subsequent changes to that setting persist. Restore appearance changes only visual fields.

## Validation

Controller and widget tests cover first launch, persistence, failure recovery, navigation and small screens. Native tests cover risk continuity, lifecycle race protection, settings migration and deterministic dot-field bounds. APK verification checks the bundled model, absence of network permissions and 16-KB native alignment.

Unit tests and Flutter screenshots are not physical-device evidence. The separate device plan covers overlay/cutout placement, real camera use, vibration and OS interruption behaviour.
