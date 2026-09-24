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

defmodule NervesHubLinkWrappersTest do
  use ExUnit.Case, async: true

  # Every function the agent offers has a counterpart here, so nobody has to
  # notice which ones are missing and reach for `:nerves_hub_link` instead.
  test "wraps everything the agent exports" do
    agent = :nerves_hub_link.module_info(:exports) -- [module_info: 0, module_info: 1]
    wrapped = NervesHubLink.__info__(:functions)

    missing = for {name, arity} <- agent, not wrapped?(wrapped, name, arity), do: {name, arity}
    assert missing == []
  end

  # A default argument can stand in for the shorter arity.
  defp wrapped?(wrapped, name, arity),
    do: {name, arity} in wrapped or {name, arity + 1} in wrapped

  describe "update decisions" do
    test "go to the agent as messages" do
      :ok = NervesHubLink.ignore_update(self(), "on battery")
      assert_receive {:update_decision, {:ignore, "on battery"}}

      :ok = NervesHubLink.reschedule_update(self(), 60_000, "busy")
      assert_receive {:update_decision, {:reschedule, 60_000, "busy"}}

      :ok = NervesHubLink.apply_update(self(), %{"firmware_url" => "u"})
      assert_receive {:update_decision, {:apply, %{"firmware_url" => "u"}}}
    end
  end

  describe "device-managed updates" do
    # Answers one call the way the agent does, and nothing more.
    defp fake_agent(reply) do
      spawn(fn ->
        receive do
          {:call, from, tag, request} -> send(from, {tag, reply.(request)})
        end
      end)
    end

    test "check_for_update/1 asks and returns the answer" do
      agent = fake_agent(fn :check_update -> {:ok, %{available: false, firmware_meta: :null}} end)
      assert {:ok, %{available: false}} = NervesHubLink.check_for_update(agent)
    end

    test "request_update/1 passes a refusal through" do
      agent = fake_agent(fn :request_update -> {:error, :no_update} end)
      assert {:error, :no_update} = NervesHubLink.request_update(agent)
    end

    test "set_update_mode/2 sends the mode as NervesHub spells it" do
      agent = fake_agent(fn {:set_update_mode, mode} -> {:ok, mode} end)
      assert {:ok, "device_managed"} = NervesHubLink.set_update_mode(agent, :device_managed)
    end

    test "set_update_mode/2 refuses a mode a device may not set" do
      assert {:error, {:invalid_update_mode, :off}} = NervesHubLink.set_update_mode(self(), :off)
    end

    test "update_mode/1 returns what the agent last heard" do
      agent = fake_agent(fn :update_mode -> {:error, :unknown} end)
      assert {:error, :unknown} = NervesHubLink.update_mode(agent)
    end
  end
end
