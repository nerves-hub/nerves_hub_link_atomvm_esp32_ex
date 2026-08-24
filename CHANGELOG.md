# Changelog

Notable changes to this library. It follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0]

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

[Unreleased]: https://github.com/nerves-hub/nerves_hub_link_atomvm_esp32_ex/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/nerves-hub/nerves_hub_link_atomvm_esp32_ex/releases/tag/v0.1.0
