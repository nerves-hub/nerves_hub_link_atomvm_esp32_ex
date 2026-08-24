# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later

defmodule NervesHubLink do
  @moduledoc """
  An Elixir face for `:nerves_hub_link`.

  A convenience layer, not an abstraction. Every function here is one line deep
  and the Erlang agent does the work, so `:nerves_hub_link` can be called
  directly for anything this does not cover. Nothing here holds state, so mixing
  the two is ordinary rather than a workaround.

      {:ok, agent} =
        NervesHubLink.start_link(
          identifier: "my-device",
          shared_secret: {key, secret},
          console: true,
          extensions: :all
        )

  Where it connects is worked out for you. See `:nh_url`.

  ## Events

  The agent sends `{:nerves_hub, event}` to whatever process is named as its
  `:handler`, which defaults to the caller. Name a `GenServer` and they arrive
  in `handle_info/2`:

      def init(config) do
        {:ok, agent} = NervesHubLink.start_link(handler: self(), identifier: ...)
        {:ok, %{agent: agent}}
      end

      def handle_info({:nerves_hub, :identify}, state) do
        spawn(fn -> blink() end)
        {:noreply, state}
      end

  That is the shape to reach for, and it needs nothing from this library:
  `handler: self()` in `init/1` is the whole of it. A bare `receive` loop works
  too, and is enough for a device that waits on nothing else.

  There is deliberately no handler behaviour. `handle_info/2` *is* the
  messages, still matched where you can see them; callbacks like `identify/1`
  would hide the part worth reading, which is what the device actually hears.

  See the README for what a supervised device looks like, and for two ways to
  get `handle_info/2` wrong on a device.

  ## Logging

  `NervesHubLink.Logger` exists because AtomVM's `:logger` raises `badarg` on a
  binary message, which takes down the process that logged it. Elixir strings
  are binaries, so `:logger.info("...")` is a crash waiting for the first line
  anyone writes.
  """

  @doc """
  A child specification, for a supervision tree.

  `:handler` is required here even though `:nerves_hub_link` defaults it to the
  calling process. Under a supervisor the caller is the supervisor, which does
  not read its mailbox, so the default silently sends every event nowhere.

      children = [
        {NervesHubLink, handler: self(), identifier: "my-device", shared_secret: {key, secret}}
      ]

  Building the spec happens in your process, so `self()` there is what you want.
  """
  def child_spec(options) do
    options
    |> Keyword.fetch(:handler)
    |> case do
      {:ok, _handler} ->
        :ok

      :error ->
        raise ArgumentError, """
        NervesHubLink needs a :handler when supervised.

        Without one the agent reports to whatever process started it, which
        under a supervisor is the supervisor, and every {:nerves_hub, event}
        goes to a mailbox nothing reads.

            {NervesHubLink, handler: self(), identifier: "..."}
        """
    end

    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [options]},
      type: :worker,
      restart: :permanent,
      shutdown: 5_000
    }
  end

  @doc "Connect, linked to the calling process."
  def start_link(options), do: :nerves_hub_link.start_link(options)

  @doc "Connect, unlinked."
  def start(options), do: :nerves_hub_link.start(options)

  @doc "Stop the agent."
  def stop(agent), do: :nerves_hub_link.stop(agent)

  @doc """
  Report how far an update has got.

  NervesHub shows this on the device's page, so a long download looks like
  progress rather than a device that has stopped answering.
  """
  def update_progress(agent, percent, status \\ "downloading"),
    do: :nerves_hub_link.update_progress(agent, percent, status)

  @doc """
  Tell NervesHub the running firmware works.

  Until this arrives the update is on probation, and a device that reboots
  without sending it is treated as having failed.
  """
  def firmware_validated(agent), do: :nerves_hub_link.firmware_validated(agent)

  @doc "Report an update that could not be installed."
  def update_failed(agent, reason), do: :nerves_hub_link.update_failed(agent, reason)

  @doc """
  Send one log line, whatever its level.

  Takes a binary, unlike `:logger`. Needs the logging extension attached and
  the device's clock set.
  """
  def send_log(agent, level, message, meta \\ %{}),
    do: :nerves_hub_link.send_log(agent, level_name(level), message, meta)

  # Not `to_string/1`: that reaches `String.Chars.Atom`, which calls
  # `Atom.to_string/1`, and AtomVM ships neither `Atom` nor `String`.
  defp level_name(level) when is_atom(level), do: :erlang.atom_to_binary(level, :utf8)
  defp level_name(level) when is_binary(level), do: level

  @doc "Push a message on the device channel."
  def push(agent, event, payload), do: :nerves_hub_link.push(agent, event, payload)
end
