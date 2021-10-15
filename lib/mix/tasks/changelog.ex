defmodule Mix.Tasks.Changelog do
  @moduledoc """
  Aggregates a changelog from GitHub pull requests present in each commit.
  """
  @shortdoc "Generates a changelog"
  @requirements ["app.start"]

  use Mix.Task

  alias Realleasy

  @impl Mix.Task
  def run([rc_branch] = args) do
    Mix.shell().info(Enum.join(args, " "))
    Realleasy.prepare_changelog(rc_branch)
  end

  def run([rc_branch, "into", base_branch] = args) do
    Mix.shell().info(Enum.join(args, " "))
    Realleasy.prepare_changelog(rc_branch, base_branch)
  end
end
