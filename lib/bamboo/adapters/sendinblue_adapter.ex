defmodule Bamboo.SendinblueAdapter do
  @moduledoc """
  Sends email using SendInBlue's API.

  Use this adapter to send emails through SendInBlue's API. Requires that an API
  key and a domain are set in the config.

  ## Example config

      # In config/config.exs, or config.prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.SendinblueAdapter,
        api_key: "my_api_key"

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  @base_uri "https://api.sendinblue.com/v3/"
  @behaviour Bamboo.Adapter

  alias Bamboo.Email

  defmodule ApiError do
    defexception [:message]

    def exception(%{headers: headers, body: body, response: response}) do
      filtered_header = headers |> Poison.decode! |> Map.put("api-key", "[FILTERED]")
      decoded_body = body |> Poison.decode!

      message = """
      There was a problem sending the email through the SendInBlue API.

      Here is the response:

      #{inspect response, limit: :infinity}


      Here are the headers we sent:

      #{inspect filtered_header, limit: :infinity}

      Here is the body we sent:

      #{inspect decoded_body, limit: :infinity}
      """
      %ApiError{message: message}
    end
    def exception(reason), do: %ApiError{message: reason}
  end

  def deliver(email, config) do
    body = email |> to_sendinblue_body |> Poison.encode!

    case :hackney.post(full_uri(), headers(config), body, [:with_body]) do
      {:ok, status, _headers, response} when status > 299 ->
        raise(ApiError, %{body: body, headers: headers(config), response: response})
      {:ok, status, headers, response} ->
        %{status_code: status, headers: headers, body: response}
      {:error, reason} ->
        raise(ApiError, inspect(reason))
    end
  end

  @doc false
  def handle_config(config) do
    if config[:api_key] in [nil, ""] do
      raise_api_key_error(config)
    else
      config
    end
  end

  @doc false
  def supports_attachments?, do: true

  defp to_sendinblue_body(%Email{} = email) do
    %{
      sender: sender_params(email),
      to: recipients(email.to),
      cc: recipients(email.cc),
      bcc: recipients(email.bcc),
      replyTo: sender_params(email),
      htmlContent: email.html_body,
      textContent: email.text_body,
      subject: email.subject,
      attachment: attachments(email)
    }
  end

  defp attachments(%{attachments: attachments}) do
    # "attachment":[{"name":"Junk","url":"www.google.com/junk.png"}]
    attachments
    |> Enum.map(fn(attachment) ->
      %{
        name: attachment.filename,
        content: Base.encode64(attachment.data)
      }
    end)
  end
  defp attachments(_), do: nil

  defp recipients(recips) do
    [] |> put_recipients(recips)
  end
  defp put_recipients(recipients, new_recipients) do
    Enum.reduce(new_recipients, recipients, fn(recipient, recipients) ->
      recipients ++ [%{
        name: recipient |> elem(0),
        email: recipient |> elem(1)
        }]
    end)
  end
  defp sender_params(email) do
    %{
      name: email.from |> elem(0),
      email: email.from |> elem(1)
    }
  end

  defp get_key(config) do
    case Map.get(config, :api_key) do
      nil -> raise_api_key_error(config)
      key -> key
    end
  end

  defp headers(config) do
    [
      {"content-type", "application/json"},
      {"api-key", get_key(config)}
    ]
  end

  defp raise_api_key_error(config) do
    raise ArgumentError, """
    There was no API key set for the SendInBlue adapter.

    * Here are the config options that were passed in:

    #{inspect config}
    """
  end

  defp full_uri do
    Application.get_env(:bamboo, :sendinblue_base_uri, @base_uri) <> "/smtp/email"
  end
end
