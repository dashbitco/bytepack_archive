defmodule Bytepack.Extensions.Sentry.FinchClientTest do
  use ExUnit.Case

  @dsn Application.compile_env(:sentry, :dsn)

  test "integration" do
    bypass = Bypass.open()

    Application.put_all_env(
      sentry: [
        dsn: "http://public:secret@localhost:#{bypass.port}/1",
        included_environments: [:test, :prod],
        send_result: :sync,
        send_max_attempts: 1
      ]
    )

    Bypass.expect_once(bypass, fn conn ->
      Plug.Conn.resp(conn, 200, ~s<{}>)
    end)

    exception = RuntimeError.exception("oops")
    {:ok, _} = Sentry.capture_exception(exception)

    Bypass.down(bypass)
    assert {:error, _} = Sentry.capture_exception(exception, result: :sync)
  after
    Application.put_all_env(
      sentry: [
        dsn: @dsn,
        included_environments: [:prod],
        send_result: :none,
        send_max_attempts: 4
      ]
    )
  end
end
