defmodule GitHubHelper do
  use Tesla, only: [:get, :post], docs: false

  require Logger

  @commits_endpoint "/repos/:owner/:repo/commits/:commit_sha/pulls"
  @compare_endpoint "/repos/:owner/:repo/compare/:base...:head"
  @pull_requests_endpoint "/repos/:owner/:repo/pulls"
  @pull_request_merge_endpoint "/repos/:owner/:repo/pulls/:pull_number/merge"

  adapter Tesla.Adapter.Hackney

  plug Tesla.Middleware.BaseUrl, "https://api.github.com"
  plug Tesla.Middleware.PathParams
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Headers, [{"Accept", "application/vnd.github.groot-preview+json"}]
  plug Tesla.Middleware.BasicAuth, get_basic_auth()

  def get_commits_between_refs(base, head \\ "develop") do
    path_params = Keyword.merge(get_base_params(), base: base, head: head)

    case get(@compare_endpoint, opts: [path_params: path_params]) do
      {:ok, %Tesla.Env{body: body}} ->
        commits = body["commits"] || []

        IO.puts("The following commits will be included in the release:")

        commit_hashes =
          commits
          # Reject commits with more than one parent (should match "merge commits")
          |> Enum.reject(fn commit ->
            parents = commit["parents"] || []
            Enum.count(parents) > 1
          end)
          |> Enum.map(fn commit ->
            date = commit["commit"]["author"]["date"]
            hash = commit["sha"]
            {short_hash, _rest} = String.split_at(hash, 7)
            author = commit["commit"]["author"]["name"]
            [message | _rest] = String.split(commit["commit"]["message"], "\n")
            IO.puts("#{date} – #{short_hash} – #{author} – #{message}")

            hash
          end)

        {:ok, commit_hashes}

      {:error, _reason} = error ->
        error
    end
  end

  def fetch_gh_pull_requests(commit_hashes) when is_list(commit_hashes) do
    commit_hashes
    |> Enum.reduce_while({:ok, []}, &fetch_gh_pull_request/2)
    |> case do
      {:ok, results} ->
        {:ok, Enum.reverse(results)}

      {:error, _reason} = error ->
        error
    end
  end

  def open_gh_pull_request(target_branch, base_branch, title, description, opts \\ []) do
    draft? = Keyword.get(opts, :draft?, false)

    req_body = %{
      "head" => target_branch,
      "base" => base_branch,
      "title" => title,
      "body" => description,
      "draft" => draft?
    }

    case post(@pull_requests_endpoint, req_body, opts: [path_params: get_base_params()]) do
      {:ok, %Tesla.Env{body: body}} ->
        {:ok, body["number"]}

      {:error, _reason} = error ->
        error
    end
  end

  def check_gh_pull_request_merged(pull_number) do
    path_params = Keyword.merge(get_base_params(), pull_number: pull_number)

    case get(@pull_request_merge_endpoint, opts: [path_params: path_params]) do
      {:ok, %Tesla.Env{status: 204}} ->
        {:ok, true}

      {:ok, %Tesla.Env{status: 404}} ->
        {:ok, false}

      {:error, _reason} = error ->
        error
    end
  end

  def wait_until_pr_merged(pr_number, timeout \\ 60_000) do
    case check_gh_pull_request_merged(pr_number) do
      {:ok, false} ->
        Logger.info(
          "PR ##{pr_number} was not merged yet. Re-checking in #{timeout / 1000} seconds."
        )

        :timer.sleep(timeout)
        wait_until_pr_merged(pr_number)

      {:ok, true} ->
        Logger.info("PR ##{pr_number} was merged.")
        :ok

      {:error, _reason} = error ->
        error
    end
  end

  # Internal

  defp get_config do
    Application.get_env(:realleasy, :github)
  end

  defp get_config(key) do
    config = get_config()
    Keyword.get(config, key)
  end

  defp get_basic_auth do
    [username: get_config(:username), password: get_config(:token)]
  end

  defp get_base_params do
    [owner: get_config(:repo_owner), repo: get_config(:repo_name)]
  end

  defp fetch_gh_pull_request(commit_hash, {:ok, acc}) do
    path_params = Keyword.merge(get_base_params(), commit_sha: commit_hash)

    case get(@commits_endpoint, opts: [path_params: path_params]) do
      {:ok, %Tesla.Env{body: body}} ->
        [pull_request] =
          Enum.filter(body, fn pr -> pr["state"] == "closed" and not is_nil(pr["merged_at"]) end)

        pr_number = pull_request["number"]
        pr_url = pull_request["html_url"]
        pr_desc = pull_request["body"]

        {:cont, {:ok, [{pr_number, pr_url, pr_desc} | acc]}}

      {:error, _reason} = error ->
        {:halt, error}
    end
  end
end
