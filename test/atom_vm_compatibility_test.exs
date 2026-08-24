# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later

defmodule AtomVMCompatibilityTest do
  use ExUnit.Case, async: true

  # The bug this catches happened for real: `String.to_charlist/1` compiled,
  # passed every test on the host, and failed on the device with
  #
  #     Failed load module: Elixir.String.beam
  #
  # taking the application down. Nothing running on OTP can notice, because on
  # OTP the module is there. This reads what each module actually calls out of
  # its compiled BEAM and checks it against what a device has.
  test "every module this library calls exists on AtomVM" do
    # AtomVM's own libraries, plus everything packed into the archive
    # alongside this: the agent it delegates to, and this library itself.
    available =
      [:nerves_hub_link_atomvm_esp32, :nerves_hub_link_atomvm_esp32_ex]
      |> Enum.flat_map(&modules_of/1)
      |> MapSet.new()
      |> MapSet.union(AtomVMModules.available())

    missing =
      for module <- modules(),
          called <- calls(module),
          called not in available,
          do: {module, called}

    assert missing == [], """
    These calls have no module on AtomVM. They compile, and they will fail on
    the device with `Failed load module`:

    #{Enum.map_join(missing, "\n", fn {from, to} -> "  #{inspect(from)} calls #{inspect(to)}" end)}
    """
  end

  # Mix tasks are build tooling: they run on the host, are never packed into an
  # archive, and calling `File` or `Path` from one is correct.
  defp modules do
    :nerves_hub_link_atomvm_esp32_ex
    |> modules_of()
    |> Enum.reject(&String.starts_with?(inspect(&1), "Mix.Tasks."))
  end

  defp modules_of(app) do
    _ = Application.load(app)
    {:ok, modules} = :application.get_key(app, :modules)
    modules
  end

  # `imports` is every remote call the module makes, which is exactly the set
  # that has to resolve at load time.
  defp calls(module) do
    {:ok, {^module, [imports: imports]}} = :beam_lib.chunks(beam(module), [:imports])

    imports |> Enum.map(fn {called, _function, _arity} -> called end) |> Enum.uniq()
  end

  # Not `:code.which/1`: under `mix test --cover` that returns `:cover_compiled`
  # rather than a path, and `:beam_lib` then fails with `:enoent` on a file
  # called "cover_compiled.beam". This test is the one that stops a
  # device-breaking call reaching a board, so it has to keep working in the mode
  # people run before they trust their test suite.
  defp beam(module) do
    app = Application.get_application(module)

    app
    |> Application.app_dir("ebin")
    |> Path.join("#{module}.beam")
    |> String.to_charlist()
  end
end
