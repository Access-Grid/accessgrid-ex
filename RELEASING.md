# Releasing

Steps to publish a new version of the AccessGrid Elixir SDK to Hex.

## 1. Bump the version

Update the version in `mix.exs`:

```elixir
version: "0.2.0",
```

## 2. Update the CHANGELOG

Add a new section to `CHANGELOG.md` with the version and a summary of changes.

## 3. Run checks

```bash
mix test
mix format --check-formatted
mix credo --strict
mix dialyzer
mix hex.build
```

Review the `mix hex.build` output to confirm the package contents look correct.

## 4. Commit and merge

```bash
git add mix.exs CHANGELOG.md
git commit -m "bump version to 0.2.0"
```

Merge to main via PR or direct push per your workflow.

## 5. Tag the release

```bash
git tag v0.2.0
git push origin v0.2.0
```

## 6. Create a GitHub Release

```bash
gh release create v0.2.0 --generate-notes
```

This auto-generates the title and release notes from merged PRs since the last tag. You can also create it manually in the GitHub UI at https://github.com/Access-Grid/accessgrid-ex/releases/new.

## 7. Publish to Hex

```bash
mix hex.publish
```

This will prompt for confirmation before uploading. You need a valid `HEX_API_KEY` — generate one at https://hex.pm/dashboard/keys or run `mix hex.user auth`.
