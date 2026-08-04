# TripRank Personal Architecture

## Overview

TripRank Personal uses a feature-first Flutter architecture designed for maintainability, scalability, and AI-assisted development.

The architecture should remain simple while allowing features to grow independently.

---

# Technology Stack

## Framework

Flutter

## Language

Dart

## State Management

Riverpod

Used for:
- Application state
- Feature state
- Dependency injection

## Navigation

GoRouter

Used for:
- Screen navigation
- Route management
- Deep linking support

---

# Project Structure

lib/
├── app/
│ ├── app configuration
│ ├── router
│ ├── theme/
│ │ ├── app_theme.dart
│ │ ├── colors.dart
│ │ ├── spacing.dart
│ │ └── typography.dart
│ ├── app.dart
│ └── router.dart
│   
├── core/
│ ├── services
│ ├── constants
│ ├── extensions
│ ├── utils
│ └── errors
│
├── features/
│ ├── map/
│ ├── trips/
│ ├── cars/
│ ├── analytics/
│ └── profile/
│
├── shared/
│ ├── widgets
│ ├── models
│ └── components
│
└── main.dart

---

# Architecture Rules

## Feature Independence

Each feature should contain its own:
- Screens
- Widgets
- Controllers/providers
- Feature-specific logic

Features should not directly depend on each other.

---

## Business Logic

Business logic must not be placed inside UI widgets.

Example:

Incorrect:

Button → Calculates trip statistics

Correct:

Button
|
Provider
|
Service
|
Result

---

## Data Flow

General flow:

UI
|
Provider
|
Repository / Service
|
Data Source

---

# State Management

Riverpod manages:

- Current selected vehicle
- Active trip state
- User preferences
- Theme settings
- Analytics data

---

# Navigation Structure

Main navigation:

Map
Trips
Cars
Analytics
Profile

Additional screens:

Trip Details
Add Vehicle
Edit Vehicle
Settings

---

# Data Storage

The app is offline-first.

User data should be stored locally.

Initial data includes:

- Vehicles
- Trips
- Preferences
- Analytics data

Cloud synchronization is not required.

---

# Map Architecture

Google Maps is responsible for:

- Map rendering
- Routes
- Navigation display

TripRank is responsible for:

- Trip recording
- GPS data collection
- Driving analytics
- Vehicle association

---

# Development Rules

- Keep code simple.
- Avoid unnecessary dependencies.
- Avoid duplicate logic.
- Create reusable components when needed.
- Do not over-engineer features before they exist.