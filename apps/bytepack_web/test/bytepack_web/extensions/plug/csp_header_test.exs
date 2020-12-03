defmodule BytepackWeb.CSPHeaderTest do
  use BytepackWeb.ConnCase, async: true
  alias BytepackWeb.Extensions.Plug.CSPHeader

  test "adds header with Content Security Policy directives" do
    options = [
      csp_directives: [
        {"default-src", "'self'"},
        {"style-src", "'self'"}
      ]
    ]

    config = CSPHeader.init(options)
    conn = CSPHeader.call(build_conn(), config)

    [csp_header] = get_resp_header(conn, "content-security-policy")

    assert csp_header == "default-src 'self'; style-src 'self'"
  end

  test "generates and stores nonce" do
    options = [
      csp_directives: [
        {"default-src", "'self'"},
        {"style-src", [:nonce, "foo.bar"]},
        {"font-src", :nonce}
      ]
    ]

    config = CSPHeader.init(options)
    conn = CSPHeader.call(build_conn(), config)

    [csp_header] = get_resp_header(conn, "content-security-policy")
    nonce = conn.assigns[:csp_nonce]

    assert csp_header ==
             "default-src 'self'; style-src 'nonce-#{nonce}' foo.bar; font-src 'nonce-#{nonce}'"
  end

  test "uses report-only header when report-only mode is turned on" do
    options = [
      csp_directives: [
        {"default-src", "'self'"}
      ],
      report_only_mode: true
    ]

    config = CSPHeader.init(options)
    conn = CSPHeader.call(build_conn(), config)

    [csp_report_only_header] = get_resp_header(conn, "content-security-policy-report-only")
    assert csp_report_only_header == "default-src 'self'"
  end

  test "supports report uri" do
    options = [
      csp_directives: [
        {"default-src", "'self'"}
      ],
      report_uri: "https://example.com"
    ]

    config = CSPHeader.init(options)
    conn = CSPHeader.call(build_conn(), config)

    [csp_header] = get_resp_header(conn, "content-security-policy")
    assert csp_header == "report-uri https://example.com; default-src 'self'"
  end
end
