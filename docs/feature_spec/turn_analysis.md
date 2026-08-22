# Phase 6.2 — Turn Analysis

Read `AGENTS.md` first.

Implement **Phase 6.2 only**.

Phase 6.1 is complete.

The existing analytics foundation must be reused.

Phase 6.1 already provides:

* `DrivingAnalytics`
* `AnalyzedTrackPoint`
* GPS math utilities
* `DrivingAnalyticsService`
* Riverpod analytics provider
* Persisted GPS track-point access
* Speed/altitude analysis
* Bearing/heading calculations

Do NOT replace the existing analytics architecture.

---

# 1. GOAL

Implement reliable **left-turn and right-turn detection** using the persisted GPS track.

The system must detect meaningful driving turns while minimizing false positives caused by:

* GPS noise
* Small steering corrections
* Gentle road curvature
* Stationary heading changes
* Very small movements
* Duplicate GPS points

The output will eventually be used by the Trip Stats UI.

Do NOT implement the final turn UI in this phase.

---

# 2. SCOPE

Implement:

* Left turn detection
* Right turn detection
* Turn count
* Turn direction
* Turn timestamp
* Turn GPS location
* Turn angle where useful
* Turn detection confidence/quality if useful for the architecture

Do NOT implement:

* Hard braking detection
* Sudden stop detection
* Crash detection
* Final turn bar UI
* New Trip Stats UI
* New graphs
* Navigation
* Routing
* Online services

Those belong to later phases.

---

# 3. ARCHITECTURE

Extend the existing analytics architecture.

Use:

```text
Persisted Track Points
        ↓
DrivingAnalyticsService
        ↓
Turn Analysis
        ↓
Turn events/results
        ↓
DrivingAnalytics
```

Do not create a separate independent GPS-processing pipeline.

Turn detection should reuse the calculations from Phase 6.1.

Do not duplicate:

* Haversine distance
* Bearing calculation
* Time delta
* Speed calculations

Reuse the existing GPS math utilities.

---

# 4. TURN MODEL

Create a dedicated immutable turn model.

It should contain enough information for future UI and analytics.

At minimum:

```text
TurnEvent
 ├── direction
 │     ├── left
 │     └── right
 ├── timestamp
 ├── latitude
 ├── longitude
 └── angle
```

The exact field names should follow existing project conventions.

Consider also including:

* confidence
* entry heading
* exit heading
* vehicle speed at turn

Only add fields that are useful and consistent with the existing architecture.

Do not add unnecessary fields merely for future speculation.

---

# 5. TURN DIRECTION

Use a normalized signed angle difference.

Conceptually:

```text
negative → left
positive → right
```

or the opposite convention if the existing project already establishes one.

The important requirement is that the convention is:

* consistent
* documented
* tested

Handle the 0°/360° boundary correctly.

For example:

```text
355° → 5°
```

must be treated as approximately a **10° change**, not a 350° turn.

Likewise:

```text
5° → 355°
```

must be treated as approximately a **10° change in the opposite direction**.

Do not use raw absolute heading subtraction.

---

# 6. DO NOT DETECT TURNS FROM HEADING ALONE

Heading changes can be noisy.

A heading change by itself must not automatically produce a turn.

Use spatial movement and/or multiple consecutive track points to establish that the vehicle actually changed direction.

The algorithm should consider:

* GPS position
* Bearing between points
* Heading where available
* Distance traveled
* Speed where available
* Consecutive directional changes

Do not classify a turn while the vehicle is stationary.

---

# 7. MINIMUM MOVEMENT

Ignore turn candidates where insufficient physical movement has occurred.

This prevents stationary GPS noise from generating turns.

Use a sensible minimum movement threshold.

The threshold should be centralized as a named constant/configuration value.

Do not scatter magic numbers throughout the code.

The exact value should be chosen based on realistic phone GPS behavior and documented.

---

# 8. TURN ANGLE THRESHOLD

Do not classify every small directional change as a turn.

Introduce a configurable minimum turn-angle threshold.

For example, a small change such as:

```text
5°–10°
```

should normally not count as a turn.

A meaningful road turn such as:

```text
60°
90°
```

should be eligible for classification.

Do not hard-code a simplistic rule such as exactly 90°.

Real roads can have:

* 45° turns
* 60° turns
* 75° turns
* 90° turns
* 120° turns

The threshold should identify a meaningful change while filtering gentle curves.

Centralize the threshold as a named constant.

---

# 9. MULTI-POINT TURN DETECTION

Do not determine the turn angle from only one pair of points when sufficient data is available.

A turn may span several GPS fixes.

Use a local sequence/window of track points to estimate:

```text
incoming direction
        ↓
     turning
        ↓
outgoing direction
```

This is more robust than treating every adjacent pair independently.

The implementation should be able to identify a turn spread across several points.

Do not make the window excessively large because that can merge separate turns.

Choose a reasonable configurable window.

---

# 10. ENTRY AND EXIT BEARING

For a candidate turn:

Calculate an approximate:

* Entry bearing
* Exit bearing

Then calculate the normalized directional change between them.

The turn event's angle should represent the meaningful change in driving direction rather than random GPS jitter.

---

# 11. LEFT / RIGHT CLASSIFICATION

After normalization:

* Classify a sufficiently large negative directional change as one direction.
* Classify a sufficiently large positive directional change as the other.

Use whichever sign convention the project establishes.

Document the convention.

Tests must explicitly verify the mapping.

---

# 12. U-TURNS

Define how U-turns are handled.

A U-turn is not a normal left/right road turn.

For Phase 6.2:

* Do NOT count a U-turn as both a left and a right turn.
* Prefer to classify it separately as `uTurn` if the model architecture supports it.
* If the existing product requirements only support left/right, explicitly exclude U-turns from left/right counts.

Do not allow a U-turn to inflate both turn counts.

Document the chosen behavior.

If introducing `uTurn` to the model, do not display it in the existing left/right UI yet.

---

# 13. GENTLE CURVES

A gradual road curve should normally NOT generate multiple turn events.

For example:

```text
straight
   \
    \
     \
      \
```

must not become:

```text
right
right
right
right
```

Use the multi-point analysis and event cooldown/debouncing described below.

If the road makes one continuous meaningful bend, avoid counting every GPS sample.

---

# 14. TURN DEBOUNCE / COOLDOWN

A single real turn may generate several consecutive GPS points whose bearings remain changed.

Do NOT count each of those points as a separate turn.

After detecting a turn, suppress additional turn events until the vehicle has sufficiently exited the current turning movement.

Use an appropriate reset condition based on:

* Direction becoming stable
* Sufficient distance traveled
* Directional change returning below threshold

Do not use an arbitrary long time delay as the only mechanism.

A turn detector must remain usable for:

* slow traffic
* normal driving
* long drives

---

# 15. SEPARATE CLOSE TURNS

Do not let debouncing merge two legitimate nearby turns.

For example:

```text
LEFT
 ↓
short straight segment
 ↓
RIGHT
```

should be capable of producing:

```text
1 left
1 right
```

if the GPS data clearly supports both movements.

Use movement and directional stability rather than an excessively long cooldown timer.

---

# 16. SPEED REQUIREMENT

If speed data is available:

Use it as supporting evidence.

Do not require speed to be non-null for every point.

If speed is unavailable:

* Continue using GPS movement/bearing.
* Do not automatically discard the entire turn analysis.

If speed is available and indicates the vehicle is stationary, do not generate a turn merely because heading changes.

---

# 17. GPS HEADING

`headingDegrees` is currently nullable.

Do NOT require it.

Preferred approach:

1. Use GPS-derived bearing from coordinates when possible.
2. Use recorded heading when it is valid and useful.
3. Handle missing heading gracefully.

Do not assume the heading field will always exist.

---

# 18. GPS NOISE

The detector must be resistant to ordinary GPS noise.

Test cases should include small coordinate deviations around an otherwise straight path.

Example:

```text
straight path + ±small GPS jitter
```

must not produce random turns.

Do not modify or delete the original track points.

Turn analysis is derived data only.

---

# 19. INVALID DATA

Handle:

* Empty tracks
* One-point tracks
* Duplicate coordinates
* Duplicate timestamps
* Missing speed
* Missing heading
* Missing altitude
* Invalid timestamps
* Very small distances
* Invalid numerical values

The analyzer must never crash.

Do not produce:

* NaN
* Infinity
* invalid coordinates
* invalid timestamps

---

# 20. TURN LOCATION

Each detected turn should have a representative GPS coordinate.

Use the point or interpolated position closest to the center of the turning movement.

It does not need centimeter-level precision.

The important requirement is that the location is close enough for future map visualization.

Do not perform reverse geocoding.

Do not make network requests.

---

# 21. TURN TIMESTAMP

Each detected turn should have a representative timestamp.

Prefer the timestamp corresponding to the center/strongest portion of the turning movement.

Do not use the trip start/end time unless the turn actually occurs there.

---

# 22. ANALYTICS RESULT

Extend the existing `DrivingAnalytics` result with turn analysis.

For example:

```text
DrivingAnalytics
 ├── speedAnalysis
 ├── altitudeAnalysis
 └── turnAnalysis
       ├── turns
       ├── leftTurns
       ├── rightTurns
       └── ...
```

Follow the project's existing model style.

Avoid redundant storage where counts can safely be derived from the turn-event list.

If counts are stored for performance, ensure there is only one authoritative source.

---

# 23. PROVIDER

Update the existing analytics provider only as necessary.

Do not create a separate Riverpod provider just for every individual turn calculation unless there is a demonstrated architectural need.

The existing analytics provider should be able to return the updated `DrivingAnalytics`.

The UI does not need to be changed in this phase.

---

# 24. NO DATABASE CHANGES

Do NOT add database tables or columns in Phase 6.2 unless absolutely necessary.

Turn analysis can initially be calculated from the persisted GPS track.

Do not persist every turn event yet.

Phase 6.4/6.5 can determine whether analytics should be cached or persisted.

---

# 25. TEST DATA

Create deterministic synthetic GPS tracks for unit tests.

Do NOT rely on real GPS/device tests for algorithm correctness.

Tests should represent realistic road movements.

Include at minimum:

### Straight

* Straight road
* Straight road with GPS noise
* Straight road with stationary points

Expected:

```text
0 turns
```

### Left

* Clear left turn

Expected:

```text
1 left
0 right
```

### Right

* Clear right turn

Expected:

```text
0 left
1 right
```

### Multiple turns

Example:

```text
straight
→ left
→ straight
→ right
```

Expected:

```text
1 left
1 right
```

### Small curve

A gentle directional change below the threshold.

Expected:

```text
0 turns
```

### Large curve

A continuous directional change crossing the threshold.

Expected behavior should be documented and tested.

### U-turn

Expected:

* Not counted as both left and right.
* Follow the chosen U-turn policy.

### Noise

GPS jitter without an actual road turn.

Expected:

```text
0 false turns
```

### Missing data

Test:

* Null heading
* Null speed
* Duplicate timestamps
* Duplicate coordinates
* Short tracks

None should crash.

---

# 26. EDGE CASES

Explicitly test heading wraparound:

```text
355° → 5°
```

and:

```text
5° → 355°
```

Also test:

* Exactly threshold angle
* Just below threshold
* Just above threshold
* Very large angle
* Near-180° changes
* U-turn-like movements

Document whether the threshold is inclusive or exclusive.

---

# 27. PERFORMANCE

Turn analysis must remain approximately O(n).

Do not introduce nested full-track scans for every point.

A bounded local window is acceptable.

Do not repeatedly load the same trip track from SQLite.

The analytics service receives the points once.

---

# 28. UI

Do NOT modify the Trips page or Trip Stats page in Phase 6.2.

Do not replace the existing turn placeholder.

Do not add the final left/right bar yet.

That belongs to the later analytics UI integration phase.

---

# 29. DEPENDENCIES

Do not add packages.

Use the existing:

* `latlong2`
* GPS math utilities
* Dart math
* Riverpod architecture

Only add a dependency if there is an unavoidable technical requirement, and explain it before doing so.

---

# 30. EXISTING FUNCTIONALITY

Do not break:

* GPS tracking
* Background tracking
* Reckless Mode
* Destination Mode
* Google Maps launching
* Trip persistence
* Track-point persistence
* Trips page
* Trip Stats
* Speed graph
* Altitude graph
* Vehicle filtering
* Phase 6.1 analytics

All existing tests must continue passing.

---

# 31. TESTING REQUIREMENTS

After implementation:

1. Run `flutter pub get`.
2. Run the new turn-analysis tests.
3. Run the full test suite.
4. Run `flutter analyze`.

All tests must pass.

There must be no analyzer errors or warnings introduced.

---

# 32. DOCUMENTATION

Update:

`docs/PROGRESS_TRACKER.md`

Mark **Phase 6.2** complete only if:

* implementation is complete
* tests pass
* `flutter analyze` passes

Document:

* Turn detection approach
* Turn-angle threshold
* Minimum movement threshold
* Multi-point/window strategy
* Debounce/reset strategy
* U-turn behavior
* Left/right sign convention
* Known limitations

Do NOT mark:

* 6.3
* 6.4
* 6.5

as complete.

---

# 33. FINAL REPORT

When finished, report:

* Files created
* Files modified
* Turn model
* Detection algorithm
* Angle threshold
* Movement threshold
* Window strategy
* Debounce strategy
* U-turn behavior
* GPS noise handling
* Left/right classification
* Tests added
* Total tests passed
* `flutter analyze` result
* Dependencies added, if any
* Known limitations

IMPORTANT:

Stop after Phase 6.2.

Do not implement Phase 6.3, 6.4, or 6.5.
