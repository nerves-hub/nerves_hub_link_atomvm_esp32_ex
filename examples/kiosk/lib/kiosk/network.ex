defmodule Kiosk.Network do
  @moduledoc """
  WiFi and the clock, brought up before anything tries to connect.

  Deliberately blocking rather than supervised. NervesHub refuses a
  shared-secret signature more than 90 seconds old and an ESP32 boots at the
  epoch, so there is nothing useful for the rest of the tree to do until both
  an address and a time exist.
  """

  def up(config) do
    self = self()

    network = [
      {:sta,
       [
         {:connected, fn -> send(self, :wifi_connected) end},
         {:got_ip, fn info -> send(self, {:wifi_ip, info}) end},
         {:disconnected, fn -> send(self, :wifi_disconnected) end}
         | config.sta
       ]},
      {:sntp,
       [
         {:host, ~c"pool.ntp.org"},
         {:synchronized, fn time -> send(self, {:sntp, time}) end}
       ]}
    ]

    {:ok, _pid} = :network.start(network)

    :ok = await(:wifi_ip, 30_000)
    :ok = await(:sntp, 30_000)

    IO.puts("clock:          #{:erlang.system_time(:second)}")
    :ok
  end

  defp await(what, timeout) do
    receive do
      {^what, value} ->
        IO.puts("#{what}: #{inspect(value)}")
        :ok

      _other ->
        await(what, timeout)
    after
      timeout -> throw({:network_timeout, what})
    end
  end
end
