defmodule Realleasy do
  require Logger

  alias ChangelogHelper
  alias GitHelper
  alias GitHubHelper

  def prepare_changelog(rc_branch, base_branch \\ nil, opts \\ []) do
    base_branch = get_base_branch(base_branch)
    changelog_file = get_changelog_file()

    stash_first? = Keyword.get(opts, :stash_first?, false)

    # save current branch name
    {:ok, current_branch} = GitHelper.get_current_git_branch()

    if stash_first? do
      # git stash --include-untracked
      :ok = GitHelper.stash_current_git_changes()
    end

    # fetch --prune
    with :ok <- GitHelper.fetch_git_changes(),
         # git checkout RC branch
         :ok <- GitHelper.checkout_git_branch(rc_branch),
         # get last tag
         {:ok, prev_tag} <- GitHelper.get_most_recent_git_tag(),
         # find commits beween last tag and head of develop or commit hash and present them to the user
         {:ok, commit_hashes} <- GitHubHelper.get_commits_between_refs(base_branch, rc_branch),
         # ask for a version bump (i.e. major, minor, patch)
         {:ok, answer} <- prompt_version_bump(prev_tag),
         {:ok, new_version} <- bump_version(prev_tag, answer),
         {:ok, changelog} <- ChangelogHelper.read_changelog(changelog_file),
         :ok <- ChangelogHelper.validate_new_version(changelog, new_version),
         # fetch all PRs {pr_number, pr_url, pr_desc}
         {:ok, pull_requests} <- GitHubHelper.fetch_gh_pull_requests(commit_hashes),
         {:ok, changes} <- ChangelogHelper.parse_pr_descriptions(pull_requests),
         # generate Changelog section
         {:ok, new_changelog} <-
           ChangelogHelper.render_changelog(new_version, changes, Date.utc_today()),
         # prepend to existing changelog
         :ok <- ChangelogHelper.write_changelog(changelog, new_changelog, changelog_file),
         # ask for confirmation
         :ok <- prompt_changelog_confirmation(),
         # commit changelog
         :ok <- GitHelper.git_unstage_all(),
         :ok <- GitHelper.git_add(changelog_file),
         :ok <- GitHelper.git_commit("Update Changelog for #{new_version} release"),
         # push to remote
         :ok <- GitHelper.git_push(rc_branch) do
      :ok
    else
      {:error, _reason} = error ->
        error
    end

    if stash_first? do
      :ok = GitHelper.checkout_git_branch(current_branch)
      :ok = GitHelper.unstash_current_git_changes()
    end
  end

  # Internal

  defp get_base_branch(nil), do: Application.get_env(:realleasy, :default_base_branch)
  defp get_base_branch(base_branch), do: base_branch

  defp get_changelog_file, do: Application.get_env(:realleasy, :default_changelog_file)

  defp prompt_version_bump(current_version) do
    IO.puts("Current version: #{current_version}")

    "Select version bump (major|minor|[patch]): "
    |> IO.gets()
    |> String.trim()
    |> String.downcase()
    |> case do
      answer when answer in ["major", "minor", "patch"] -> {:ok, answer}
      "" -> {:ok, "patch"}
      other when is_binary(other) -> {:error, {:invalid_version_type, other}}
    end
  end

  defp bump_version(<<"v"::binary(), current_version::binary()>>, bump_type) do
    [major, minor, patch] = String.split(current_version, ".")

    case bump_type do
      "major" ->
        new_major = bump_digit(major)
        {:ok, "v#{new_major}.#{minor}.#{patch}"}

      "minor" ->
        new_minor = bump_digit(minor)
        {:ok, "v#{major}.#{new_minor}.#{patch}"}

      "patch" ->
        new_patch = bump_digit(patch)
        {:ok, "v#{major}.#{minor}.#{new_patch}"}

      type ->
        Logger.error("""
        Invalid change type selected. Valid types are 'major', 'minor' and 'patch'

        Given a version number MAJOR.MINOR.PATCH, increment the:

        1. MAJOR version when you make incompatible API changes,
        2. MINOR version when you add functionality in a backwards compatible manner, and
        3. PATCH version when you make backwards compatible bug fixes.

        More info at https://semver.org
        """)

        {:error, {:invalid_bump_type, type}}
    end
  end

  defp bump_digit(digit) when is_binary(digit) do
    {int_digit, _} = Integer.parse(digit)
    int_digit + 1
  end

  defp prompt_changelog_confirmation do
    "Please verify the changes to CHANGELOG.md and type 'OK' to continue: "
    |> IO.gets()
    |> String.trim()
    |> String.upcase()
    |> case do
      "OK" -> :ok
      other when is_binary(other) -> {:error, :changelog_not_confirmed}
    end
  end
end
