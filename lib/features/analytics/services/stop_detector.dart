// ---------------------------------------------------------------------------
// StopDetector — Phase 6.4.1 Stop Detection
// ---------------------------------------------------------------------------
//
// ## Algorithm overview
//
// The detector performs a single forward pass over the chronologically-sorted
// GPS track.  It runs a two-state machine:
//
//   MOVING → STOPPED (speed drops below nearZeroSpeedKmh AND stays there)
//          → MOVING  (speed rises above recoverySpeedKmh or gap is too large)
//
// When the STOPPED state has been maintained for at least
// [minimumStopDurationSeconds] it is considered a real stop.  A single
// StopEvent is emitted for the entire contiguous window — multiple GPS fixes
// during one stop produce exactly ONE event.
//
// ### MOVING → STOPPED transition
//
// A stop candidate opens when:
//   1. The GPS speed (raw or derived) for the current point is ≤
//      [nearZeroSpeedKmh].
//   2. No duplicate timestamp / reversed timestamp (delta ≤ 0 → skip).
//   3. The time gap from the previous point is ≤ [maximumTimeGapSeconds].
//      A large gap cannot confirm the vehicle was continuously stopped.
//
// ### Stop window accumulation
//
// While inside a candidate window each additional point:
//   - Is accepted (window extended) if:
//       * Speed ≤ nearZeroSpeedKmh, or
//       * Speed ≤ recoverySpeedKmh  (hysteresis band), or
//       * Speed > recoverySpeedKmh but position drift < minimumMovementDistanceMeters
//         (GPS position jitter — vehicle not actually moving).
//   - Terminates the window if:
//       * Speed > recoverySpeedKmh AND position drift ≥ minimumMovementDistanceMeters
//         (real movement confirmed).
//       * Time gap exceeds maximumTimeGapSeconds.
//
// ### Stop emission
//
// When the window closes (vehicle moves or track ends):
//   - If accumulated duration ≥ [minimumStopDurationSeconds] → emit StopEvent.
//   - If duration < [minimumStopDurationSeconds] → discard (GPS jitter / brief
//     pause; not a meaningful stop).
//
// ### Hysteresis band
//
// Entry threshold: nearZeroSpeedKmh (default 5 km/h)
// Exit  threshold: recoverySpeedKmh (default 8 km/h)
//
// The band [nearZeroSpeedKmh, recoverySpeedKmh] prevents the detector from
// toggling rapidly when GPS speed oscillates near the threshold.
//
// ### Noise handling
//
//   1. [nearZeroSpeedKmh] = 5 km/h absorbs typical GPS speed noise (~0–3 km/h
//      at a true standstill on Android GPS).
//
//   2. [minimumStopDurationSeconds] = 15 s rejects momentary speed dips.
//
//   3. [minimumMovementDistanceMeters] = 10 m tolerates GPS position drift
//      when the device is stationary (typical drift 5–15 m).
//
//   4. [maximumTimeGapSeconds] = 30 s seals the window when GPS data has a
//      gap, preventing inflated stop durations.
//
// ### Missing speed
//
// When neither raw GPS speed nor derived speed is available for a point:
//   - If a stop window is open: extend the window (conservative — we cannot
//     confirm the vehicle is moving).
//   - If no window is open: skip the point silently.
//
// ### End-of-track handling
//
// If the track ends while the detector is inside a candidate window (vehicle
// still stopped at FINISH), the window is sealed using the accumulated
// duration.  If that duration meets [minimumStopDurationSeconds] the stop is
// emitted.
//
// ### Invalid / unusable segments
//
//   - Duplicate timestamps (delta ≤ 0): carry the current stop state forward.
//   - Reversed timestamps (delta < 0): same.
//   - Large time gaps (> maximumTimeGapSeconds): seal any open window.
//
// ## Performance
//
//   Single forward pass: O(n).
//   No nested loops.
//
// ## Units
//
//   Speed thresholds: km/h (intuitive for configuration)
//   Duration thresholds: seconds
//   Distance thresholds: metres

import '../models/stop_analysis.dart';
import '../models/stop_event.dart';
import 'gps_math_utils.dart';
import '../../trips/models/track_point_record.dart';

// ---------------------------------------------------------------------------
// StopDetectorConfig
// ---------------------------------------------------------------------------

/// Centralised configuration for [StopDetector].
///
/// All threshold values are documented constants — no magic numbers appear
/// inside the algorithm.
///
/// Intended to be constructed once and reused.  Immutable.
class StopDetectorConfig {
  const StopDetectorConfig({
    this.nearZeroSpeedKmh = kDefaultNearZeroSpeedKmh,
    this.minimumStopDurationSeconds = kDefaultMinimumStopDurationSeconds,
    this.minimumMovementDistanceMeters =
        kDefaultMinimumMovementDistanceMeters,
    this.maximumTimeGapSeconds = kDefaultMaximumTimeGapSeconds,
    this.recoverySpeedKmh = kDefaultRecoverySpeedKmh,
  });

  // ── Speed threshold ───────────────────────────────────────────────────────

  /// Maximum speed in km/h that is considered "near-zero" (vehicle stopped
  /// or essentially stopped).
  ///
  /// ## Rationale
  ///
  /// Android GPS speed noise at a true standstill typically reads 0–3 km/h.
  /// Consumer-grade GPS chips report speed with ~0.1–0.5 m/s (~0.4–1.8 km/h)
  /// RMS error in good conditions; worse in urban canyons.  A threshold of
  /// 5 km/h comfortably covers this noise band.
  ///
  /// Slow creep in traffic (5–10 km/h) is intentionally excluded — that is
  /// not a stop.  Use a higher value if you want to count very slow driving as
  /// a stop, but be aware of the false-positive risk.
  ///
  /// Default: 5 km/h (~1.4 m/s).
  final double nearZeroSpeedKmh;

  // ── Duration threshold ────────────────────────────────────────────────────

  /// Minimum time in seconds the vehicle must remain at near-zero speed
  /// before the event is counted as a real stop.
  ///
  /// ## Rationale
  ///
  /// GPS speed can dip below 5 km/h for 1–3 seconds at slow curves,
  /// roundabout entry/exit, or aggressive deceleration during normal driving.
  /// Requiring 15 seconds of continuous near-zero speed ensures only genuine
  /// stops are counted.
  ///
  /// 15 s is long enough to filter traffic calming, roundabouts, and brief
  /// red-light-adjacent glitches, yet short enough to catch a genuine 20-second
  /// stop at traffic lights.  Tune down if users report missed short stops.
  ///
  /// Default: 15 s.
  final double minimumStopDurationSeconds;

  // ── Movement distance threshold ───────────────────────────────────────────

  /// Minimum distance in metres the vehicle must move from the stop origin
  /// for the movement to be treated as genuine (not GPS drift).
  ///
  /// ## Rationale
  ///
  /// GPS position jitter while a phone is stationary can cause apparent
  /// position drift of 5–15 m even when the device is not moving.  When speed
  /// rises above the recovery threshold but the accumulated position drift from
  /// the stop origin is smaller than [minimumMovementDistanceMeters], the
  /// vehicle is still considered stopped.
  ///
  /// 10 m is the typical upper bound of stationary GPS drift; adjust
  /// if needed.
  ///
  /// Default: 10 m.
  final double minimumMovementDistanceMeters;

  // ── Time gap threshold ────────────────────────────────────────────────────

  /// Maximum time gap in seconds between consecutive GPS fixes for the
  /// interval to be considered part of a continuous stop.
  ///
  /// ## Rationale
  ///
  /// A gap of more than 30 seconds between fixes means we have no evidence
  /// about what the vehicle did during that period.  Rather than assume it was
  /// still stopped, we seal any open candidate window and force a fresh
  /// evaluation on the next fix.  This avoids inflating stop durations with
  /// large data holes.
  ///
  /// 30 s is chosen to be:
  ///   - Larger than typical GPS fix intervals (1–5 s normal, up to ~15 s
  ///     during foreground-service GPS in some Android scenarios).
  ///   - Small enough to detect genuine data gaps (tunnels, signal loss,
  ///     app-backgrounded GPS throttling).
  ///
  /// Default: 30 s.
  final double maximumTimeGapSeconds;

  // ── Recovery speed threshold ──────────────────────────────────────────────

  /// Speed in km/h that the vehicle must exceed to unambiguously confirm it
  /// has resumed movement after a stop.
  ///
  /// ## Rationale
  ///
  /// Setting the recovery threshold slightly higher than [nearZeroSpeedKmh]
  /// creates a hysteresis band that prevents a stop from being opened and
  /// closed repeatedly when GPS speed oscillates around the threshold.
  ///
  /// With nearZeroSpeedKmh = 5 and recoverySpeedKmh = 8:
  ///   - Speed must FALL to ≤ 5 km/h to enter the stop state.
  ///   - Speed must RISE to > 8 km/h to exit the stop state.
  ///   - The 3 km/h band absorbs GPS noise oscillations at very low speed.
  ///
  /// Default: 8 km/h.
  final double recoverySpeedKmh;

  // ── Defaults ───────────────────────────────────────────────────────────────

  /// 5 km/h — near-zero speed threshold for stop detection.
  static const double kDefaultNearZeroSpeedKmh = 5.0;

  /// 15 s — minimum duration for a real stop.
  static const double kDefaultMinimumStopDurationSeconds = 15.0;

  /// 10 m — GPS position-drift tolerance while stationary.
  static const double kDefaultMinimumMovementDistanceMeters = 10.0;

  /// 30 s — maximum gap before a stop window is sealed.
  static const double kDefaultMaximumTimeGapSeconds = 30.0;

  /// 8 km/h — speed the vehicle must exceed to confirm resumed movement.
  static const double kDefaultRecoverySpeedKmh = 8.0;
}

// ---------------------------------------------------------------------------
// StopDetector
// ---------------------------------------------------------------------------

/// Detects meaningful stop events from a sorted GPS track.
///
/// ## Usage
///
/// ```dart
/// const detector = StopDetector();
/// final analysis = detector.detect(sortedPoints);
/// ```
///
/// The input must be **already sorted chronologically** (as produced by
/// [DrivingAnalyticsService]).  The detector does not re-sort.
///
/// To customise thresholds:
/// ```dart
/// final detector = StopDetector(
///   config: StopDetectorConfig(minimumStopDurationSeconds: 20),
/// );
/// ```
class StopDetector {
  const StopDetector({this.config = const StopDetectorConfig()});

  final StopDetectorConfig config;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Detects stops in [sortedPoints] and returns [StopAnalysis].
  ///
  /// [sortedPoints] must be chronologically sorted (ascending timestamp).
  /// Returns [StopAnalysis.empty] for empty or single-point tracks.
  ///
  /// Never throws.
  StopAnalysis detect(List<TrackPointRecord> sortedPoints) {
    final n = sortedPoints.length;
    if (n < 2) return StopAnalysis.empty();

    final events = <StopEvent>[];

    // ── Stop window state ──────────────────────────────────────────────────
    var inStop = false;
    var stopStartIndex = 0;
    var stopEndIndex = 0;
    var stopDurationS = 0.0;
    DateTime? stopStartTime;
    double stopStartLat = 0;
    double stopStartLng = 0;

    // ── Main pass ──────────────────────────────────────────────────────────
    for (var i = 1; i < n; i++) {
      final prev = sortedPoints[i - 1];
      final cur = sortedPoints[i];

      // ── Step A: resolve time delta ─────────────────────────────────────
      final durS = GpsMathUtils.timeDeltaSeconds(prev.timestamp, cur.timestamp);

      if (durS == null) {
        // Duplicate or reversed timestamp — skip the interval but do not
        // discard the stop window state.
        continue;
      }

      // ── Step B: large gap handling ─────────────────────────────────────
      if (durS > config.maximumTimeGapSeconds) {
        // Cannot confirm vehicle was still stopped during the gap.
        // Seal any open window using the accumulated duration so far.
        if (inStop) {
          _maybeEmit(
            events: events,
            durationS: stopDurationS,
            startTime: stopStartTime,
            startLat: stopStartLat,
            startLng: stopStartLng,
            startIndex: stopStartIndex,
            endIndex: stopEndIndex,
          );
          inStop = false;
          stopDurationS = 0;
        }
        continue;
      }

      // ── Step C: resolve best speed for current point ───────────────────
      // Prefer raw GPS speedKmh; fall back to derived speed.
      final speedKmh = _bestSpeedKmh(cur, i, sortedPoints, durS);

      if (speedKmh == null) {
        // No speed available — treat as an opaque interval.
        // If already in a stop window, extend it (conservative).
        if (inStop) {
          stopDurationS += durS;
          stopEndIndex = i;
        }
        continue;
      }

      // ── Step D: state machine ──────────────────────────────────────────
      if (!inStop) {
        // ── MOVING: check entry condition ──────────────────────────────
        if (speedKmh <= config.nearZeroSpeedKmh) {
          // Vehicle has dropped to near-zero — open a stop window.
          inStop = true;
          stopStartIndex = i;
          stopEndIndex = i;
          stopStartTime = cur.timestamp;
          stopStartLat = cur.latitude;
          stopStartLng = cur.longitude;
          stopDurationS = 0;
        }
        // else: still clearly moving — nothing to do.
      } else {
        // ── STOPPED: check exit condition ──────────────────────────────

        if (speedKmh > config.recoverySpeedKmh) {
          // Speed above the recovery threshold — check position drift to
          // distinguish real movement from GPS jitter.
          final driftM = GpsMathUtils.distanceMetres(
            stopStartLat, stopStartLng,
            cur.latitude, cur.longitude,
          );

          if (driftM < config.minimumMovementDistanceMeters) {
            // Position change too small — GPS position drift, not movement.
            // Extend the window.
            stopDurationS += durS;
            stopEndIndex = i;
          } else {
            // Real movement confirmed — seal the window.
            _maybeEmit(
              events: events,
              durationS: stopDurationS,
              startTime: stopStartTime,
              startLat: stopStartLat,
              startLng: stopStartLng,
              startIndex: stopStartIndex,
              endIndex: stopEndIndex,
            );
            inStop = false;
            stopDurationS = 0;
          }
        } else {
          // Speed ≤ recoverySpeedKmh (either still ≤ nearZero or in the
          // hysteresis band) — extend the window.
          stopDurationS += durS;
          stopEndIndex = i;
        }
      }
    }

    // ── Step E: end-of-track — seal any still-open window ─────────────────
    if (inStop) {
      _maybeEmit(
        events: events,
        durationS: stopDurationS,
        startTime: stopStartTime,
        startLat: stopStartLat,
        startLng: stopStartLng,
        startIndex: stopStartIndex,
        endIndex: stopEndIndex,
      );
    }

    return StopAnalysis(events: events);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Resolves the best available speed in km/h for [point] at [index].
  ///
  /// Preference:
  ///   1. Raw GPS [speedKmh] from the track point (direct sensor reading).
  ///   2. Derived speed from haversine distance / [durS].
  ///
  /// Returns null when neither is available.
  double? _bestSpeedKmh(
    TrackPointRecord point,
    int index,
    List<TrackPointRecord> sorted,
    double durS,
  ) {
    // 1. Raw GPS speed.
    if (point.speedKmh != null && point.speedKmh! >= 0) {
      return point.speedKmh;
    }

    // 2. Derived speed (only computable for non-first points).
    if (index == 0) return null;
    final prev = sorted[index - 1];
    final distM = GpsMathUtils.distanceMetres(
      prev.latitude, prev.longitude,
      point.latitude, point.longitude,
    );
    final spdMs = GpsMathUtils.derivedSpeedMs(distM, durS);
    return GpsMathUtils.speedMsToKmh(spdMs);
  }

  /// Emits a [StopEvent] to [events] if [durationS] meets the minimum.
  ///
  /// Silently discards:
  ///   - Windows where [startTime] is null (defensive).
  ///   - Windows shorter than [minimumStopDurationSeconds].
  ///   - Windows with non-finite duration.
  void _maybeEmit({
    required List<StopEvent> events,
    required double durationS,
    required DateTime? startTime,
    required double startLat,
    required double startLng,
    required int startIndex,
    required int endIndex,
  }) {
    if (startTime == null) return;
    if (!GpsMathUtils.isValid(durationS)) return;
    if (durationS < config.minimumStopDurationSeconds) return;

    events.add(StopEvent(
      timestamp: startTime,
      latitude: startLat,
      longitude: startLng,
      durationS: durationS,
      startIndex: startIndex,
      endIndex: endIndex,
    ));
  }
}
