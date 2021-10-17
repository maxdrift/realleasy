# Realleasy

Mix command to generate a log of changes before releasing a new version of an application.

Finds all commits between `rc_branch` and `base_branch`, prompts for a new version
and extracts Changelog information from each commit's PR description.
Finally inserts a new release in the `CHANGELOG.md` file with a log of changes.
Optionally commits and pushed to a remote origin.

## Installation

The package can be installed by adding `realleasy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:realleasy, "~> 0.2.2"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/realleasy](https://hexdocs.pm/realleasy).
