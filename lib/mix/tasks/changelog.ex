defmodule Mix.Tasks.Changelog do
  @moduledoc """
  Generate a log of changes before releasing a new version of an application.
  """
  @shortdoc "Generates a changelog"
  @requirements ["app.start"]

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Realleasy.CLI.main(["changelog" | argv])
end
