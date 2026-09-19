# PrFitness Production Foundation

## Product identity

PrFitness is an installable application.

The Android product is distributed as APK/AAB.

Users do not interact with a web URL.

## Signature themes

1. Pink + White
2. Black + Gold

There is no generic light/dark identity.

## Architecture

Phone
  |
  |-- Local database
  |-- Local notifications
  |-- Local scoring
  |-- Local calculations
  |
  +---- HTTPS Sync
          |
          v
       Go API
          |
          v
     PostgreSQL VPS

## Critical security rule

The mobile application never connects directly to PostgreSQL.

Database credentials remain on the VPS.

## Offline-first rule

Core functionality must continue to work when the VPS or internet is unavailable.

Changes will later enter a local sync outbox and synchronize when connectivity returns.

## Phase 0

- Flutter architecture
- design system
- theme engine
- component system
- Go API foundation
- PostgreSQL migration foundation
- offline-first boundary
- testing baseline

## Phase 1

- premium app shell
- mobile navigation
- desktop navigation
- animated navigation transitions
- animated theme changes
- premium dashboard
- haptic interactions
- edge-to-edge mobile UI
- responsive layout
- Android APK build validation

## Product rule

Visual sophistication must never be achieved by fabricating health data.

Real calculations remain deterministic, explainable and testable.
