defmodule ChangelogHelper do
  require Logger

  @pr_changelog_pattern ~r/## Changelog\s+### Added\s+(?<added>(?>\s*\*.+)*)\s+### Changed\s+(?<changed>(?>\s*\*.+)*)\s+### Fixed\s+(?<fixed>(?>\s*\*.+\s)*)/

  def parse_pr_descriptions(pull_requests) do
    Enum.reduce_while(pull_requests, {:ok, {[], [], []}}, &parse_pr_description/2)
  end

  def render_changelog(new_version, {all_added, all_changed, all_fixed}, release_date \\ nil) do
    all_added = join_changelog_entries(all_added)
    all_changed = join_changelog_entries(all_changed)
    all_fixed = join_changelog_entries(all_fixed)

    deployed_on =
      if release_date do
        " (Deployed on #{Date.to_iso8601(release_date)})"
      else
        ""
      end

    new_changelog = """
    ## #{new_version}#{deployed_on}

    ### Added
    #{all_added}
    ### Changed
    #{all_changed}
    ### Fixed
    #{all_fixed}
    """

    IO.puts("""
    -------------- New Changelog --------------
    #{new_changelog}
    ------------ End New Changelog ------------
    """)

    {:ok, new_changelog}
  end

  def read_changelog(file) do
    case File.read(file) do
      {:ok, lines} ->
        prev_changelog =
          lines
          |> String.split("# CHANGELOG", trim: true)
          |> hd()
          |> String.trim_leading()

        {:ok, prev_changelog}

      {:error, _reason} = error ->
        error
    end
  end

  def validate_new_version(changelog, new_version) do
    if version_in_changelog?(changelog, new_version) do
      Logger.error("Version #{new_version} is already present in the Changelog.")
      {:error, {:version_exists, new_version}}
    else
      :ok
    end
  end

  def write_changelog(prev_changelog, next_changelog, file) do
    full_changelog = """
    # CHANGELOG

    #{next_changelog}
    #{prev_changelog}
    """

    File.write(file, full_changelog)
  end

  # Internal

  defp parse_pr_description(
         {pr_number, pr_link, pr_description},
         {:ok, {all_added, all_changed, all_fixed}}
       ) do
    case Regex.named_captures(@pr_changelog_pattern, pr_description) do
      %{
        "added" => added,
        "changed" => changed,
        "fixed" => fixed
      } ->
        added = add_pr_number_to_line(added, pr_number, pr_link)
        changed = add_pr_number_to_line(changed, pr_number, pr_link)
        fixed = add_pr_number_to_line(fixed, pr_number, pr_link)
        # Store Changelog entries in reverse order like in the final result
        {:cont, {:ok, {[added | all_added], [changed | all_changed], [fixed | all_fixed]}}}

      nil ->
        Logger.error("""
        Error: Changelog malformed or not found in PR ##{pr_number}.
        #{pr_link}
        """)

        {:halt, {:error, {pr_number, :changelog_not_found}}}
    end
  end

  defp add_pr_number_to_line(change_group, pr_number, pr_link) do
    change_group
    # split text block by line
    |> String.split("\n")
    # add PR number link if Changelog item starts with `*` i.e. it's not a child change like single dependencies
    |> Enum.map(fn
      <<"*", _rest::binary()>> = line -> "#{String.trim(line)} ([##{pr_number}](#{pr_link}))"
      line -> String.trim_trailing(line)
    end)
    |> Enum.join("\n")
    |> String.trim()
  end

  defp join_changelog_entries(entries) do
    entries
    |> Enum.reject(fn e -> e == "" or String.starts_with?(e, "* [example]") end)
    |> Enum.join("\n")
    |> case do
      "" -> ""
      str_entries -> "\n#{str_entries}\n"
    end
  end

  defp version_in_changelog?(changelog, version) do
    String.contains?(changelog, "## #{version}")
  end
end
