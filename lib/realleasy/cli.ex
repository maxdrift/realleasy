defmodule Realleasy.CLI do
  @moduledoc """
  synopsis:
    Finds all commits between `rc_branch` and `base_branch`, prompts for a new version
    and extracts Changelog information from each commit's PR description.
  usage:
    $ realleasy changelog {options}
    $ realleasy changelog {options} rc_branch
    $ realleasy changelog {options} rc_branch into base_branch
  options:
    --commit            Commit the Changelog file.
    --push              Commit (see --commit) and pushed the changes.
    --stash             Stash all changes in the current branch and restores them once the program is done.
    --changelog=<file>  Write to a custom changelog file
  """

  def main(argv \\ []) do
    {parsed, args, invalid} =
      OptionParser.parse(argv,
        strict: [stash: :boolean, commit: :boolean, push: :boolean, changelog_file: :string]
      )

    case {args, invalid} do
      {["changelog"], []} ->
        Realleasy.prepare_changelog(nil, nil, parsed)

      {["changelog", rc_branch], []} ->
        Realleasy.prepare_changelog(rc_branch, nil, parsed)

      {["changelog", rc_branch, "into", base_branch], []} ->
        Realleasy.prepare_changelog(rc_branch, base_branch, parsed)

      {[], []} ->
        IO.puts("""
        Missing command

        #{@moduledoc}
        """)

      {[cmd | _], []} ->
        IO.puts("""
        Invalid command: #{cmd}

        #{@moduledoc}
        """)

      {_args, invalid} ->
        handle_invalid_arguments(invalid)
    end
  end

  defp handle_invalid_arguments(invalid) do
    str_invalid =
      Enum.reduce(invalid, "", fn {key, value}, acc ->
        value = value || "nil"
        acc <> "#{key}: #{value}\n"
      end)

    IO.puts("""
    Invalid arguments:
      #{str_invalid}

    #{@moduledoc}
    """)
  end
end
