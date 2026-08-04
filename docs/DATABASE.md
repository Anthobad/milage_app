# TripRank Database Design

## Overview

TripRank is an offline-first application.

User data is stored locally on the device.

The database should support:
- Vehicles
- Trips
- GPS tracking
- Driving analytics
- User preferences

---

# Entities

## Vehicle

Represents a user car.

Fields:

id
brand
model
year
type
createdAt

Example:

Toyota
Corolla
2020
Sedan

---

# Trip

Represents one driving session.

A trip can be:

- Navigation mode
- Drive tracking mode

Fields:

id
vehicleId
mode
startTime
endTime
distance
duration
averageSpeed
maximumSpeed
minimumSpeed
createdAt

Relationship:

Vehicle
|
|
└── Many Trips

---

# GPS Point

Stores the recorded route.

Fields:

id
tripId
latitude
longitude
altitude
speed
heading
timestamp

Relationship:

Trip
|
└── Many GPS Points

---

# Driving Events

Stores detected driving events.

Examples:

- Hard braking
- Sudden stop
- Turns

Fields:

id
tripId
type
timestamp
location

Event types:

LEFT_TURN
RIGHT_TURN
HARD_BRAKE
SUDDEN_STOP

---

# Trip Statistics

Calculated information from trip data.

Examples:

leftTurnCount
rightTurnCount
leftTurnPercentage
rightTurnPercentage
stopCount
startingAltitude
maximumAltitude
minimumAltitude
altitudeChange
totalElevationGain
totalElevationLoss
totalDistance
duration
movingTime
stoppedTime
minimumSpeed
averageSpeed
maximumSpeed

These can be calculated after the trip.

---

# User Preferences

Stores application settings.

Fields:

id
themeMode
mapTheme
units
voiceGuidanceEnabled
selectedVehicleId

---

# Analytics

Overall statistics generated from trips.

Examples:

totalDistance
totalTrips
totalDrivingTime
averageSpeed
averageAltitude
vehicleStatistics

Analytics should be calculated from stored trip data whenever possible.

---

# Relationships

Vehicle
|
| 1:N
|
Trip
|
| 1:N
|
GPS Point

Trip
|
| 1:N
|
Driving Events

---

# Database Rules

- Store raw data when possible.
- Calculate statistics from raw data.
- Avoid storing duplicate information.
- Keep data local.
- Database changes should not affect UI directly.