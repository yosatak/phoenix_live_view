defmodule Phoenix.LiveView.ChannelTest do
  alias Phoenix.LiveView.Channel
  use ExUnit.Case

  describe "find_file/3" do
    test "returns the path of the nested file" do
      params = %{
        "user" => %{
          "avatar" => %{
            "__PHX_FILE__" => "some_ref"
          }
        }
      }

      assert Channel.find_file(params, "todo", []) == ["user", "avatar"]
    end
  end
end
