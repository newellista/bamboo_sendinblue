defmodule Bamboo.SendinblueAdapterTest do
  use ExUnit.Case

  @config %{adapter: Bamboo.SendinblueAdapter, api_key: "123_abc"}
  @config_with_bad_key %{adapter: Bamboo.SendinblueAdapter, api_key: nil}

  defmodule FakeSendinblue do
    use Plug.Router

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison
    plug :match
    plug :dispatch

    def start_server(parent) do
      Agent.start_link(fn -> Map.new end, name: __MODULE__)
      Agent.update(__MODULE__, &Map.put(&1, :parent, parent))
      port = get_free_port()
      Application.put_env(:bamboo, :sendinblue_base_uri, "http://localhost:#{port}")
      Plug.Adapters.Cowboy.http __MODULE__, [], port: port, ref: __MODULE__
    end

    defp get_free_port do
      {:ok, socket} = :ranch_tcp.listen(port: 0)
      {:ok, port} = :inet.port(socket)
      :erlang.port_close(socket)
      port
    end

    def shutdown do
      Plug.Adapters.Cowboy.shutdown __MODULE__
    end

    post "/smtp/email" do
      case get_in(conn.params, ["sender", "email"]) do
        "INVALID_EMAIL" -> conn |> send_resp(500, "Error!") |> send_to_parent
        _ -> conn |> send_resp(200, "SENT") |> send_to_parent
      end
    end

    defp send_to_parent(conn) do
      parent = Agent.get(__MODULE__, fn(set) -> Map.get(set, :parent) end)
      send parent, {:fake_sendinblue, conn}
      conn
    end
  end

  setup do
    FakeSendinblue.start_server(self())

    on_exit fn ->
      FakeSendinblue.shutdown
    end
  end

  test "raises if the api key is nil" do
    assert_raise ArgumentError, ~r/no API key set/, fn ->
      new_mail(from: "foo@bar.com") |> Bamboo.SendinblueAdapter.deliver(@config_with_bad_key)
    end

    assert_raise ArgumentError, ~r/no API key set/, fn ->
      Bamboo.SendinblueAdapter.handle_config(%{})
    end
  end

  test "deliver/2 correctly formats recipients" do
    email = new_mail(
      to: [{"To", "to@bar.com"}, {"To2", "to2@bar.com"}],
      cc: [{"CC", "cc@bar.com"}],
      bcc: [{"BCC", "bcc@bar.com"}]
    )

    email |> Bamboo.SendinblueAdapter.deliver(@config)

    assert_receive {:fake_sendinblue, %{params: params}}
    assert params["to"] == [
      %{"name" => "To", "email" => "to@bar.com"},
      %{"name" => "To2", "email" => "to2@bar.com"},
    ]
    assert params["cc"] == [
      %{"name" => "CC", "email" => "cc@bar.com"},
    ]
    assert params["bcc"] == [
      %{"name" => "BCC", "email" => "bcc@bar.com"},
    ]
  end

  defp new_mail(attrs) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Bamboo.Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses
  end
end
