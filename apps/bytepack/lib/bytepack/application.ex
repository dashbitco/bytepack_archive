defmodule Bytepack.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    topologies = Application.fetch_env!(:libcluster, :topologies)

    children = [
      {Cluster.Supervisor, [topologies, [name: Bytepack.ClusterSupervisor]]},
      {Finch,
       name: Bytepack.Finch,
       pools: %{
         :default => [size: 10, count: 2],
         "https://api.postmarkapp.com" => [size: 10, count: 2],
         "https://storage.googleapis.com" => [size: 20, count: 4]
       }},
      goth_spec(),
      Bytepack.Repo,
      {Phoenix.PubSub, name: Bytepack.PubSub},
      Bytepack.Extensions.Plug.DevStore
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Bytepack.Supervisor)
  end

  defp goth_spec() do
    name = Bytepack.Goth

    case Application.fetch_env(:bytepack, :goth_credentials) do
      {:ok, credentials} ->
        {Goth,
         name: name,
         http_client: {Goth.HTTPClient.Finch, name: Bytepack.Finch},
         credentials: Jason.decode!(credentials)}

      :error ->
        %{id: name, start: {Function, :identity, [:ignore]}}
    end
  end
end
