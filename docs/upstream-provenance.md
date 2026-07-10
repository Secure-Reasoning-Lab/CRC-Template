# Upstream Provenance

## Claude Code Finder

The current Finder source at `crs/crs-finder-claude-code/` was imported from:

```text
https://github.com/Team-Atlanta/crs-bug-finding-template
```

The imported upstream revision is:

```text
9aaff24e79cb1a45dab3ab076ccf5b694f947dbb
```

It was integrated by the Git subtree merge commit:

```text
d3b714372452074788249b2aa2bc61ccde6b177f
```

That commit records `git-subtree-dir: crs/crs-finder-claude-code` and
`git-subtree-split: 9aaff24e79cb1a45dab3ab076ccf5b694f947dbb`. The upstream
commit remains a parent of the merge commit, so later changes to the imported
tree can be reviewed against the exact imported source with ordinary Git tools.

At the time of integration, the upstream `main` branch resolved to that same
revision. The imported tree contains 56 tracked files from the upstream commit.

## Attribution And License Follow-Up

The imported upstream `pyproject.toml` declares `license = "MIT"` and names
Team Atlanta as the author. The imported revision does not include a standalone
`LICENSE` file. Preserve the upstream attribution in future changes and confirm
the complete redistribution license record before publishing a derived Finder
outside this development repository.

The Finder has local integration changes after the subtree baseline: renamed
metadata/package identity, a supported libFuzzer-only production path, OAuth
run-module configuration, reliable final artifact submission, and root-level
OSS-CRS wrappers. Review them directly with:

```bash
git diff 9aaff24..HEAD -- crs/crs-finder-claude-code
```

Keep future local changes in ordinary commits after the import merge so this
upstream-to-local delta remains auditable.
