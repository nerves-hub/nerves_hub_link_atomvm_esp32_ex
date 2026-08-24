# NervesHubLink for Elixir on AtomVM

An Elixir face for
[nerves_hub_link_atomvm_esp32](https://github.com/nerves-hub/nerves_hub_link_atomvm_esp32).

A convenience layer, not an abstraction. Every function is one line deep and
the Erlang agent does the work, so anything not covered here can be called on
`:nerves_hub_link` directly without leaving the road.

## Installing

```elixir
defp deps do
  [
    {:nerves_hub_link_atomvm_esp32_ex,
     github: "nerves-hub/nerves_hub_link_atomvm_esp32_ex"},
    # Both rebar3 projects, so mix is told which manager to use.
    {:nerves_hub_link_atomvm_esp32,
     github: "nerves-hub/nerves_hub_link_atomvm_esp32", manager: :rebar3, override: true},
    {:atomvm_websocket_client,
     github: "nerves-hub/atomvm_websocket_client", manager: :rebar3, override: true}
  ]
end
```

All three, and none of them optional: this package delegates to the agent, and
the agent talks to NervesHub over the transport. The transport is also an
ESP-IDF component, so it has to be compiled into the VM as well as listed here.

Not on Hex yet, which is why these are git dependencies.

## Usage

```elixir
{:ok, agent} =
  NervesHubLink.start_link(
    identifier: "my-device",
    shared_secret: {key, secret},
    console: true,
    extensions: :all
  )
```

Where it connects is worked out for you, so there is no URL above. See `nh_url`
in the agent.

A device needs AtomVM built from source: the WebSocket transport is an ESP-IDF
component, and over-the-air updates need a partition table with two packbeam
slots rather than the one a stock build has.

```
. $IDF_PATH/export.sh
mix nerves_hub.atomvm.vm ~/src/AtomVM ~/src/atomvm_websocket_client
```

That task copies the two files the VM needs out of the agent's `priv/atomvm`
and runs `idf.py` with the right flags. `--dry-run` prints what it would do.
The agent's README explains
[what each change buys](https://github.com/nerves-hub/nerves_hub_link_atomvm_esp32#building-the-vm).

## Write the device as a GenServer

The agent sends `{:nerves_hub, event}` to whatever process is named as its
`:handler`. Name a `GenServer` and those arrive in `handle_info/2`:

```elixir
defmodule Kiosk.Device do
  use GenServer

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config) do
    {:ok, agent} =
      NervesHubLink.start_link(
        handler: self(),
        identifier: config.identifier,
        shared_secret: config.shared_secret,
        console: true,
        extensions: :all
      )

    {:ok, %{agent: agent, config: config}}
  end

  @impl true
  def handle_info({:nerves_hub, {:joined, _reply}}, state), do: {:noreply, state}

  def handle_info({:nerves_hub, :identify}, state) do
    spawn(fn -> blink(state.config.led_pin) end)
    {:noreply, state}
  end

  def handle_info({:nerves_hub, {:update_ready, _slot}}, state) do
    Process.send_after(self(), :restart, 500)
    {:noreply, state}
  end

  # Not a NervesHub message, which is the point.
  def handle_info(:restart, state) do
    :esp.restart()
    {:noreply, state}
  end
end
```

Please see [examples/kiosk](examples/kiosk) for an example implementation.

Be careful with a catch-all clause that logs. A log line sent before the
logging extension attaches comes back as `{:not_joined, "logging:send"}`, and
logging *that* sends another line, which comes back again. It settles once the
extension is up, but until then the process chases its own tail. Drop that
event rather than report it.

## Supervision

Supervise the device, and the agent comes with it:

```elixir
def start do
  config = Config.get()
  :ok = Kiosk.Network.up(config)

  {:ok, _supervisor} = Supervisor.start_link([{Kiosk.Device, config}], strategy: :one_for_one)

  sleep_forever()
end
```

There is one child, and the agent is not in the list. `Kiosk.Device` starts it
in `init/1` with `start_link`, so the two are linked: if the agent dies the
device dies, the supervisor restarts the device, and `init/1` connects again.
The tree is `Supervisor -> Kiosk.Device -> agent`, and only the middle one
needs a child spec, which `use GenServer` writes.

Note what `start/0` does after starting the supervisor. AtomVM stops when the
process that started everything returns, so it waits instead. There is no
`Application` here and no application callback: an app runs from the `start/0`
named in its own `mix.exs`, so the tree is something you build there rather
than something you get.

### Putting the agent in the tree directly

`NervesHubLink` has a `child_spec/1` too, for a device with no GenServer to
hang it from:

```elixir
children = [
  {NervesHubLink, handler: self(), identifier: "my-device", shared_secret: {key, secret}}
]
```

`:handler` is required here even though the agent defaults it to whatever
started it. Under a supervisor that is the supervisor, which does not read its
mailbox, so the default would send every event nowhere. `child_spec/1` raises
rather than let that happen.

It only fits when the process building the child list is the one that will read
the events, since `self()` is evaluated there. A sibling in the list cannot be
named this way, because it does not exist yet. That is the reason the GenServer
above starts the agent itself rather than sitting beside it.

### Restarts

The agent starts before it connects, so a refused connection is a crash shortly
after a successful start, not an error from `start_link/1`. A supervisor sees a
restart rather than a startup failure.

That matters more than it sounds, because `:max_restarts` defaults to 3 in 5
seconds. A device whose WiFi is not up yet can spend those three restarts
before the radio has an address, and then the supervisor exits and takes the
application with it. Bringing the network up before starting the tree, as
`start/0` above does, is the simple fix; raising `:max_restarts` is the other.

## Logging

```elixir
alias NervesHubLink.Logger, as: Log

Log.info("started")
Log.warning(%{event: :retrying, attempt: 3})
```

AtomVM's `:logger` accepts a list or a map and raises `badarg` on anything
else, *before* any handler sees the event. Elixir strings are binaries, so the
most natural line an Elixir developer can write is the one that takes down the
process that wrote it. This converts and passes everything else through.

It is `:logger` underneath, so `:nh_logger` picks these up like any other event.
Nothing here talks to the agent, which is why it works before the agent exists
and keeps working if it dies.

## Signing

```
mix nerves_hub.sign --key ~/keys/fwup-key.priv
```

Signs `<app>.avm` in place and verifies the result, so a wrong key is found
here rather than by a device refusing the update. `--check` reports without
changing anything, and the key path can come from `NERVES_HUB_FW_PRIVATE_KEY`
instead of the flag.

A device only requires this if it is configured with `firmware_keys`. The key
is the organization's existing fwup private key, whose trailing half is the
`.pub` NervesHub already stores, so signing packbeams adds no key management.

To sign every build, chain it onto the packbeam alias:

```elixir
aliases: [
  "atomvm.packbeam": ["atomvm.application_bin", "atomvm.packbeam", "nerves_hub.sign"]
]
```

Then a build needs the key present, so a contributor without one cannot build
and CI has to be given a key before anything works. That trade is why it is not
wired up for you. What the task will not do is quietly succeed without a key:
that is how unsigned firmware reaches a product configured to allow unsigned.

Give it a path, never the key itself. `mix.exs` is committed, and a key in an
environment variable is readable in process listings and tends to end up in CI
logs.

## License

Apache-2.0 OR LGPL-2.1-or-later.
