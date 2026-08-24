# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later

defmodule Kiosk.MixProject do
  use Mix.Project

  def project do
    [
      app: :kiosk,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: deps(),
      aliases: ["atomvm.packbeam": ["atomvm.application_bin", "atomvm.packbeam"]],
      # ExAtomVM reads these when it builds the packbeam and flashes.
      atomvm: [
        start: Kiosk,
        # main.avm. Must match the table on the device, not this repo's
        # partitions.csv -- see the note there.
        flash_offset: 0x270000
      ]
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp deps do
    [
      {:exatomvm, github: "atomvm/exatomvm", runtime: false},
      # The Elixir API this example exists to exercise.
      {:nerves_hub_link_atomvm_esp32_ex, path: "../.."},
      # Both rebar3 projects, so mix is told which manager to use.
      {:nerves_hub_link_atomvm_esp32,
       github: "nerves-hub/nerves_hub_link_atomvm_esp32", manager: :rebar3, override: true},
      {:atomvm_websocket_client,
       github: "nerves-hub/atomvm_websocket_client", manager: :rebar3, override: true}
    ]
  end
end
