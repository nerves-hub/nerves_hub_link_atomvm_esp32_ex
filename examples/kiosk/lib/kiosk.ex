defmodule Kiosk do
  @moduledoc """
  A NervesHub device in Elixir, on AtomVM.

  The point of this example is the shape rather than the features: the device
  is a `GenServer` under a `Supervisor`, and NervesHub events arrive as
  `handle_info/2` like any other message. See `Kiosk.Device`.

  `start/0` is the entry point AtomVM calls, named in `mix.exs`. There is no
  `Application` on AtomVM and no application callback, so the supervision tree
  is something built here rather than something you get.
  """

  alias NervesHubLink.Logger, as: Log

  def start do
    config = Config.get()

    # Nothing starts logger_manager on AtomVM, and handlers can only be given
    # to it here: there is no add_handler/3, so the NervesHub handler has to be
    # in place before the agent exists. It finds the agent by registered name.
    #
    # nh_console_h rather than logger_std_h because capture_io is on below.
    # logger runs handlers in the process that logged, so logger_std_h's own
    # io:format would be captured and every line would go up twice.
    {:ok, _logger} =
      :logger_manager.start_link(%{
        log_level: :info,
        logger: [
          :nh_console_h.handler(%{level: :info}),
          :nh_logger.handler(%{level: :info})
        ]
      })

    IO.puts("\n=== kiosk ===")
    IO.puts("AtomVM:         #{inspect(:nh_metadata.atomvm_version())}")
    IO.puts("boot partition: #{inspect(:nh_flash.boot_partition())}")

    # Before the agent: a shared-secret signature is refused if it is more than
    # 90 seconds old, and an ESP32 boots at the epoch.
    :ok = Kiosk.Network.up(config)

    {:ok, _supervisor} = Supervisor.start_link([{Kiosk.Device, config}], strategy: :one_for_one)

    Log.info("kiosk is up")

    # AtomVM stops when the process that started everything returns, so this
    # one waits instead. The work happens in Kiosk.Device.
    sleep_forever()
  end

  defp sleep_forever do
    receive do
      other -> IO.puts("main: #{inspect(other)}")
    end

    sleep_forever()
  end
end
