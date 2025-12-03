defmodule Kronii.MCP.Adapters.Anubis.Client do
  use Anubis.Client,
    name: "Kronii",
    version: "1.0.0",
    protocol_version: "2025-06-18",
    capabilities: [:roots, :sampling]
end
