defmodule StopWatch do
  @moduledoc """

  A simple stop watch for measuring execution times.

  ## Example

      iex> StopWatch.run("calling function", fn _ -> run_my_function() end)

  """

  require Logger

  def run(msg, fun) do
    {t, result} = :timer.tc(fun)
    print(msg, t)
    result
  end

  defp print(msg, t) when t < 1000 do
    Logger.info("\u001b[38;5;48m\u001b[1m#{msg}\u001b[0m\u001b[38;5;48m took #{t} µs")
  end

  defp print(msg, t) when t < 1_000_000 do
    Logger.info("\u001b[38;5;75m\u001b[1m#{msg}\u001b[0m\u001b[38;5;75m took #{div(t, 1000)} ms")
  end

  defp print(msg, t) do
    Logger.info(
      "\u001b[38;5;1m\u001b[1m#{msg}\u001b[0m\u001b[38;5;1m took #{div(t, 1_000_000)} s"
    )
  end
end
