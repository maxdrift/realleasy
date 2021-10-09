import Config

config :realleasy,
  default_base_branch: "main",
  default_changelog_file: "CHANGELOG.md",
  github: [
    username: System.get_env("GITHUB_USERNAME"),
    token: System.get_env("GITHUB_TOKEN"),
    repo_owner: "maxdrift",
    repo_name: "realleasy"
  ]
