# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later

defmodule NervesHubLinkTest do
  use ExUnit.Case, async: true

  # The Erlang agent opens a socket through whatever `:transport` names, so a
  # module that refuses to open is enough to test everything up to that point.
  defmodule RefusingTransport do
    def open(_config), do: {:error, :refused}
  end

  defp options(extra) do
    Keyword.merge(
      [
        identifier: "dev-1",
        shared_secret: {"nhp_key", "secret"},
        firmware: :none,
        transport: RefusingTransport,
        handler: self()
      ],
      extra
    )
  end

  describe "child_spec/1" do
    test "is a worker started from start_link" do
      spec = NervesHubLink.child_spec(options([]))

      assert %{id: NervesHubLink, type: :worker, restart: :permanent} = spec
      assert {NervesHubLink, :start_link, [_options]} = spec.start
    end

    # The default handler is the calling process, which under a supervisor is
    # the supervisor: a mailbox nothing reads. Failing here is the whole point
    # of having a child_spec at all.
    test "refuses to build a spec without a handler" do
      options = Keyword.delete(options([]), :handler)

      assert_raise ArgumentError, ~r/needs a :handler when supervised/, fn ->
        NervesHubLink.child_spec(options)
      end
    end
  end

  # Worth knowing before putting this under a supervisor: the agent starts
  # before it connects, so a refused connection is a crash after a successful
  # start rather than an error from start_link. A supervisor sees a restart,
  # not a startup failure.
  describe "start_link/1" do
    test "takes a keyword list" do
      Process.flag(:trap_exit, true)

      # Reaching the transport at all means the config was accepted.
      assert {:ok, agent} = NervesHubLink.start_link(options([]))
      assert_receive {:nerves_hub, {:transport_error, :refused}}
      assert_receive {:EXIT, ^agent, {:transport_error, :refused}}
    end

    test "reports a config it cannot use" do
      options = Keyword.delete(options([]), :identifier)

      assert {:error, {:missing_config, [:identifier]}} = NervesHubLink.start_link(options)
    end

    test "url and host together is an error, not a precedence rule" do
      options = options(url: "wss://a.example.com", host: "b.example.com")

      assert {:error, {:conflicting_config, [:url, :host]}} = NervesHubLink.start_link(options)
    end
  end
end
