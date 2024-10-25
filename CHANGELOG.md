# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.9.1] - 2024-10-26

### Added

- Detecting and fixing docker server issues
- Additional cleanup of container logs
- Events added to logs and diagnostics
- Mail notification on possible update
- Build date shown in UI, logs and diagnostics
- Forced update flag
- Gracefull handling of repo 404 and invalid channels

### Changed

- Tool update mechanism taking into account build date

### Fixed

- Cleanups and refactoring in dialogs
- Bugs in update detection

## [1.9.0] - 2024-10-12

### Added

- Cleanup menu
- Gathering and sending encrypted diagnostics
- Watchdog notifications for low free space

### Changed

- Main menu, moved update items to its own submenu
- Added diagnostics encryption key to about dialog

### Fixed

- More robust watchdog, detects and restarts stale MongoDB

## [1.8.1] - 2024-01-17

### Added

- Custom update channels support

### Changed

- Added more detailed logs in case of watchdog failure

## [1.8.0] - 2024-01-07

### Added

- Support for command line switches
- Support for development and production update channels
- Watchdog called from cron
- Status of watchdog and its logs

### Changed

- Main menu status show live calculated status instead of Nightscout container status

### Fixed

- Removed underscore from domain name hint, as xDrip and NS have issues with domains containing it

### Fixed

- More memory and memory limits config (in template) for MongoDB

## [1.7.0] - 2023-10-20

### Added

- UI shows verison number
- split betwen conatainer update and restart
