defmodule Mix.Tasks.Changelog do
  @moduledoc """
  Generate a log of changes before releasing a new version of an application.
  """
  @shortdoc "Generates a changelog"
  @requirements ["app.start"]

  use Mix.Task

  alias Realleasy

  @impl Mix.Task
  def run([rc_branch]) do
    Realleasy.prepare_changelog(rc_branch)
  end

  def run([rc_branch, "into", base_branch]) do
    Realleasy.prepare_changelog(rc_branch, base_branch)
  end

  def run(_args) do
    IO.puts("""
    Invalid arguments. Please run:
      mix changelog <rc-branch>
    or
      mix changelog <rc-branch> into <base-branch>
    """)
  end
end
