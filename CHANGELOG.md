# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Minor features that don't break backwards compatibility are released as patches.

## Unreleased

### Added

- `raindown DIRECTORY`, or `raindown` for the current directory, watches every project in it with a `.raindown` folder
- Each project's nodes load in a process of their own, and reload when they change

### Changed

- Watching only writes back to files, without writing HTML, so `-o` is for `--once` and `--stdin`

## 0.4.0

### Added

- `raindown init` creates a `.raindown` folder with a `config.yml`
- `raindown --version`

### Fixed

- Errors in a file show as one line instead of a backtrace, and `RAINDOWN_DEBUG=1` shows the backtrace
- An error in a file no longer stops `raindown FILE` watching it
- Standalone binaries of the same minor version, like 0.3.0 and 0.3.1, shared a cached payload and warned on every run
- Standalone binaries remove earlier releases' payloads from `~/.tebako`

### Changed

- Remove the nokogiri dependency, which made the gem and standalone binaries much larger
- Escape HTML with `CGI.escapeHTML` rather than loading erb
- Standalone binaries are compressed with DwarFS, and leave out gem archives, other Rubies' native builds, sources, signatures and tests

## 0.3.0

### Added

- Support charts
- Support antlers node arguments

## 0.1.0

### Added

- First release
