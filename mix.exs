# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later

defmodule NervesHubLink.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nerves-hub/nerves_hub_link_atomvm_esp32_ex"

  def project do
    [
      app: :nerves_hub_link_atomvm_esp32_ex,
      version: @version,
      # Not 1.15: the agent needs OTP 27 for the `json` module, and Elixir
      # gained OTP 27 support in 1.17.
      elixir: "~> 1.17",
      start_permanent: false,
      deps: deps(),
      description: "An Elixir face for the AtomVM NervesHub agent",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  # An allow list: `examples` is a whole project of its own and CI config means
  # nothing to a consumer, so neither ships.
  defp package do
    [
      licenses: ["Apache-2.0", "LGPL-2.1-or-later"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE LICENSES)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}"
    ]
  end

  # No application callback: AtomVM has no `Application`, and an app here runs
  # from the `start/0` named in its own mix.exs.
  def application do
    [extra_applications: []]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:nerves_hub_link_atomvm_esp32, "~> 0.1"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
