# Releasing

Every file that has to change for a release, in the order they have to change,
because the ones that are easy to forget are the ones nothing checks. Nothing
in CI catches a README still describing the previous version's dependency.

This package depends on
[nerves_hub_link_atomvm_esp32](https://github.com/nerves-hub/nerves_hub_link_atomvm_esp32),
so that one is released first. Hex will not accept a package whose dependencies
are not themselves on Hex.

## Before

- [ ] The agent is released, and its version is what this depends on.
- [ ] `CHANGELOG.md`: move `Unreleased` into a new version heading, dated, and
      add the compare links at the bottom.
- [ ] `mix.exs`: bump `@version`.
- [ ] `mix.exs`: the dependency on the agent must be a bare requirement.
      Hex rejects `github:`, `override:` and `manager:` on a published
      package's dependencies, and it rejects them one at a time, so fixing
      only the first gets you the second.
- [ ] `README.md`: the versions in the **Installing** snippet. This is the one
      that gets missed.
- [ ] `mix test`, `mix test --cover`, `mix format --check-formatted`.
- [ ] Build a throwaway project that depends only on this package and check
      the install snippet against it. Nothing else catches a snippet that lists
      a dependency mix would have resolved anyway.
- [ ] `mix hex.build`, then look at the file list it prints. `files` in
      `package/0` is an allow list, so a new top-level directory is absent
      until someone adds it.

## Publish

```
mix hex.publish
```

Hex allows an hour to revert a publish and nothing after that, so read what it
prints before confirming.

## After

```
git tag -a v0.1.2 -m "v0.1.2"
git push origin v0.1.2
```

## What does not change

`atomvm_websocket_client` stays a git dependency in the Installing snippet. It
is not on Hex and is not going to be: it is an ESP-IDF component first, and the
half that matters is compiled into the VM rather than fetched by mix.

`examples/kiosk` uses `path: "../.."` for this package deliberately. An example
inside this repository should build against the code it ships with, not against
the last published version of it.
