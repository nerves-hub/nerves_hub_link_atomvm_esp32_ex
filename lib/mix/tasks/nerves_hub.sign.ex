defmodule Mix.Tasks.NervesHub.Sign do
  @shortdoc "Sign a packbeam archive with the organization's firmware key"

  @moduledoc """
  Sign a packbeam archive so a device configured with `firmware_keys` will
  install it.

      mix nerves_hub.sign --key ~/keys/fwup-key.priv

  Packbeam has no signature format of its own, so this appends an entry named
  `nerves_hub/signature` after everything it signs. The entry is a data file,
  the class AtomVM skips when looking for code, so a signed archive still boots
  on a stock VM.

  The key is the organization's existing fwup private key. An fwup private key
  is a 32 byte Ed25519 seed followed by its public key, and that trailing half
  is byte for byte the `.pub` NervesHub already stores, so signing packbeams
  adds no key management.

  ## Signing every build

  Chain it onto the packbeam alias, and signing stops being a step anyone can
  forget:

      aliases: [
        "atomvm.packbeam": ["atomvm.application_bin", "atomvm.packbeam", "nerves_hub.sign"]
      ]

  A build then needs the key present, so a contributor without it cannot build
  at all and CI has to be given one before anything works. That is the trade,
  and it is the reason this is not wired up for you.

  ## Options

    * `--key` - path to the private key. Defaults to `$NERVES_HUB_FW_PRIVATE_KEY`
    * `--in` - archive to sign. Defaults to `<app>.avm` in the project root
    * `--out` - where to write it. Defaults to signing in place
    * `--check` - verify and report, changing nothing

  A path, never the key itself. `mix.exs` is committed, and a key in an
  environment variable is readable in process listings and tends to end up in
  CI logs.
  """

  use Mix.Task

  @env "NERVES_HUB_FW_PRIVATE_KEY"

  @impl true
  def run(argv) do
    {options, _rest} =
      OptionParser.parse!(argv,
        strict: [key: :string, in: :string, out: :string, check: :boolean]
      )

    archive = Keyword.get_lazy(options, :in, &default_archive/0)

    File.exists?(archive) ||
      Mix.raise("no such archive: #{archive}. Run mix atomvm.packbeam first")

    if Keyword.get(options, :check, false),
      do: check(archive, options),
      else: sign(archive, options)
  end

  defp sign(archive, options) do
    seed = private_key(options)
    contents = File.read!(archive)
    out = Keyword.get(options, :out, archive)

    case :nh_signature.sign(contents, seed) do
      {:ok, signed} ->
        File.write!(out, signed)
        verify!(out, seed)

        Mix.shell().info([
          :green,
          "* signed ",
          :reset,
          "#{Path.relative_to_cwd(out)} (+#{byte_size(signed) - byte_size(contents)} bytes)"
        ])

      {:error, reason} ->
        Mix.raise("could not sign #{archive}: #{inspect(reason)}")
    end
  end

  # Immediately, and against the archive as written rather than the bytes in
  # memory. A signature that does not verify is worth finding here rather than
  # on a device that refuses the update.
  defp verify!(path, seed) do
    {public, _seed} = :crypto.generate_key(:eddsa, :ed25519, seed)

    case :nh_signature.verify(File.read!(path), [public]) do
      {:ok, _key} ->
        :ok

      {:error, reason} ->
        Mix.raise("signed #{path}, and the signature does not verify: #{inspect(reason)}")
    end
  end

  defp check(archive, options) do
    seed = private_key(options)
    {public, _seed} = :crypto.generate_key(:eddsa, :ed25519, seed)

    case :nh_signature.verify(File.read!(archive), [public]) do
      {:ok, _key} ->
        Mix.shell().info([:green, "* valid ", :reset, Path.relative_to_cwd(archive)])

      {:error, reason} ->
        Mix.raise("#{Path.relative_to_cwd(archive)}: #{inspect(reason)}")
    end
  end

  defp private_key(options) do
    path =
      Keyword.get(options, :key) || System.get_env(@env) ||
        Mix.raise("""
        No signing key. Pass --key, or set #{@env}.

        Both take a path. Never the key itself: a key in an environment
        variable is readable in process listings and tends to end up in CI
        logs.
        """)

    File.exists?(path) || Mix.raise("no such key: #{path}")

    case :nh_signature.private_key(File.read!(path)) do
      {:ok, seed} -> seed
      {:error, reason} -> Mix.raise("#{path}: #{inspect(reason)}")
    end
  end

  defp default_archive do
    app = Mix.Project.config()[:app] || Mix.raise("no :app in mix.exs")
    "#{app}.avm"
  end
end
