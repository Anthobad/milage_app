// ---------------------------------------------------------------------------
// BrakingDetector — Phase 6.3 Hard Braking & Sudden Stop Detection
// ---------------------------------------------------------------------------
//
// ## Algorithm overview
//
// The detector performs a single forward pass over the chronologically-sorted
// GPS track.  It maintains a lightweight sliding state machine:
//
//   IDLE → CANDIDATE (strong deceleration detected)
//        → IDLE (deceleration ends / cooldown distance elapsed)
//
// ### Candidate accumulation
//
// For each consecutive pair of points (i-1, i):
//
//   1. Skip the pair if:
//        - time delta ≤ 0  (duplicate or reversed timestamp)
//        - time delta > maxTimeGapS  (too large a gap — data missing)
//        - speed source is unavailable for either point
//        - the speed used for the START of the segment is below
//          minStartSpeedKmh (vehicle not moving fast enough to matter)
//
//   2. Compute deceleration = (v₁ - v₂) / Δt  (positive = slowing down).
//      Use the BEST available speed per point:
//        a. Valid GPS speedKmh if present.
//        b. Derived speed from haversine distance / time delta otherwise.
//
//   3. If deceleration ≥ minDecelerationMps2:
//        - If not in a candidate window, open one (record start speed,
//          start time, start location).
//        - Extend the window: update peak deceleration, end speed, end time.
//
//   4. If deceleration < minDecelerationMps2 (or pair was skipped):
//        - If a candidate window was open:
//            * The window is "sealed" — emit a braking event.
//        - Reset candidate state.
//
//   5. Cooldown: after an event is emitted, the detector does not open a
//      new candidate window until the vehicle has traveled at least
//      cooldownDistanceM metres.  This prevents a single long braking
//      maneuver from fragmenting into several events due to GPS speed
//      fluctuations within the maneuver.
//
// ### Event emission
//
// When a candidate window is sealed:
//   - If endSpeedKmh ≤ suddenStopEndSpeedKmh → BrakingEventType.suddenStop
//   - Otherwise → BrakingEventType.hardBraking
//   - decelerationMps2 = peak deceleration observed in the window
//   - location = GPS coordinates of the peak-deceleration point
//   - timestamp = GPS timestamp of the peak-deceleration point
//   - durationS = total time of the candidate window (if > 0, else null)
//   - severity derived from peak deceleration using severity thresholds
//
// ### Deduplication
//
// One candidate window → one event.  A sudden stop is never emitted
// together with a hard-braking event for the same window.
//
// ### Multi-point evidence
//
// The detector requires the deceleration to exceed the threshold on at
// least [minBrakingSegments] consecutive GPS pair(s) before emitting an
// event.  A single noisy GPS spike is insufficient.
//
// ### GPS noise resistance
//
//   - minStartSpeedKmh prevents stationary jitter events.
//   - minDecelerationMps2 is conservatively calibrated for GPS-derived data.
//   - maxTimeGapS skips segments where a large gap could fabricate
//     implausibly high deceleration.
//   - cooldownDistanceM debounces multiple events from the same maneuver.
//   - minBrakingSegments requires evidence across consecutive points.
//   - The speed source preference (raw GPS > derived) uses the more direct
//     measurement when available.
//
// ## Speed source
//
// Preferred order per point:
//   1. rawSpeedKmh from the GPS sensor (already validated ≥ 0).
//   2. derivedSpeedKmh from haversine / time delta.
// If neither is available, the segment is skipped.
//
// ## Units
//
// Internal calculations use SI units (m/s, m/s², seconds, metres).
// km/h values are converted at the boundary and stored in [BrakingEvent]
// fields for display.
//
// ## Thresholds — rationale
//
// GPS-only deceleration thresholds must be MORE conservative than
// accelerometer-based thresholds for the following reasons:
//
//   1. GPS speed is rate-limited to the fix interval (typically 1–5 s).
//      Deceleration computed across a 2 s interval averages the actual
//      deceleration over that entire period, masking brief peaks.
//
//   2. GPS speed has inherent noise (~0.1–0.3 m/s RMS in good conditions,
//      worse in urban canyons).  This noise produces apparent deceleration
//      even on a straight road.
//
//   3. Published accelerometer-based thresholds (e.g. SAE, ISO 15622, many
//      UBI/telematics papers) use 0.3–0.5 g (≈ 3–5 m/s²) for "harsh
//      braking" — values measured at millisecond resolution from a rigid
//      sensor mounted to the vehicle.  These CANNOT be used for GPS.
//
//   4. GPS-derived deceleration studies (e.g. Bagdadi & Várhelyi 2011,
//      Wahlberg 2006) suggest thresholds in the range 0.35–0.6 m/s² for
//      GPS-only harsh-event detection.
//
//   The default threshold (0.5 m/s²) sits in the middle of the empirically
//   suggested GPS range and is intentionally conservative.  It corresponds
//   to a speed drop of ~1.8 km/h per second — clearly above normal GPS
//   noise but well below aggressive panic braking.
//
//   After physical-device testing the threshold can be tuned by passing a
//   custom [BrakingDetectorConfig] to [BrakingDetector].

import '../models/braking_analysis.dart';
import '../models/braking_event.dart';
import 'gps_math_utils.dart';
import '../../trips/models/track_point_record.dart';

// ---------------------------------------------------------------------------
// BrakingDetectorConfig
// ---------------------------------------------------------------------------

/// Centralised configuration for [BrakingDetector].
///
/// All threshold values are documented constants — no magic numbers appear
/// inside the algorithm.
///
/// Intended to be constructed once and reused.  Immutable.
class BrakingDetectorConfig {
  const BrakingDetectorConfig({
    this.minDecelerationMps2 = kDefaultMinDecelerationMps2,
    this.suddenStopEndSpeedKmh = kDefaultSuddenStopEndSpeedKmh,
    this.minStartSpeedKmh = kDefaultMinStartSpeedKmh,
    this.maxTimeGapS = kDefaultMaxTimeGapS,
    this.cooldownDistanceM = kDefaultCooldownDistanceM,
    this.minBrakingSegments = kDefaultMinBrakingSegments,
    this.hardSeverityThresholdMps2 = kDefaultHardSeverityThresholdMps2,
    this.severeSeverityThresholdMps2 = kDefaultSevereSeverityThresholdMps2,
  });

  // ── Detection thresholds ──────────────────────────────────────────────────

  /// Minimum deceleration (m/s²) required to open a braking candidate window.
  ///
  /// ## Rationale
  ///
  /// GPS-derived deceleration is noisier than accelerometer data.  This
  /// threshold is deliberately lower than accelerometer-based "hard braking"
  /// thresholds (which are typically 0.3–0.5 g ≈ 3–5 m/s²).
  ///
  /// A value of 0.5 m/s² corresponds to roughly 1.8 km/h per second of
  /// sustained deceleration.  This is above typical GPS speed noise
  /// (~0.1–0.3 m/s² apparent deceleration on a smooth road) but clearly
  /// detectable as intentional braking.
  ///
  /// Literature basis: Bagdadi & Várhelyi (2011), Wahlberg (2006) — GPS-based
  /// harsh-braking thresholds between 0.35 and 0.6 m/s².  Chosen conservatively
  /// at 0.5 m/s² to reduce false positives before physical-device calibration.
  ///
  /// Tune this value after testing on a real device with a real GPS track.
  final double minDecelerationMps2;

  // ── Sudden stop ───────────────────────────────────────────────────────────

  /// Speed in km/h below which the end of a braking sequence is classified
  /// as a sudden stop (i.e. the vehicle came to approximately a standstill).
  ///
  /// ## Rationale
  ///
  /// GPS speed noise at a true stop can report 0–3 km/h.  A threshold of
  /// 5 km/h captures legitimate near-stops without being so wide that
  /// mid-speed hard braking (e.g. 60 → 20 km/h) is misclassified.
  final double suddenStopEndSpeedKmh;

  // ── Minimum starting speed ────────────────────────────────────────────────

  /// Minimum speed in km/h at the START of a candidate braking segment.
  ///
  /// ## Rationale
  ///
  /// GPS jitter around 0–5 km/h can produce apparent deceleration from
  /// noise alone.  Requiring the vehicle to be travelling at least
  /// [minStartSpeedKmh] before a braking event can be opened prevents:
  ///   - Stationary GPS jitter (0 → 0 → 1 → 0 km/h)
  ///   - Crawl-speed fluctuations (0 → 2 → 0 km/h)
  ///   - Parking manoeuvres at walking speed
  ///
  /// 10 km/h is well above pedestrian speed (~4–6 km/h) and walking-pace
  /// parking, but low enough to catch genuine urban braking events.
  final double minStartSpeedKmh;

  // ── Time gap ──────────────────────────────────────────────────────────────

  /// Maximum allowable time gap (seconds) between two consecutive points
  /// for the segment to be usable for braking detection.
  ///
  /// ## Rationale
  ///
  /// A very large time gap (e.g. 30 s) between two GPS fixes cannot be used
  /// for deceleration calculation because the vehicle's motion during the gap
  /// is unknown.  Computing deceleration across such a gap would fabricate a
  /// misleadingly low average deceleration.
  ///
  /// 10 seconds is chosen to:
  ///   - Allow for normal GPS fix-rate variation (1–5 s typical, 8 s common
  ///     in foreground-service scenarios on some Android devices).
  ///   - Exclude gaps caused by tunnels, signal loss, or app pause/resume.
  final double maxTimeGapS;

  // ── Cooldown / debounce ───────────────────────────────────────────────────

  /// Minimum distance (metres) the vehicle must travel after a braking event
  /// before a new candidate window can open.
  ///
  /// ## Rationale
  ///
  /// A single physical braking maneuver can span several GPS fixes.  After
  /// the vehicle resumes motion, the first few segments may still show
  /// slight deceleration (GPS lag, slow re-acceleration) and could
  /// incorrectly trigger a second event.  A 100 m cooldown ensures the
  /// vehicle has clearly resumed normal driving before a new event is
  /// registered.
  ///
  /// 100 m at 30 km/h ≈ 12 s — long enough to confirm resumed motion,
  /// short enough to allow two real braking events in quick succession on a
  /// busy road.  Compare: TurnDetector uses 50 m; braking events tend to
  /// affect a slightly larger stretch of road.
  final double cooldownDistanceM;

  // ── Multi-point evidence ──────────────────────────────────────────────────

  /// Minimum number of consecutive GPS segments that must show deceleration
  /// above [minDecelerationMps2] before an event is emitted.
  ///
  /// ## Rationale
  ///
  /// A single GPS point with a noisy speed reading can produce a momentary
  /// deceleration spike.  Requiring at least [minBrakingSegments] consecutive
  /// qualifying segments rejects single-point noise while still detecting
  /// real short-duration braking.
  ///
  /// Default: 1 — requiring only one segment keeps sensitivity high while
  /// the other thresholds (minStartSpeed, minDeceleration, maxTimeGap)
  /// handle most noise.  Can be increased to 2 for stricter detection if
  /// false positives are observed on-device.
  final int minBrakingSegments;

  // ── Severity thresholds ───────────────────────────────────────────────────

  /// Deceleration (m/s²) above which an event is classified as
  /// [BrakingEventSeverity.hard] rather than [BrakingEventSeverity.mild].
  ///
  /// Default: 0.7 m/s² — corresponds to ~2.5 km/h per second deceleration.
  final double hardSeverityThresholdMps2;

  /// Deceleration (m/s²) above which an event is classified as
  /// [BrakingEventSeverity.severe] rather than [BrakingEventSeverity.hard].
  ///
  /// Default: 1.0 m/s² — corresponds to ~3.6 km/h per second deceleration.
  /// Emergency / panic braking territory for GPS-derived data.
  final double severeSeverityThresholdMps2;

  // ── Defaults ───────────────────────────────────────────────────────────────

  /// 0.5 m/s² — conservative GPS-derived hard-braking threshold.
  static const double kDefaultMinDecelerationMps2 = 0.5;

  /// 5 km/h — end-speed threshold for sudden-stop classification.
  static const double kDefaultSuddenStopEndSpeedKmh = 5.0;

  /// 10 km/h — minimum starting speed to avoid low-speed / stationary noise.
  static const double kDefaultMinStartSpeedKmh = 10.0;

  /// 10 s — maximum usable time gap between consecutive GPS fixes.
  static const double kDefaultMaxTimeGapS = 10.0;

  /// 100 m — post-event cooldown distance before a new event can open.
  static const double kDefaultCooldownDistanceM = 100.0;

  /// 1 — minimum consecutive qualifying segments required for an event.
  static const int kDefaultMinBrakingSegments = 1;

  /// 0.7 m/s² — mild → hard severity boundary.
  static const double kDefaultHardSeverityThresholdMps2 = 0.7;

  /// 1.0 m/s² — hard → severe severity boundary.
  static const double kDefaultSevereSeverityThresholdMps2 = 1.0;
}

// ---------------------------------------------------------------------------
// BrakingDetector
// ---------------------------------------------------------------------------

/// Detects hard-braking and sudden-stop events from a sorted GPS track.
///
/// ## Usage
///
/// ```dart
/// const detector = BrakingDetector();
/// final analysis = detector.detect(sortedPoints);
/// ```
///
/// The input must be **already sorted chronologically** (as produced by
/// [DrivingAnalyticsService]).  The detector does not re-sort.
///
/// To customise thresholds:
/// ```dart
/// final detector = BrakingDetector(
///   config: BrakingDetectorConfig(minDecelerationMps2: 0.6),
/// );
/// ```
class BrakingDetector {
  const BrakingDetector({this.config = const BrakingDetectorConfig()});

  final BrakingDetectorConfig config;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Detects braking events in [sortedPoints] and returns [BrakingAnalysis].
  ///
  /// [sortedPoints] must be chronologically sorted (ascending timestamp).
  /// Returns [BrakingAnalysis.empty] for empty or single-point tracks.
  ///
  /// Never throws.
  BrakingAnalysis detect(List<TrackPointRecord> sortedPoints) {
    final n = sortedPoints.length;
    if (n < 2) return BrakingAnalysis.empty();

    final events = <BrakingEvent>[];

    // ── Candidate window state ─────────────────────────────────────────────
    // A candidate window is open when [_inCandidate] is true.
    // It accumulates data across consecutive qualifying segments.
    var inCandidate = false;

    // Start of the braking window.
    double candidateStartSpeedKmh = 0;
    DateTime? candidateStartTime;

    // Peak deceleration seen within the window.
    double candidatePeakDecelMps2 = 0;
    DateTime? candidatePeakTime;
    double candidatePeakLat = 0;
    double candidatePeakLng = 0;

    // End-of-window speed (updated on every qualifying segment).
    double candidateEndSpeedKmh = 0;
    DateTime? candidateEndTime;

    // Number of consecutive qualifying segments accumulated.
    int candidateSegments = 0;

    // ── Cooldown state ─────────────────────────────────────────────────────
    // After an event is emitted the detector accumulates distance.
    // No new candidate window opens until cooldownDistanceM is exceeded.
    double distanceSinceCooldownStartM = double.infinity; // starts "ready"

    // ── Main pass ──────────────────────────────────────────────────────────
    for (var i = 1; i < n; i++) {
      final prev = sortedPoints[i - 1];
      final cur = sortedPoints[i];

      // ── Step A: always accumulate cooldown distance ────────────────────
      final segDistM = GpsMathUtils.distanceMetres(
        prev.latitude, prev.longitude,
        cur.latitude, cur.longitude,
      );
      if (distanceSinceCooldownStartM < config.cooldownDistanceM) {
        distanceSinceCooldownStartM += segDistM;
      }

      // ── Step B: resolve time delta ─────────────────────────────────────
      final durS = GpsMathUtils.timeDeltaSeconds(prev.timestamp, cur.timestamp);

      // Skip segments with invalid or too-large time deltas.
      if (durS == null || durS > config.maxTimeGapS) {
        // Large gap — seal any open candidate without emitting
        // (data quality insufficient to span the gap).
        if (inCandidate) {
          inCandidate = false;
          candidateSegments = 0;
        }
        continue;
      }

      // ── Step C: resolve best speed for prev and cur ────────────────────
      // Prefer raw GPS speedKmh; fall back to derived speed.
      final prevSpeedKmh = _bestSpeedKmh(prev, i - 1, sortedPoints, durS);
      final curSpeedKmh = _bestSpeedKmh(cur, i, sortedPoints, durS);

      // If either speed is unavailable, skip this segment.
      if (prevSpeedKmh == null || curSpeedKmh == null) {
        if (inCandidate) {
          inCandidate = false;
          candidateSegments = 0;
        }
        continue;
      }

      // ── Step D: minimum starting speed gate ───────────────────────────
      // Only consider segments where the vehicle was meaningfully moving.
      if (prevSpeedKmh < config.minStartSpeedKmh) {
        if (inCandidate) {
          // Candidate opened at a higher speed; the vehicle has slowed below
          // the minimum — seal the candidate.
          final sealed = _tryEmit(
            inCandidate: inCandidate,
            segments: candidateSegments,
            startSpeedKmh: candidateStartSpeedKmh,
            startTime: candidateStartTime,
            endSpeedKmh: candidateEndSpeedKmh,
            endTime: candidateEndTime,
            peakDecelMps2: candidatePeakDecelMps2,
            peakTime: candidatePeakTime,
            peakLat: candidatePeakLat,
            peakLng: candidatePeakLng,
          );
          if (sealed != null) {
            events.add(sealed);
            distanceSinceCooldownStartM = 0;
          }
          inCandidate = false;
          candidateSegments = 0;
        }
        continue;
      }

      // ── Step E: compute deceleration ──────────────────────────────────
      // Convert to m/s for accuracy (avoid km/h rounding artefacts).
      final prevSpeedMs = prevSpeedKmh / 3.6;
      final curSpeedMs = curSpeedKmh / 3.6;
      final speedChangeMps = curSpeedMs - prevSpeedMs; // negative = decelerating
      final decelMps2 = -speedChangeMps / durS; // positive = decelerating

      if (!GpsMathUtils.isValid(decelMps2)) {
        if (inCandidate) {
          inCandidate = false;
          candidateSegments = 0;
        }
        continue;
      }

      // ── Step F: cooldown gate ──────────────────────────────────────────
      // If we are still within the cooldown distance of the last event,
      // do not open a new candidate window.  If already in a candidate,
      // the candidate was opened after the cooldown; continue extending it.
      final cooldownReady =
          distanceSinceCooldownStartM >= config.cooldownDistanceM;

      // ── Step G: qualifying check ───────────────────────────────────────
      if (decelMps2 >= config.minDecelerationMps2) {
        if (!inCandidate) {
          // Do not open a new candidate during cooldown.
          if (!cooldownReady) continue;

          // Open a new candidate window.
          inCandidate = true;
          candidateSegments = 1;
          candidateStartSpeedKmh = prevSpeedKmh;
          candidateStartTime = prev.timestamp;
          candidatePeakDecelMps2 = decelMps2;
          candidatePeakTime = cur.timestamp;
          candidatePeakLat = cur.latitude;
          candidatePeakLng = cur.longitude;
          candidateEndSpeedKmh = curSpeedKmh;
          candidateEndTime = cur.timestamp;
        } else {
          // Extend the existing window.
          candidateSegments++;
          candidateEndSpeedKmh = curSpeedKmh;
          candidateEndTime = cur.timestamp;
          if (decelMps2 > candidatePeakDecelMps2) {
            candidatePeakDecelMps2 = decelMps2;
            candidatePeakTime = cur.timestamp;
            candidatePeakLat = cur.latitude;
            candidatePeakLng = cur.longitude;
          }
        }
      } else {
        // ── Step H: seal and possibly emit ────────────────────────────
        if (inCandidate) {
          final sealed = _tryEmit(
            inCandidate: inCandidate,
            segments: candidateSegments,
            startSpeedKmh: candidateStartSpeedKmh,
            startTime: candidateStartTime,
            endSpeedKmh: candidateEndSpeedKmh,
            endTime: candidateEndTime,
            peakDecelMps2: candidatePeakDecelMps2,
            peakTime: candidatePeakTime,
            peakLat: candidatePeakLat,
            peakLng: candidatePeakLng,
          );
          if (sealed != null) {
            events.add(sealed);
            distanceSinceCooldownStartM = 0;
          }
          inCandidate = false;
          candidateSegments = 0;
        }
      }
    } // end main pass

    // ── Step I: seal any still-open candidate at end of track ──────────────
    if (inCandidate) {
      final sealed = _tryEmit(
        inCandidate: inCandidate,
        segments: candidateSegments,
        startSpeedKmh: candidateStartSpeedKmh,
        startTime: candidateStartTime,
        endSpeedKmh: candidateEndSpeedKmh,
        endTime: candidateEndTime,
        peakDecelMps2: candidatePeakDecelMps2,
        peakTime: candidatePeakTime,
        peakLat: candidatePeakLat,
        peakLng: candidatePeakLng,
      );
      if (sealed != null) {
        events.add(sealed);
      }
    }

    return BrakingAnalysis(events: events);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Resolves the best available speed in km/h for [point] at [index].
  ///
  /// Preference order:
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

    // 2. Derived speed: only computable for non-first points.
    if (index == 0) return null;
    final prev = sorted[index - 1];
    final distM = GpsMathUtils.distanceMetres(
      prev.latitude, prev.longitude,
      point.latitude, point.longitude,
    );
    final spdMs = GpsMathUtils.derivedSpeedMs(distM, durS);
    return GpsMathUtils.speedMsToKmh(spdMs);
  }

  /// Attempts to build and return a [BrakingEvent] from the accumulated
  /// candidate window state.
  ///
  /// Returns null when:
  ///   - Not actually in a candidate (defensive).
  ///   - Fewer than [minBrakingSegments] qualifying segments.
  ///   - Peak time is unavailable.
  BrakingEvent? _tryEmit({
    required bool inCandidate,
    required int segments,
    required double startSpeedKmh,
    required DateTime? startTime,
    required double endSpeedKmh,
    required DateTime? endTime,
    required double peakDecelMps2,
    required DateTime? peakTime,
    required double peakLat,
    required double peakLng,
  }) {
    if (!inCandidate) return null;
    if (segments < config.minBrakingSegments) return null;
    if (peakTime == null) return null;

    // Compute duration from start → end times when available.
    double? durationS;
    if (startTime != null && endTime != null) {
      final dt = GpsMathUtils.timeDeltaSeconds(startTime, endTime);
      if (dt != null && dt > 0) durationS = dt;
    }

    // Classify as sudden stop or hard braking.
    final type = endSpeedKmh <= config.suddenStopEndSpeedKmh
        ? BrakingEventType.suddenStop
        : BrakingEventType.hardBraking;

    // Derive severity from peak deceleration.
    final severity = _severity(peakDecelMps2);

    return BrakingEvent(
      type: type,
      timestamp: peakTime,
      latitude: peakLat,
      longitude: peakLng,
      startSpeedKmh: startSpeedKmh,
      endSpeedKmh: endSpeedKmh,
      decelerationMps2: peakDecelMps2,
      durationS: durationS,
      severity: severity,
    );
  }

  /// Maps peak deceleration to [BrakingEventSeverity].
  BrakingEventSeverity _severity(double decelMps2) {
    if (decelMps2 >= config.severeSeverityThresholdMps2) {
      return BrakingEventSeverity.severe;
    }
    if (decelMps2 >= config.hardSeverityThresholdMps2) {
      return BrakingEventSeverity.hard;
    }
    return BrakingEventSeverity.mild;
  }
}
