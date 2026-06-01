# Garmin Connect IQ API Reference

> Auto-generated reference from [Garmin Connect IQ API Docs](https://developer.garmin.com/connect-iq/api-docs/index.html)
> Generated: May 31, 2026

## Overview

The Connect IQ SDK provides the **Toybox** framework, a collection of modules for building Garmin watch applications.

## Core Modules

### Application Lifecycle
- **Toybox.Application** — App lifecycle management (onStart, onStop, onUpdate, etc.)
- **Toybox.ApplicationProperties** — Application properties and settings

### User Interface
- **Toybox.Lang** — Language utilities (String, Array, Math, etc.)
- **Toybox.Lang.Exception** — Exception handling
- **Toybox.Lang.Object** — Base object class

### Data & Storage
- **Toybox.Storage** — Persistent data storage
- **Toybox.System** — System utilities (memory, power, device info)

### Connectivity
- **Toybox.Communication** — Data streaming and file transfer
- **Toybox.Web** — HTTP/HTTPS network requests

### Sensors & Hardware
- **Toybox.Activity** — Activity tracking APIs
- **Toybox.ActivityMonitor** — Activity monitoring
- **Toybox.ActivityPrompts** — Activity-related prompts
- **Toybox.ActivityRecording** — Activity recording
- **Toybox.Ant** — ANT wireless protocol
- **Toybox.AntPlus** — ANT+ sensor support
- **Toybox.Attention** — Attention level monitoring
- **Toybox.Authentication** — User authentication
- **Toybox.Gps** — GPS positioning
- **Toybox.Sensor** — Sensor access (accelerometer, gyroscope, etc.)
- **Toybox.SensorSimulation** — Sensor simulation for testing

### Health & Wellness
- **Toybox.Health** — Health data access
- **Toybox.Health.Stores** — Health data stores
- **Toybox.WatchUi** — UI framework (menus, views, layouts)

### Media & Audio
- **Toybox.Media** — Media playback control
- **Toybox.Audio** — Audio playback

### Location & Maps
- **Toybox.Maps** — Map rendering and geolocation
- **Toybox.Position** — Positioning utilities

### Time & Calendar
- **Toybox.Time** — Time handling
- **Toybox.Time.Format** — Time formatting
- **Toybox.Time.Zone** — Time zone handling

### Other Modules
- **Toybox.Payments** — Garmin Pay integration
- **Toybox.Settings** — Device settings
- **Toybox.UserMessages** — User messages
- **Toybox.VideoRecording** — Video recording (supported devices)
- **Toybox.WatchState** — Watch state monitoring

## Key Classes for BMW Widget

Based on the current project (`grm_bmw_widget`), the most relevant Toybox modules are:

| Module | Usage in Project |
|--------|-----------------|
| `Toybox.Application` | App entry point (`BmwWidgetApp.mc`) |
| `Toybox.WatchUi` | UI views and pages (`WatchUi:View`, `WatchUi:Menu`) |
| `Toybox.Storage` | Persistent data storage (`VehicleCache`, `TokenManager`) |
| `Toybox.Web` | HTTP requests for vehicle data (`Web:HttpClient`) |
| `Toybox.System` | System utilities and device info |
| `Toybox.Activity` | Activity tracking (if applicable) |
| `Toybox.Gps` | GPS positioning (location-based features) |

## SDK Version

This reference applies to Connect IQ SDK **v9.1.0** (2026-03-09).

## Further Reading

- [Connect IQ Developer Guide](https://developer.garmin.com/connect-iq/)
- [Connect IQ API Docs (full)](https://developer.garmin.com/connect-iq/api-docs/)
- [Connect IQ Sample Apps](https://developer.garmin.com/connect-iq/sample-apps/)
