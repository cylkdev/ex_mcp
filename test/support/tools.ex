defmodule ExMCP.TestTools.Echo do
  use ExMCP.Tool

  @impl true
  def spec do
    %{
      "name" => "echo",
      "description" => "Echoes the given text.",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{"text" => %{"type" => "string"}}
      }
    }
  end

  @impl true
  def call(%{"text" => text}), do: %{"content" => [%{"type" => "text", "text" => text}]}
  def call(_), do: %{"content" => [%{"type" => "text", "text" => ""}]}
end

defmodule ExMCP.TestTools.Accounts do
  use ExMCP.Tool

  @impl true
  def spec do
    %{
      "name" => "get_user",
      "description" => "Look up a user by id",
      "inputSchema" => %{"type" => "object", "properties" => %{"id" => %{"type" => "string"}}}
    }
  end

  @impl true
  def call(%{"id" => id}), do: %{"content" => [%{"type" => "text", "text" => "user:#{id}"}]}
end

defmodule ExMCP.TestTools.Boom do
  use ExMCP.Tool
  @impl true
  def spec, do: %{"name" => "boom", "description" => "raises", "inputSchema" => %{"type" => "object"}}
  @impl true
  def call(_), do: raise("kaboom")
end
