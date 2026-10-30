# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later

defmodule Mix.Tasks.NervesHub.Atomvm.VmTest do
  use ExUnit.Case, async: false

  @task Mix.Tasks.NervesHub.Atomvm.Vm

  # A dry run checks for an AtomVM tree, a transport and `idf.py` on PATH, then
  # prints the idf.py commands instead of running them. None of the three has
  # to be real for that.
  setup do
    dir = Path.join(System.tmp_dir!(), "nh-vm-#{System.unique_integer([:positive])}")
    atomvm = Path.join(dir, "AtomVM")
    transport = Path.join(dir, "atomvm_websocket_client")
    bin = Path.join(dir, "bin")

    File.mkdir_p!(Path.join([atomvm, "src", "platforms", "esp32"]))
    File.mkdir_p!(transport)
    File.mkdir_p!(bin)
    File.write!(Path.join(bin, "idf.py"), "#!/bin/sh\nexit 1\n")
    File.chmod!(Path.join(bin, "idf.py"), 0o755)

    path = System.get_env("PATH")
    System.put_env("PATH", bin <> ":" <> path)
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      System.put_env("PATH", path)
      Mix.shell(Mix.Shell.IO)
      File.rm_rf!(dir)
    end)

    %{paths: [atomvm, transport]}
  end

  test "keeps SMP on by default", context do
    @task.run(["--dry-run" | context.paths])

    assert configure() =~ "-DAVM_DISABLE_SMP=OFF"
  end

  test "builds with one scheduler with --no-smp", context do
    @task.run(["--dry-run", "--no-smp" | context.paths])

    assert configure() =~ "-DAVM_DISABLE_SMP=ON"
  end

  defp configure do
    receive do
      {:mix_shell, :info, [line]} ->
        if line =~ "set-target", do: line, else: configure()
    after
      0 -> flunk("no idf.py set-target line")
    end
  end
end
