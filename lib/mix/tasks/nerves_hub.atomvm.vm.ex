defmodule Mix.Tasks.NervesHub.Atomvm.Vm do
  @shortdoc "Build an AtomVM firmware a NervesHub device can run"

  @moduledoc """
  Build an AtomVM firmware a NervesHub device can run.

      mix nerves_hub.atomvm.vm ~/src/AtomVM ~/src/atomvm_websocket_client

  A device does not run a stock AtomVM. The WebSocket transport is an ESP-IDF
  component, over-the-air updates need a partition table with two packbeam
  slots rather than the one stock has, and verifying signatures needs
  `AVM_USE_LIBSODIUM=ON` and more main task stack than the default.

  This copies two files into the AtomVM tree and runs `idf.py` with the right
  flags, so the same VM comes out on another machine. The files ship in the
  agent's `priv/atomvm` and are printed below as they are copied, so nothing
  here is hidden.

  Run it from an ESP-IDF environment (`. $IDF_PATH/export.sh`). ESP-IDF v5.2 to
  v5.5: AtomVM does not build against v6.

  ## Options

    * `--target` - the chip, `esp32` by default
    * `--no-libsodium` - skip Ed25519, and with it firmware signature
      verification. The two update slots are still set up
    * `--dry-run` - print what would happen and change nothing
  """

  use Mix.Task

  @agent :nerves_hub_link_atomvm_esp32

  @impl true
  def run(argv) do
    {options, paths} =
      OptionParser.parse!(argv,
        strict: [target: :string, libsodium: :boolean, dry_run: :boolean]
      )

    {atomvm, transport} = paths(paths)
    esp32 = Path.join([atomvm, "src", "platforms", "esp32"])

    check!(esp32, transport)

    priv = priv()
    dry_run? = Keyword.get(options, :dry_run, false)

    # The partition table is compiled into the firmware and the component
    # manifest has to sit beside the component it describes, so both have to
    # land in the AtomVM tree rather than being passed as flags.
    copy(Path.join(priv, "partitions.csv"), Path.join(esp32, "partitions.csv"), dry_run?)

    copy(
      Path.join(priv, "idf_component.yml"),
      Path.join([esp32, "components", "libatomvm", "idf_component.yml"]),
      dry_run?
    )

    idf(esp32, transport, priv, options, dry_run?)
  end

  defp paths([atomvm, transport]), do: {Path.expand(atomvm), Path.expand(transport)}

  defp paths(_other) do
    Mix.raise("""
    usage: mix nerves_hub.atomvm.vm <path-to-AtomVM> <path-to-atomvm_websocket_client>

    Both are checkouts. The transport is an ESP-IDF component and has to be
    compiled into the VM, which is why it is needed here rather than only as a
    dependency.
    """)
  end

  defp check!(esp32, transport) do
    File.dir?(esp32) || Mix.raise("not an AtomVM checkout: no #{esp32}")
    File.dir?(transport) || Mix.raise("no such directory: #{transport}")

    System.find_executable("idf.py") ||
      Mix.raise("idf.py is not on PATH. Source ESP-IDF's export.sh first.")
  end

  defp priv do
    case :code.priv_dir(@agent) do
      {:error, :bad_name} ->
        Mix.raise("#{@agent} is not a dependency of this project")

      dir ->
        Path.join(to_string(dir), "atomvm")
    end
  end

  defp copy(from, to, dry_run?) do
    Mix.shell().info([:green, "* copying ", :reset, Path.relative_to_cwd(to)])
    unless dry_run?, do: File.cp!(from, to)
  end

  defp idf(esp32, transport, priv, options, dry_run?) do
    target = Keyword.get(options, :target, "esp32")
    libsodium = if Keyword.get(options, :libsodium, true), do: "ON", else: "OFF"

    # `set-target` rather than `reconfigure`: CMake caches its component list,
    # and a plain build after adding one reports success without ever
    # compiling it.
    configure = [
      "-DAVM_USE_LIBSODIUM=#{libsodium}",
      "-DEXTRA_COMPONENT_DIRS=#{transport}",
      "-DSDKCONFIG_DEFAULTS=sdkconfig.defaults;#{Path.join(priv, "sdkconfig.defaults")}",
      "set-target",
      target
    ]

    run_idf(esp32, configure, dry_run?)
    run_idf(esp32, ["build"], dry_run?)

    unless dry_run? do
      Mix.shell().info([
        :green,
        "\nBuilt ",
        :reset,
        Path.join([esp32, "build", "atomvm-#{target}.bin"]),
        "\n\nFlash it, then the boot image:\n",
        "  cd #{esp32}\n",
        "  idf.py -p PORT flash\n",
        "  idf.py -p PORT flash-elixir\n"
      ])
    end
  end

  defp run_idf(esp32, args, true) do
    Mix.shell().info([:yellow, "* would run ", :reset, "idf.py ", Enum.join(args, " ")])
    _ = esp32
    :ok
  end

  defp run_idf(esp32, args, false) do
    Mix.shell().info([:green, "* idf.py ", :reset, Enum.join(args, " ")])

    case System.cmd("idf.py", args, cd: esp32, into: IO.stream(:stdio, :line)) do
      {_output, 0} -> :ok
      {_output, status} -> Mix.raise("idf.py #{Enum.join(args, " ")} failed with #{status}")
    end
  end
end
