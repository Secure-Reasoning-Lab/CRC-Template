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

## Claude Code Patcher

The current Patcher source at `crs/crs-patcher-claude-code/` was imported from:

```text
https://github.com/Team-Atlanta/crs-claude-code
```

The imported upstream revision is:

```text
42fb600e41cb71f38f488b1ac822de58d54cc1db
```

It was integrated by the Git subtree merge commit:

```text
dc28cbace6137f028be1bc9f52c31d8c86c1ea0a
```

That commit records `git-subtree-dir: crs/crs-patcher-claude-code` and
`git-subtree-split: 42fb600e41cb71f38f488b1ac822de58d54cc1db`. The upstream
commit remains a parent of the merge commit, so the complete Team Atlanta
history is available in this repository. The import source is
`crs-claude-code`, not `crs-patch-ensemble`.

The Patcher upstream includes an MIT `LICENSE`. Preserve Team Atlanta
attribution and the license file in derived work. Local adaptation was kept in
ordinary commits after the subtree baseline: the Template-specific name,
OAuth-only run-module configuration, root compose/wrapper, and a corrected
CLI-command test assertion. Review its local delta with:

```bash
git diff 42fb600..HEAD -- crs/crs-patcher-claude-code
```

The root-level Finder-to-Patcher orchestration lives outside either imported
tree, so upstream updates can be evaluated independently of Template workflow
changes.
