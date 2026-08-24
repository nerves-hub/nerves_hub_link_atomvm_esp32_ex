# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later

defmodule Mix.Tasks.NervesHub.SignTest do
  use ExUnit.Case, async: false

  @task Mix.Tasks.NervesHub.Sign

  # The smallest thing `nh_signature` will sign: the packbeam magic and the
  # terminator entry, with no modules in between.
  @archive <<"#!/usr/bin/env AtomVM\n", 0, 0, 0::96, "end", 0>>

  setup do
    dir = Path.join(System.tmp_dir!(), "nh-sign-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    {public, seed} = :crypto.generate_key(:eddsa, :ed25519)

    # fwup's layout: a seed followed by its public key, base64 with a newline.
    key = Path.join(dir, "fwup-key.priv")
    File.write!(key, Base.encode64(seed <> public) <> "\n")

    archive = Path.join(dir, "app.avm")
    File.write!(archive, @archive)

    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    %{dir: dir, key: key, archive: archive, public: public}
  end

  test "signs in place, and the result verifies", context do
    @task.run(["--key", context.key, "--in", context.archive])

    signed = File.read!(context.archive)
    assert byte_size(signed) > byte_size(@archive)
    assert {:ok, _key} = :nh_signature.verify(signed, [context.public])
  end

  test "writes elsewhere when asked", context do
    out = Path.join(context.dir, "signed.avm")

    @task.run(["--key", context.key, "--in", context.archive, "--out", out])

    assert File.read!(context.archive) == @archive
    assert {:ok, _key} = :nh_signature.verify(File.read!(out), [context.public])
  end

  test "--check reports on a signed archive without changing it", context do
    @task.run(["--key", context.key, "--in", context.archive])
    signed = File.read!(context.archive)

    @task.run(["--key", context.key, "--in", context.archive, "--check"])

    assert File.read!(context.archive) == signed
  end

  test "--check fails on an unsigned archive", context do
    assert_raise Mix.Error, ~r/unsigned/, fn ->
      @task.run(["--key", context.key, "--in", context.archive, "--check"])
    end
  end

  # Silently doing nothing is how unsigned firmware reaches a product that
  # allows unsigned, and nobody notices until it matters.
  test "refuses to run without a key rather than skipping", context do
    System.delete_env("NERVES_HUB_FW_PRIVATE_KEY")

    assert_raise Mix.Error, ~r/No signing key/, fn ->
      @task.run(["--in", context.archive])
    end

    assert File.read!(context.archive) == @archive
  end

  test "takes the key path from the environment", context do
    System.put_env("NERVES_HUB_FW_PRIVATE_KEY", context.key)
    on_exit(fn -> System.delete_env("NERVES_HUB_FW_PRIVATE_KEY") end)

    @task.run(["--in", context.archive])

    assert {:ok, _key} = :nh_signature.verify(File.read!(context.archive), [context.public])
  end

  test "says which file is missing", context do
    assert_raise Mix.Error, ~r/no such key/, fn ->
      @task.run(["--key", Path.join(context.dir, "absent"), "--in", context.archive])
    end

    assert_raise Mix.Error, ~r/mix atomvm.packbeam/, fn ->
      @task.run(["--key", context.key, "--in", Path.join(context.dir, "absent.avm")])
    end
  end

  test "refuses a key it cannot read", context do
    bad = Path.join(context.dir, "bad.priv")
    File.write!(bad, "not a key\n")

    assert_raise Mix.Error, ~r/not_a_private_key|not_a_key/, fn ->
      @task.run(["--key", bad, "--in", context.archive])
    end
  end
end
