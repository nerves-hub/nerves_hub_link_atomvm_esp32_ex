defmodule Mix.Tasks.Atomvm.ApplicationBin do
  @moduledoc """
  Write `priv/application.bin`, the OTP application metadata NervesHub reads.

  `rebar3 atomvm packbeam` puts this in every archive it builds; ExAtomVM does
  not, and has no option to. Without it a device cannot report what it is
  running and NervesHub cannot parse an upload at all — see
  `nh_packbeam` in nerves_hub_link_atomvm_esp32.

  A `priv` file is packed as `<app>/priv/<file>`, which is exactly where both
  ends look, so supplying it here is enough.

  The contents are the bare external term format. The packer adds the four byte
  length prefix in front of every data file it stores, and writing one here too
  produces an entry with two, which decodes as nothing.

  Generated from the project's own configuration rather than written by hand,
  so the version cannot drift from mix.exs.
  """

  use Mix.Task

  @shortdoc "Write priv/application.bin from the project's app spec"

  @impl Mix.Task
  def run(_args) do
    config = Mix.Project.config()
    app = Keyword.fetch!(config, :app)

    term =
      {:application, app,
       [
         {:description, String.to_charlist(config[:description] || to_string(app))},
         {:vsn, String.to_charlist(Keyword.fetch!(config, :version))},
         {:registered, []},
         {:applications, [:kernel, :stdlib]}
       ]}

    File.mkdir_p!("priv")
    File.write!("priv/application.bin", :erlang.term_to_binary(term))

    Mix.shell().info("priv/application.bin: #{app} #{config[:version]}")
  end
end
