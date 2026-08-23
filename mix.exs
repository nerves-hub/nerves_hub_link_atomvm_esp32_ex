defmodule NervesHubLink.MixProject do
  use Mix.Project

  def project do
    [
      app: :nerves_hub_link_atomvm_esp32_ex,
      version: "0.1.0",
      # Not 1.15: the agent needs OTP 27 for the `json` module, and Elixir
      # gained OTP 27 support in 1.17.
      elixir: "~> 1.17",
      start_permanent: false,
      deps: deps(),
      description: "An Elixir face for the AtomVM NervesHub agent",
      elixirc_paths: elixirc_paths(Mix.env())
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
      # The agent itself. Everything here delegates to it, and it is a rebar3
      # project, so mix is told which manager to use.
      {:nerves_hub_link_atomvm_esp32,
       github: "nerves-hub/nerves_hub_link_atomvm_esp32", manager: :rebar3, override: true}
    ]
  end
end
