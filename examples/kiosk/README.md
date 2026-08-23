# kiosk

A NervesHub device in Elixir, on AtomVM. The point is the shape rather than the
features: a `GenServer` under a `Supervisor`, with NervesHub events arriving as
`handle_info/2`.

## Why a GenServer

The agent sends `{:nerves_hub, event}` to whatever process is named as its
`:handler`. Name a `GenServer` and those land in `handle_info/2` next to
everything else it hears:

```elixir
def init(config) do
  {:ok, agent} = NervesHubLink.start_link(handler: self(), identifier: ..., ...)
  {:ok, %{agent: agent, config: config}}
end

def handle_info({:nerves_hub, :identify}, state) do
  spawn(fn -> blink(state.config.led_pin) end)
  {:noreply, state}
end

def handle_info(:restart, state) do
  :esp.restart()
  {:noreply, state}
end
```

No callback behaviour is involved and none is needed. The messages are still
the interface, still pattern-matched where you can see them; a `GenServer` only
saves threading state through every clause of a recursive `receive` and gives
the process a supervisor. The last clause above is the argument for it: a timer
this process set arrives through the same door as a NervesHub event.

`handler: self()` in `init/1` is what wires it up, and `start_link` ties the
two together, so if the agent dies the device does too and the supervisor
restarts both.

## Two things this got wrong first

Blinking in `handle_info` blocks the process for two seconds, and a `GenServer`
that sleeps is one that is not reading NervesHub's messages. It runs in its own
process instead.

A catch-all clause that logs every unrecognised event chases its own tail. A
log line sent before the logging extension attaches comes back as
`{:not_joined, "logging:send"}`, and logging that sends another line, which
comes back again. It settles once the extension is up, but the fix is to drop
that event rather than report it.

## The VM underneath

This does not run on a stock AtomVM:

```
. $IDF_PATH/export.sh
mix nerves_hub.atomvm.vm ~/src/AtomVM ~/src/atomvm_websocket_client
```

## Before building

```
cp lib/config.ex.example lib/config.ex
```

That file holds a WiFi password and a NervesHub shared secret, so it is not
committed.

## Building and flashing

```
mix atomvm.packbeam
```

The offset below is `main.avm` in the table on the device, which comes from the
AtomVM build, not from the `partitions.csv` kept here for reference. Read the
device rather than trusting the file: writing to an offset from a stale copy
lands the app inside `boot.avm`, and the only symptom is
`Failed app start: invalid_avm`.

```
esptool.py --chip esp32 --port /dev/ttyUSB0 read_flash 0x8000 0xC00 ptable.bin
gen_esp32part.py ptable.bin
esptool.py --chip esp32 --port /dev/ttyUSB0 --baud 460800 \
  write_flash 0x270000 kiosk.avm
```

After the first flash, updates go over the air.

## Status

Run on an ESP32 against a NervesHub. `Supervisor` and `GenServer` both work on
AtomVM, events arrive as `handle_info/2`, and the device joins, attaches all
three extensions and takes a console session.

`nerves_hub_link_atomvm_esp32` is a path dependency here rather than the
published one, because this example uses the keyword-list config that is not
released yet. Switch it back to `github:` once it is.
