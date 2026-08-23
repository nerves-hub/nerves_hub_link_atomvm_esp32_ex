defmodule NervesHubLink.LoggerTest do
  use ExUnit.Case, async: true

  alias NervesHubLink.Logger, as: Log

  @levels [:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug]

  describe "safe/1" do
    # The reason this module exists. AtomVM's logger raises badarg on a binary
    # before any handler sees it, and Elixir strings are binaries.
    test "a binary becomes a charlist" do
      assert Log.safe("started") == ~c"started"
    end

    test "a charlist and a map are already what logger wants" do
      assert Log.safe(~c"started") == ~c"started"
      assert Log.safe(%{event: :retrying}) == %{event: :retrying}
    end

    # An ugly line beats a missing one, and beats taking down the caller.
    test "anything else is rendered rather than dropped" do
      assert to_string(Log.safe({:not, :loggable})) == "{:not, :loggable}"
      assert to_string(Log.safe(42)) == "42"
    end

    test "unicode survives the conversion" do
      assert Log.safe("naïve café") |> to_string() == "naïve café"
    end
  end

  describe "levels" do
    test "every level logger has is available, and takes a binary" do
      for level <- @levels do
        assert apply(Log, level, ["a message"]) == :ok
      end
    end

    test "every level takes a format string and arguments" do
      for level <- @levels do
        assert apply(Log, level, ["~s is ~p", [~c"answer", 42]]) == :ok
      end
    end

    test "a level can be chosen at runtime" do
      assert Log.log(:info, "a message") == :ok
      assert Log.log(:info, "~s", [~c"a message"]) == :ok
    end
  end
end
