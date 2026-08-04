# TripRank Development Tasks

## Phase 0 — Environment Setup

Status: Completed

Tasks:
- Install Flutter
- Install Android Studio
- Configure Android SDK
- Verify Flutter doctor
- Create Flutter project

---

# Phase 1 — Project Foundation

Status: In Progress

Tasks:

## Project Structure

- Create feature-first folder structure
- Configure app entry point
- Configure routing
- Configure theme system

## Core Setup

- Add state management
- Add local storage solution
- Create shared components structure

## Documentation

- Create project documentation
- Maintain docs as source of truth

---

# Phase 2 — App Shell

Tasks:

## Main Navigation

Implement:

- Map
- Trips
- Cars
- Profile
- Analytics

## Theme System

Implement:

- Dark mode default
- Light mode
- System mode
- Separate map theme preference

---

# Phase 3 — Vehicle System

Tasks:

## Vehicle Management

Implement:

- Add vehicle
- Edit vehicle
- Delete vehicle
- Select active vehicle

Vehicle fields:

- Brand
- Model
- Year
- Type

## Vehicle State

Implement:

- Remember last selected vehicle
- Use selected vehicle for trips and analytics

---

# Phase 4 — Map System

Tasks:

## Map Screen

Implement:

- Current location
- Google Maps integration
- Map theme selection

## Navigation Mode

Implement:

- Destination search
- Route display
- Voice guidance toggle

## Drive Tracking Mode

Implement:

- Start drive
- GPS tracking
- Finish drive
- Save trip

---

# Phase 5 — Trip System

Tasks:

## Trip Storage

Implement:

- Save trips
- Load trip history
- Link trips to vehicles

## Trip Details

Implement:

- Route display
- Distance
- Duration
- Speed statistics
- Altitude information
- Driving events

---

# Phase 6 — Driving Analytics

Tasks:

Implement:

- Speed calculations
- Speed graphs
- Altitude graphs
- Turn analysis
- Hard braking detection
- Sudden stop detection
- Overall statistics

---

# Phase 7 — Profile & Settings

Tasks:

Implement:

- Theme settings
- Map theme settings
- Units
- Voice settings
- Permissions

---

# Phase 8 — Testing & Polish

Tasks:

- Fix UI issues
- Improve performance
- Test GPS accuracy
- Test background behavior
- Test different devices

---

# Development Rules

- Complete phases in order.
- Do not build future features early.
- Keep the application simple.
- Test each major feature before moving on.
- Update documentation when decisions change.