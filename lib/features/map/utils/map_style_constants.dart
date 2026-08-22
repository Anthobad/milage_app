// ---------------------------------------------------------------------------
// Map Style Constants — Phase 7.3
// ---------------------------------------------------------------------------
//
// OpenStreetMap tile URL templates for each map appearance mode.
//
// The app uses flutter_map with OSM tile providers (no Google Maps SDK).
// Dark mode uses CartoDB Dark Matter tiles (free, no API key required).
// Light mode uses the standard OSM tiles.
//
// These are local configuration values — no network request is made to
// determine which style to apply.  Selecting a style is 100% offline.
//
// The tile fetch itself requires internet (as it always has), but the
// *selection* of which tile URL to use is local and offline-safe.
//
// DO NOT use TripRank UI colors here.  These tiles use proper Google/OSM
// map geographic styling.

/// Standard OSM tiles — light appearance.
///
/// The original, clean OpenStreetMap rendering with white/cream background.
const String kMapTileUrlLight =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// CartoDB Dark Matter tiles — dark appearance.
///
/// A purpose-built dark map by CartoDB/CARTO with black background and
/// muted colour palette appropriate for dark-mode applications.
/// Free for non-commercial use, no API key required.
const String kMapTileUrlDark =
    'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png';

/// User agent string sent with tile requests.
const String kMapTileUserAgent = 'com.triprank.app';
