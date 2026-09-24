# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later

defmodule Kiosk.Device do
  @moduledoc """
  The device, as a `GenServer`.

  This is the answer to "should NervesHub events be `handle_info`". They
  already are: the agent sends `{:nerves_hub, event}` to whatever process is
  named as its `:handler`, and a `GenServer` that names itself gets them in
  `handle_info/2` alongside everything else it hears. The library needs no
  callback behaviour to allow this, and adding one would only hide which
  messages exist.

  What a `GenServer` buys over a bare `receive` loop is the ordinary Elixir
  answer: state lives in one place instead of being threaded through every
  clause of a recursive function, the process is supervised, and a timer or a
  GPIO callback arrives through the same door as a NervesHub event.
  """

  use GenServer

  alias NervesHubLink.Logger, as: Log

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config) do
    # `handler: self()` is the whole trick. init/1 runs in this process, so the
    # agent reports here, and `start_link` links the two: if the agent dies
    # this dies, and the supervisor starts both again.
    {:ok, agent} =
      NervesHubLink.start_link(
        url: config.url,
        identifier: config.identifier,
        shared_secret: config.shared_secret,
        verify: :none,
        console: true,
        extensions: :all,
        firmware_keys: config.firmware_keys,
        request_firmware_keys: true,
        register: :nerves_hub_link,
        handler: self(),
        capture_io: true
      )

    {:ok, %{agent: agent, config: config}}
  end

  @impl true
  def handle_info({:nerves_hub, {:joined, reply}}, state) do
    Log.info("joined: #{inspect(reply)}")
    {:noreply, state}
  end

  def handle_info({:nerves_hub, {:extensions_attached, attached}}, state) do
    Log.info("extensions: #{inspect(attached)}")
    {:noreply, state}
  end

  def handle_info({:nerves_hub, {:firmware_keys, count}}, state) do
    Log.info("firmware keys: #{count} after the server's")
    {:noreply, state}
  end

  # A bare atom now, rather than a one-tuple.
  def handle_info({:nerves_hub, :identify}, state) do
    Log.info("identify")
    # In its own process: blinking takes two seconds, and a GenServer that
    # sleeps is a GenServer that is not reading NervesHub's messages.
    spawn(fn -> blink(Map.get(state.config, :led_pin, 2)) end)
    {:noreply, state}
  end

  def handle_info({:nerves_hub, :console_joined}, state) do
    Log.info("console attached")
    {:noreply, state}
  end

  def handle_info({:nerves_hub, {:update_ready, slot}}, state) do
    Log.info("update armed in #{slot}, rebooting")
    # After the reply, so NervesHub hears about it before the socket drops.
    Process.send_after(self(), :restart, 500)
    {:noreply, state}
  end

  def handle_info({:nerves_hub, {:firmware_committed, slot}}, state) do
    Log.info("running #{slot}, committed")
    {:noreply, state}
  end

  def handle_info({:nerves_hub, {:update_failed, reason}}, state) do
    Log.error("update refused: #{inspect(reason)}")
    {:noreply, state}
  end

  # Dropped rather than logged: something pushed while the connection is down
  # comes back as this, and it says nothing a `{:disconnected, _}` did not.
  # Log lines are not among them; the agent holds those until logging attaches.
  def handle_info({:nerves_hub, {:not_joined, _topic}}, state), do: {:noreply, state}

  def handle_info({:nerves_hub, event}, state) do
    Log.info("nerves_hub: #{inspect(event)}")
    {:noreply, state}
  end

  # Not a NervesHub message at all, which is the point: one mailbox, one place
  # to handle what arrives in it.
  def handle_info(:restart, state) do
    :esp.restart()
    {:noreply, state}
  end

  def handle_info(other, state) do
    Log.info("unexpected: #{inspect(other)}")
    {:noreply, state}
  end

  defp blink(pin) do
    :gpio.set_pin_mode(pin, :output)
    blink(pin, 6)
  catch
    class, reason -> Log.warning("no LED on pin #{pin}: #{class} #{inspect(reason)}")
  end

  defp blink(pin, 0), do: :gpio.digital_write(pin, :low)

  defp blink(pin, remaining) do
    :gpio.digital_write(pin, :high)
    :timer.sleep(150)
    :gpio.digital_write(pin, :low)
    :timer.sleep(150)
    blink(pin, remaining - 1)
  end
end
