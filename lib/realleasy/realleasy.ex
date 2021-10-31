defmodule Realleasy do
  @moduledoc """
  Finds all commits between `rc_branch` and `base_branch`, prompts for a new version
  and extracts Changelog information from each commit's PR description.
  """
  require Logger

  alias ChangelogHelper
  alias GitHelper
  alias GitHubHelper

  @doc """
  Inserts a new release in the `CHANGELOG.md` file with a log of changes.
  Optionally commits and pushed to a remote origin.
  """
  @spec prepare_changelog(String.t(), String.t() | nil, Keyword.t()) :: :ok | {:error, any()}
  def prepare_changelog(rc_branch \\ nil, base_branch \\ nil, opts \\ []) do
    # Make sure Hackney is started
    Application.ensure_all_started(:hackney)

    base_branch = base_branch || "main"
    changelog_file = Keyword.get(opts, :changelog, "CHANGELOG.md")

    # save current branch name
    {:ok, current_branch} = GitHelper.get_current_git_branch()
    rc_branch = rc_branch || current_branch

    try do
      with :ok <- maybe_stash(opts),
           :ok <- GitHelper.fetch_git_changes(),
           # fetch --prune
           # git checkout RC branch
           :ok <- GitHelper.checkout_git_branch(rc_branch),
           # get last tag
           {:ok, prev_tag} <- GitHelper.get_most_recent_git_tag(base_branch),
           # find commits beween last tag and head of base_branch or commit hash and present them to the user
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
           :ok <- maybe_commit_changelog(changelog_file, new_version, rc_branch, opts) do
        :ok
      else
        {:error, reason} ->
          Logger.error("Failed to generate the Changelog: #{inspect(reason)}")
          :error
      end
    rescue
      e in RuntimeError ->
        Logger.error("Error generating the Changelog: #{e.message}")
        :error

      error ->
        Logger.error("Error generating the Changelog: #{inspect(error)}")
        :error
    end

    :ok = maybe_unstash(current_branch, opts)
  end

  # Internal

  defp maybe_stash(opts) do
    stash? = Keyword.get(opts, :stash, false)

    with true <- stash?,
         # git stash --include-untracked
         :ok <- GitHelper.stash_current_git_changes() do
      :ok
    else
      false ->
        :ok

      {:error, _reason} = error ->
        error
    end
  end

  defp maybe_unstash(current_branch, opts) do
    stash? = Keyword.get(opts, :stash, false)

    with true <- stash?,
         :ok <- GitHelper.checkout_git_branch(current_branch),
         :ok <- GitHelper.unstash_current_git_changes() do
      :ok
    else
      false ->
        :ok

      {:error, _reason} = error ->
        error
    end
  end

  defp maybe_commit_changelog(changelog_file, new_version, rc_branch, opts) do
    commit? = Keyword.get(opts, :commit, false)
    push? = Keyword.get(opts, :push, false)

    with true <- commit? or push?,
         # ask for confirmation
         :ok <- prompt_changelog_confirmation(),
         # commit changelog
         :ok <- GitHelper.git_unstage_all(),
         :ok <- GitHelper.git_add(changelog_file),
         :ok <- GitHelper.git_commit("Update Changelog for #{new_version} release"),
         :ok <- maybe_push_commit(rc_branch, opts) do
      :ok
    else
      false ->
        :ok

      {:error, _reason} = error ->
        error
    end
  end

  defp maybe_push_commit(rc_branch, opts) do
    push? = Keyword.get(opts, :push, false)

    with true <- push?,
         # push to remote
         :ok <- GitHelper.git_push(rc_branch) do
      :ok
    else
      false ->
        :ok

      {:error, _reason} = error ->
        error
    end
  end

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
        {:ok, "v#{new_major}.0.0"}

      "minor" ->
        new_minor = bump_digit(minor)
        {:ok, "v#{major}.#{new_minor}.0"}

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
