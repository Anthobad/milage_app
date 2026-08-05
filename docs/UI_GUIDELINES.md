# TripRank UI Guidelines

## Design Philosophy

TripRank follows a functional navigation-focused design inspired by Google Maps.

The interface should prioritize:
- Clarity
- Simplicity
- Easy interaction while driving
- Minimal distractions

The map is the main visual element.

---

# Theme

## App Theme

Default:
- Dark mode

Users can change:

- Dark
- Light
- System

The app theme is independent from the map theme.

---

## Map Theme

The map has its own setting:

- Google Maps Light
- Google Maps Dark

The user can combine any app theme with any map theme.

Example:

App:
Dark

Map:
Light

---

# Colors

## Primary Accent

Blue

Used for:
- Primary actions
- Selected navigation items
- Active controls
- Highlights

## Status Colors

Green:
- Active driving
- Successful states

Orange:
- Warnings

Red:
- Errors or critical states

Colors should have meaning and should not be overused.

---

# Typography

Font:

Inter

Hierarchy:

## Large Numbers

Used for important driving information.

Example:

45 km/h

## Titles

Used for page names and sections.

Example:

Trip Details

## Secondary Text

Used for descriptions and labels.

Example:

Average speed

---

# Navigation

Bottom navigation contains:

TripRank uses a custom floating bottom navigation bar.

Requirements:
- Floating (not attached to screen edges)
- Rounded corners
- Respect safe areas
- Large touch targets
- Blue highlight for the active tab
- Smooth transitions
- Consistent across the app

- Map
- Trips
- Cars
- Analytics
- Profile

The selected car is a global application state.

---

# Map Screen

The map should occupy most of the screen.

Avoid:
- Large overlays
- Blocking the map
- Unnecessary controls

---

# Driving Bottom Sheet

The bottom sheet should be minimal.

During driving display:

- Current speed
- Altitude
- Distance

Do not display detailed analytics during driving.

---

# Components

## Buttons

Primary buttons:
- Large
- Easy to tap
- Rounded

Used for:
- Start Drive
- Start Route
- Finish Drive

Secondary buttons:
- Smaller
- Used for settings/actions

---

## Cards

Cards should be:
- Simple
- Rounded
- Easy to scan

Avoid excessive information density.

---

# Animations

Animations should be:
- Smooth
- Short
- Functional

Avoid decorative animations.

---

# General Rule

Every screen should answer:

"What information does the user need right now?"

Do not add information just because it exists.