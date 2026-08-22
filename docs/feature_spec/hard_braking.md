# Phase 6.3 — Hard Braking & Sudden Stop Detection

Read `AGENTS.md` first.

Implement **Phase 6.3 only**.

Phases 6.1 and 6.2 are complete.

Reuse the existing analytics architecture.

Existing components include:

* `DrivingAnalytics`
* `AnalyzedTrackPoint`
* `SpeedAnalysis`
* `AltitudeAnalysis`
* `TurnAnalysis`
* `TurnEvent`
* `GPSMathUtils`
* `DrivingAnalyticsService`
* `TurnDetector`
* persisted `TrackPoint` data
* Riverpod analytics provider

Do NOT replace the existing architecture.

---

# 1. GOAL

Implement reliable GPS-based detection of:

1. **Hard braking**
2. **Sudden stops**

The implementation must be conservative and resistant to ordinary GPS noise.

This is a GPS-derived driving analytics feature.

Do NOT claim that GPS-only detection is perfectly equivalent to vehicle brake-pedal or accelerometer measurements.

---

# 2. SCOPE

Implement:

* Hard braking detection
* Sudden stop detection
* Event timestamps
* Event locations
* Event starting speed
* Event ending speed
* Deceleration magnitude
* Event duration where meaningful
* Event severity where useful
* Event debouncing/cooldown
* Robust handling of GPS noise
* Unit tests

Do NOT implement:

* Hard acceleration
* Crash detection
* Final analytics UI
* New graphs
* New Trip Stats sections
* Notifications
* Real-time driving alerts
* Navigation
* Database schema changes

UI integration happens later.

---

# 3. ARCHITECTURE

Extend the existing analytics pipeline:

```text
Persisted Track Points
        ↓
DrivingAnalyticsService
        ↓
Speed / Motion Analysis
        ↓
Braking Detector
        ↓
Braking / Stop Analysis
        ↓
DrivingAnalytics
```

Do not create another independent GPS processing pipeline.

Reuse Phase 6.1 GPS calculations.

Do not duplicate:

* Distance calculations
* Time calculations
* Speed conversion
* Acceleration calculations

---

# 4. IMPORTANT: GPS-BASED DETECTION

The existing track points contain GPS speed data, but not a dedicated vehicle braking sensor.

Therefore:

* Prefer persisted `speedKmh` when valid.
* Use track-derived speed when necessary and reliable.
* Use acceleration/deceleration calculated from sequential speed/time data.
* Do not invent acceleration when the time interval is invalid.
* Do not treat one noisy GPS speed sample as definitive evidence of hard braking.

The algorithm should require sufficient evidence across multiple samples when possible.

---

# 5. EVENT MODEL

Create an immutable event model.

For example:

```text
BrakingEvent
 ├── type
 │     ├── hardBraking
 │     └── suddenStop
 ├── timestamp
 ├── latitude
 ├── longitude
 ├── startSpeedKmh
 ├── endSpeedKmh
 ├── decelerationMps2
 ├── duration
 └── severity
```

Use project naming conventions.

Do not add unnecessary fields.

The event model must contain enough information for future Trip Stats UI.

---

# 6. HARD BRAKING DEFINITION

Hard braking means a substantial negative acceleration/deceleration over a meaningful driving interval.

Do NOT use:

```text
speed dropped → hard braking
```

Instead evaluate:

```text
deceleration = change in velocity / change in time
```

A braking candidate should require:

* Vehicle was actually moving
* Starting speed exceeds a minimum speed
* Deceleration is sufficiently strong
* Time interval is valid
* Movement/data quality is sufficient

Use a configurable threshold.

Do not scatter threshold numbers throughout the code.

---

# 7. THRESHOLD

Create a centralized configuration:

```text
BrakingDetectorConfig
```

It should contain configurable values for:

* Hard-braking deceleration threshold
* Sudden-stop starting-speed threshold
* Minimum movement
* Minimum event duration
* Maximum usable time gap
* Event cooldown/reset distance

Do not make these constants inside individual functions.

---

# 8. THRESHOLD CHOICE

Use a conservative initial threshold suitable for GPS-derived data.

Do NOT blindly copy a threshold from an accelerometer-based system.

Published systems use substantially different thresholds depending on vehicle/device/data source; GPS-only and accelerometer-based detection should not be treated as interchangeable.

Document the chosen threshold and why it was selected.

Make it easy to tune later after physical-device testing.

---

# 9. MINIMUM STARTING SPEED

Do not classify a vehicle slowing from walking speed or GPS jitter as hard braking.

A braking candidate must begin above a configurable minimum speed.

For example, a tiny GPS fluctuation around:

```text
0–5 km/h
```

should not produce a braking event.

Use a sensible driving-speed threshold and document it.

---

# 10. SUDDEN STOP

Sudden stop is different from ordinary hard braking.

A sudden stop should represent a meaningful reduction from a moving speed to approximately stationary.

For example:

```text
moving
 ↓
strong deceleration
 ↓
near-zero speed
```

Require:

* Starting speed above the configured minimum
* Ending speed near zero/very low
* Significant speed reduction
* Valid time interval
* Sufficient evidence that the vehicle actually stopped

Do not classify:

```text
0 → 0
1 → 0
2 → 0
```

as sudden stops.

---

# 11. HARD BRAKING VS SUDDEN STOP

A sudden stop may also involve hard braking.

Avoid counting the same physical event twice unless the architecture explicitly distinguishes:

* Hard braking event
* Sudden stop event

The recommended behavior is:

```text
Strong braking that ends near zero
        ↓
One braking event
        +
Sudden-stop classification/flag
```

Do not create duplicate events for the same braking sequence.

If separate event types are retained, ensure the analytics layer can associate them with the same underlying event.

Document the chosen approach.

---

# 12. MULTI-POINT ANALYSIS

Do not rely exclusively on one adjacent pair of GPS points.

A real braking event may span several samples.

Use a local sequence of track points when appropriate.

Conceptually:

```text
speed
  |
  |\
  | \
  |  \
  |   \
  |    \____
  +------------ time
      braking
```

The algorithm should identify the meaningful deceleration period.

Do not let every consecutive pair become a separate braking event.

---

# 13. NOISY GPS SPEED

GPS speed can fluctuate.

Example:

```text
60
58
61
57
52
48
```

Do not automatically interpret every downward fluctuation as braking.

Use:

* Multiple samples
* Minimum deceleration
* Valid time intervals
* Minimum starting speed
* Event confirmation
* Cooldown/reset logic

where appropriate.

Do not over-filter legitimate braking.

---

# 14. TIME INTERVAL

Ignore or safely handle unusable intervals.

Do not calculate acceleration when:

```text
deltaTime <= 0
```

Also avoid using extremely large gaps as if the vehicle continuously decelerated throughout the missing period.

Create a configurable maximum usable time gap.

If the gap is too large:

* Do not use that segment for braking detection.
* Resume analysis after valid data becomes available.

Never produce NaN or Infinity.

---

# 15. SPEED SOURCE

Preferred order:

1. Valid persisted GPS `speedKmh`
2. Derived speed from GPS movement when valid

Do not overwrite the original track point.

Keep raw data unchanged.

The derived analytics layer should decide whether a point is usable.

---

# 16. SPEED UNITS

Use consistent internal units.

Prefer:

```text
speed → m/s
acceleration → m/s²
distance → meters
time → seconds
```

Convert to km/h only for display/model fields that explicitly require km/h.

Do not mix km/h and m/s inside acceleration calculations.

---

# 17. EVENT LOCATION

Each event must have a representative GPS coordinate.

Use the point around the strongest/central part of the braking event.

It does not need centimeter-level precision.

Do not reverse geocode.

Do not use the internet.

---

# 18. EVENT TIMESTAMP

Use the timestamp corresponding to the event's representative/strongest braking point.

Do not use trip start/end timestamps unless appropriate.

---

# 19. EVENT DURATION

Where the data supports it, record the approximate duration of the braking event.

Do not fabricate a duration when the data is insufficient.

---

# 20. SEVERITY

Create a simple severity representation if useful.

For example:

```text
mild
hard
severe
```

However, do NOT overcomplicate the classification.

If severity thresholds are introduced:

* Centralize them
* Document them
* Test them

The initial implementation should prioritize reliable event detection over elaborate severity scoring.

---

# 21. DEBOUNCE / COOLDOWN

A single braking maneuver may contain multiple GPS samples exceeding the threshold.

Do NOT count:

```text
hard braking
hard braking
hard braking
hard braking
```

as four separate events.

Instead:

```text
one braking sequence
        ↓
one event
```

Reset detection after the vehicle:

* stops decelerating strongly
* resumes stable motion
* or travels a sufficient configured distance

Use movement/state-based reset rather than an arbitrary long timer alone.

---

# 22. SEPARATE BRAKING EVENTS

Two real braking events should remain distinguishable.

Example:

```text
60 → 20
normal driving
50 → 0
```

should be capable of producing two events if the track clearly indicates two separate braking sequences.

Do not use an excessively long cooldown that merges them.

---

# 23. STATIONARY GPS NOISE

If the vehicle is stopped and GPS reports:

```text
0
1
0
2
1
```

do not generate braking events.

Similarly:

```text
stationary position jitter
```

must not create braking.

---

# 24. MISSING DATA

Test and handle:

* Empty track
* One point
* Missing speed
* Missing heading
* Missing altitude
* Duplicate timestamps
* Duplicate coordinates
* Invalid numerical values
* Large time gaps
* Very small movement

Never crash.

Never generate NaN/Infinity.

---

# 25. ANALYTICS MODEL

Extend:

```text
DrivingAnalytics
```

with a braking analysis result.

For example:

```text
DrivingAnalytics
 ├── speedAnalysis
 ├── altitudeAnalysis
 ├── turnAnalysis
 └── brakingAnalysis
       ├── events
       ├── hardBrakingCount
       ├── suddenStopCount
       └── ...
```

Avoid duplicate authoritative sources.

If counts can safely be derived from events, prefer derived counts.

---

# 26. RIVERPOD

Update the existing analytics provider only as required.

Do not create unnecessary providers.

The existing analytics provider should return the complete updated `DrivingAnalytics`.

The braking detector itself should remain independent of Riverpod.

---

# 27. DATABASE

Do NOT modify the database schema.

Do not add:

* braking tables
* event tables
* braking columns
* cached analytics columns

Calculate braking analytics from persisted track points.

Future phases can determine whether caching/persistence is worthwhile.

---

# 28. UI

Do NOT modify the Trip Stats UI in Phase 6.3.

Do not add:

* braking cards
* sudden-stop cards
* event lists
* notifications
* new graphs

UI integration happens later.

---

# 29. TEST DATA

Create deterministic synthetic tracks.

Do NOT depend on physical GPS for algorithm correctness.

Minimum required tests:

### Normal driving

```text
60 → 59 → 60 → 58 → 59
```

Expected:

```text
0 hard braking
0 sudden stops
```

### Moderate braking

A realistic moderate reduction below the hard-braking threshold.

Expected:

```text
0 hard braking
```

### Hard braking

Example synthetic sequence with sufficiently strong negative acceleration.

Expected:

```text
1 hard braking
```

### Sudden stop

Example:

```text
60 km/h
→
45
→
25
→
5
→
0
```

Expected:

```text
1 braking event
1 sudden stop
```

according to the selected configuration.

### Multiple braking events

Example:

```text
80
→ hard brake
→ stable driving
→ 60
→ hard brake
→ 0
```

Expected separate events.

### GPS noise

Example:

```text
60
59
61
58
60
57
59
```

Expected:

```text
0 events
```

### Stationary noise

```text
0
1
0
2
1
```

Expected:

```text
0 events
```

### Duplicate timestamps

Must not crash.

### Large time gaps

Must not create false braking events.

### Missing speed

Must safely use derived speed where valid or skip the segment.

### Invalid numeric data

Must not produce NaN/Infinity.

---

# 30. EDGE CASES

Test:

* Exactly threshold acceleration
* Just below threshold
* Just above threshold
* Starting below minimum speed
* Ending near zero
* Zero time delta
* Negative time delta
* Large time gap
* Very small movement
* Long stationary period
* Repeated threshold crossings
* Multiple close braking events

Document whether thresholds are inclusive or exclusive.

---

# 31. PERFORMANCE

Keep the implementation approximately O(n).

A bounded local state/window is acceptable.

Do not perform:

```text
for every point
    scan the entire trip
```

Do not query SQLite repeatedly.

The analytics service should receive the track once.

---

# 32. DEPENDENCIES

Do not add packages.

Use the existing:

* Dart math
* GPS math utilities
* analytics models
* Riverpod architecture

---

# 33. EXISTING FUNCTIONALITY

Do not break:

* Map
* Reckless Mode
* Destination Mode
* Google Maps integration
* Background tracking
* Screen-off tracking
* Trip persistence
* Track-point persistence
* Trips page
* Trip Stats
* Speed graph
* Altitude graph
* Vehicle filtering
* Phase 6.1 analytics
* Phase 6.2 turn analysis

All existing tests must continue passing.

---

# 34. TESTING

After implementation:

1. Run `flutter pub get`.
2. Run braking/sudden-stop tests.
3. Run all tests.
4. Run `flutter analyze`.

All tests must pass.

---

# 35. DOCUMENTATION

Update:

`docs/PROGRESS_TRACKER.md`

Mark Phase 6.3 complete only if:

* Implementation is complete
* Tests pass
* `flutter analyze` passes

Document:

* Hard-braking definition
* Threshold values
* Sudden-stop definition
* Minimum starting speed
* Time-gap handling
* Multi-point strategy
* Debounce/reset strategy
* Event deduplication
* Severity approach
* Known GPS limitations

Do NOT mark Phase 6.4 or 6.5 complete.

---

# 36. FINAL REPORT

When finished, report:

* Files created
* Files modified
* Braking model
* Detection algorithm
* Thresholds
* Sudden-stop definition
* Multi-point strategy
* Debounce strategy
* Event deduplication
* GPS noise handling
* Tests added
* Total tests passed
* `flutter analyze` result
* Dependencies added, if any
* Known limitations

IMPORTANT:

Stop after Phase 6.3.

Do not implement Phase 6.4 or Phase 6.5.
