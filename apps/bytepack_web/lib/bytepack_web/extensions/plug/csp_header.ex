defmodule BytepackWeb.Extensions.Plug.CSPHeader do
  @moduledoc """
  Adds header and assign needed for implementing Content Security Policy (CSP).
  Detailed information about CSP and its directives can be found at: https://content-security-policy.com/

  ## Options

  * `:csp_directives` - required list of CSP directives. For example:

      [
        {"default-src", "'self'"},
        {"style-src", :nonce},
        {"script-src", :nonce},
        {"font-src", "data:"}
      ]

  * `:report_uri` - optional uri to which CSP violations will be reported.

  * `:report_only_mode` - `false` by default. If set to `true` security policy will not be enforced, but all violations will be reported to the `report-uri`.

  """

  import Plug.Conn

  @csp_header_name "content-security-policy"
  @csp_header_name_report_only "content-security-policy-report-only"

  def init(opts) do
    base_directives = Keyword.fetch!(opts, :csp_directives)

    directives =
      case opts[:report_uri] do
        nil -> base_directives
        report_uri -> [{"report-uri", report_uri} | base_directives]
      end

    %{
      directives: directives,
      report_only_mode: Keyword.get(opts, :report_only_mode, false)
    }
  end

  def call(conn, config) do
    nonce = secure_random_string()
    header_value = csp_header_value(nonce, config)

    conn
    |> put_resp_header(csp_header_name(config), IO.iodata_to_binary(header_value))
    |> assign(:csp_nonce, nonce)
  end

  defp csp_header_name(%{report_only_mode: true}), do: @csp_header_name_report_only
  defp csp_header_name(_), do: @csp_header_name

  defp csp_header_value(nonce, config) do
    Enum.map_intersperse(config.directives, "; ", &csp_header_directive(&1, nonce))
  end

  defp csp_header_directive({directive_name, directive_value}, nonce) do
    entries =
      directive_value
      |> List.wrap()
      |> Enum.map_intersperse(?\s, fn
        :nonce -> ["'nonce-", nonce, ?']
        binary -> binary
      end)

    [directive_name, ?\s | entries]
  end

  defp secure_random_string() do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
