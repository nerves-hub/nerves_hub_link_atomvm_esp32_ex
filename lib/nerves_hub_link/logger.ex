# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later

defmodule NervesHubLink.Logger do
  @moduledoc """
  Logging that does not kill the process that logged.

  AtomVM's `:logger` accepts a list or a map and raises `badarg` on anything
  else, *before* any handler sees the event. Elixir strings are binaries, so
  the most natural line an Elixir developer can write is the one that crashes:

      :logger.info("started")   # badarg, and the caller dies

  This converts a binary to a charlist and passes everything else through.

      require NervesHubLink.Logger, as: Log
      Log.info("started")
      Log.warning(%{event: :retrying, attempt: 3})

  It is `:logger` underneath, so `:nh_logger` picks these up like any other
  event and sends them to NervesHub. Nothing here talks to the agent, which is
  why it works before the agent exists and keeps working if it dies.

  For a line that should reach NervesHub whatever `:logger` is configured to
  do, `NervesHubLink.send_log/4` sends one directly.
  """

  levels = [:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug]

  for level <- levels do
    @doc "Log at #{level}."
    def unquote(level)(message), do: log(unquote(level), message)

    @doc "Log at #{level}, with a format string and arguments."
    def unquote(level)(format, args), do: log(unquote(level), format, args)
  end

  @doc """
  Log at a level chosen at runtime.
  """
  def log(level, message), do: :logger.log(level, safe(message))

  def log(level, format, args) when is_list(args),
    do: :logger.log(level, safe(format), args)

  @doc """
  What `:logger` will actually be given.

  Public because it is the whole point of this module, and asserting on it is
  more honest than asserting on the shape a particular `logger` hands a
  handler: AtomVM's and OTP's differ, and the device runs AtomVM's.
  """
  # `:unicode` rather than `String.to_charlist/1`: AtomVM has no `String`
  # module, and neither does `to_charlist/1` help, since `List.Chars.BitString`
  # calls `String.to_charlist/1` itself. This is not something host tests can
  # catch, because on the host both exist.
  def safe(message) when is_binary(message), do: :unicode.characters_to_list(message)
  def safe(message) when is_list(message), do: message
  def safe(message) when is_map(message), do: message
  def safe(message), do: message |> inspect() |> :unicode.characters_to_list()
end
