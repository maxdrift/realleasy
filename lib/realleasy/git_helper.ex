defmodule GitHelper do
  def get_current_git_branch do
    case System.cmd("git", ["branch", "--show-current"]) do
      {branch_name, 0} -> {:ok, String.trim(branch_name)}
      {_result, _status_code} = error -> {:error, error}
    end
  end

  def stash_current_git_changes do
    case System.cmd("git", ["stash", "--include-untracked"]) do
      {_result, 0} -> :ok
      {_result, _status_code} = error -> {:error, error}
    end
  end

  def unstash_current_git_changes do
    case System.cmd("git", ["stash", "pop"]) do
      {_result, 0} -> :ok
      {_result, _status_code} = error -> {:error, error}
    end
  end

  def fetch_git_changes do
    case System.cmd("git", ["fetch", "--prune", "origin"]) do
      {_result, 0} -> :ok
      {_result, _status_code} = error -> {:error, error}
    end
  end

  def get_random_branch_name(length \\ 10, prefix \\ "release-", suffix \\ "") do
    s = for _ <- 1..length, into: "#{prefix}", do: <<Enum.random('0123456789abcdef')>>
    "#{s}#{suffix}"
  end

  def checkout_git_branch(branch_name, opts \\ []) do
    base_branch = Keyword.get(opts, :base_branch)
    opt_arguments = if not is_nil(base_branch), do: [base_branch], else: []

    case System.cmd("git", ["checkout", "-B", branch_name] ++ opt_arguments) do
      {_result, 0} -> :ok
      {_result, _status_code} = error -> {:error, error}
    end
  end

  def get_most_recent_git_tag do
    case System.cmd("git", ["describe", "--tags", "--abbrev=0"]) do
      {tag, 0} -> {:ok, String.trim(tag)}
      {_result, _status_code} = error -> {:error, error}
    end
  end

  def git_unstage_all do
    case System.cmd("git", ["reset"]) do
      {_message, 0} -> :ok
      {_result, _status_code} = error -> {:error, error}
    end
  end

  def git_add(filenames) when is_list(filenames) do
    Enum.reduce_while(filenames, :ok, fn filename, _acc ->
      case git_add(filename) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  def git_add(filename) when is_binary(filename) do
    case System.cmd("git", ["add", filename]) do
      {"", 0} -> :ok
      {"", 128} -> {:error, {:not_found, filename}}
      {_result, _status_code} = error -> {:error, error}
    end
  end

  # Update Changelog for #{versopm} release
  def git_commit(message, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    opt_arguments = if dry_run, do: ["--dry-run"], else: []

    case System.cmd("git", ["commit", "-S", "-m", message] ++ opt_arguments) do
      {_, 0} -> :ok
      {_result, _status_code} = error -> {:error, error}
    end
  end

  def git_push(remote_branch, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    opt_arguments = if dry_run, do: ["--dry-run"], else: []

    case System.cmd("git", ["push", "-u", "origin", remote_branch] ++ opt_arguments) do
      {_, 0} -> :ok
      {_result, _status_code} = error -> {:error, error}
    end
  end

  def git_tag(version, commit, message) do
    case System.cmd("git", ["tag", "-a", "-m", message, version, commit]) do
      {_, 0} -> :ok
      {_result, _status_code} = error -> {:error, error}
    end
  end
end
