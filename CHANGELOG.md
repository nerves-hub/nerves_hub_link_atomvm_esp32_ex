# Changelog

Notable changes to this library. It follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Depends on `nerves_hub_link_atomvm_esp32` `~> 0.2`. Read its 0.2.0
  changelog before upgrading a fleet: firmware that cannot reach NervesHub
  after an update is now reverted by default, and new events arrive on every
  join.
- The README's `GenServer` example ends in a catch-all `handle_info/2` clause.
  Without one, the `{:update_mode, mode, allowed}` NervesHub sends after every
  join crashes the device process.

### Added

- `check_for_update/1`, `request_update/1`, `set_update_mode/2` and
  `update_mode/1`, for devices that manage their own updates.
- `apply_update/2`, `ignore_update/2` and `reschedule_update/3`, for
  `updates: :manual`.

## [0.1.2] - 2026-08-24

### Fixed

- The **Installing** snippet listed the agent as a dependency. It does not need
  listing: this package depends on it, so mix resolves and builds it. Verified
  against Hex with a project depending on nothing else.

## [0.1.1] - 2026-08-24

### Fixed

- The **Installing** snippet in the README asked for git dependencies, which is
  what they were before this package was on Hex, and did not say that
  `manager:` and `override:` belong in the consuming application rather than
  here. Documentation only; no code changed between 0.1.0 and this.

### Added

- `RELEASING.md`, listing every file a release has to touch and the order the
  two packages go out in. The README dependency snippet is the one nothing
  checks and the one that was wrong here.

## [0.1.0] - 2026-08-24

First release. An Elixir face for
[nerves_hub_link_atomvm_esp32](https://github.com/nerves-hub/nerves_hub_link_atomvm_esp32),
verified on hardware.

### Added

- `NervesHubLink`, delegating to the agent: `start_link/1` and `start/1` taking
  a keyword list, `child_spec/1` for a supervision tree, and the functions a
  device reports back with.
- `NervesHubLink.Logger`, which exists because AtomVM's `:logger` raises
  `badarg` on a binary message before any handler sees it, and Elixir strings
  are binaries.
- `mix nerves_hub.sign`, signing a packbeam without building an escript inside
  `deps`, verifying the result before it can be uploaded.
- `mix nerves_hub.atomvm.vm`, building the AtomVM firmware a device needs from
  the files the agent ships in `priv/atomvm`.
- `examples/kiosk`, a device as a `GenServer` under a `Supervisor`, with
  NervesHub events arriving as `handle_info/2`.
- A test that reads every remote call out of the compiled BEAM files and checks
  it against what AtomVM actually ships, because a call to a missing module
  compiles cleanly, passes on the host, and takes the application down on the
  device.

### Publishing

Hex will not take a package whose dependencies are not themselves on Hex, nor
one carrying `override:` or `manager:`, so `nerves_hub_link_atomvm_esp32` is
published first and the dependency here becomes a bare version requirement.
See `mix.exs`.

[Unreleased]: https://github.com/nerves-hub/nerves_hub_link_atomvm_esp32_ex/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/nerves-hub/nerves_hub_link_atomvm_esp32_ex/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/nerves-hub/nerves_hub_link_atomvm_esp32_ex/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/nerves-hub/nerves_hub_link_atomvm_esp32_ex/releases/tag/v0.1.0
