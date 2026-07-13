# CRC-Template

`CRC-Template` is the local development repository for Cyber Reasoning System
(CRS) implementations. It keeps the OSS-CRS framework as one submodule and
keeps CRS implementations in this repository as normal source trees. The
currently integrated Claude Code workflow is:

```text
crs/crs-finder-claude-code
            -> submitted PoVs
crs/crs-patcher-claude-code
```

The equivalent Codex CRS sources are also integrated:

```text
crs/crs-finder-codex
            -> submitted PoVs
crs/crs-patcher-codex
```

All four CRSes are imported with their Team Atlanta Git histories preserved
through non-squashed `git subtree` merges. The checked-in root wrappers and
deployment configs currently exercise the Claude workflow; Codex deployment
and model routing can be supplied by outer OSS-CRS or CRSBench configuration.

## Prerequisites

- Git with submodule support
- [uv](https://docs.astral.sh/uv/)
- Docker Engine with Docker Compose v2 and a reachable daemon
- An OSS-Fuzz-format target directory containing `Dockerfile` and `build.sh`
- At least eight CPUs and roughly 24 GB of available memory for the checked-in
  development compose allocation
- A Claude Code OAuth token available as `CLAUDE_CODE_OAUTH_TOKEN`

Create an ignored root `.env` file or export the token in the shell:

```bash
CLAUDE_CODE_OAUTH_TOKEN=...
```

The checked-in Claude compose files deliberately omit `llm_config`; they use
Claude Code OAuth instead of an OSS-CRS-managed LiteLLM sidecar. The token
placeholder is defined in each CRS run module, not the team-level compose entry,
so it is not passed into target build containers.

## Setup

Initialize the framework and inspect the local machine:

```bash
./scripts/setup.sh
```

`./scripts/setup.sh --check` does not alter submodule state. It validates both
local Claude compose files and manifests without Docker, then reports missing
runtime prerequisites. Each compose uses a relative `source.local_path`; all
root scripts change to the repository root before calling OSS-CRS so that path
is stable.

## Claude End-To-End Run

Run the supported development workflow against one harness:

```bash
./scripts/run-claude-e2e.sh \
  --fuzz-proj-path /path/to/oss-fuzz/projects/example \
  --target-harness example_fuzzer \
  --e2e-id example-full-001
```

The wrapper runs the Finder to completion, resolves its submitted PoVs through
`oss-crs artifacts`, safely flattens them into a staging directory, then starts
the Patcher with `--pov-dir`. The two stages use separate work directories and
separate build/run IDs because the Patcher fetches input only at startup and
must build its own CRS-specific target output. It fails if the Finder submits no
PoV or if the Patcher submits no non-empty `.diff`.

For a delta challenge, pass the delta evidence to both stages:

```bash
./scripts/run-claude-e2e.sh \
  --fuzz-proj-path /path/to/oss-fuzz/projects/example \
  --target-source-path /path/to/example-source \
  --target-harness example_fuzzer \
  --diff /path/to/ref.diff \
  --seed-dir /path/to/seeds \
  --e2e-id example-delta-001
```

The resulting local bundle contains Finder/Patcher artifact JSON, staged PoVs,
exported patches, and handoff metadata below:

```text
submissions/<target>/e2e-<e2e-id>/
```

It is an implementation artifact, not a CRSBench result.

## Finder Run

Run a full-source finder campaign against one harness:

```bash
./scripts/run-finder.sh \
  --fuzz-proj-path /path/to/oss-fuzz/projects/example \
  --target-harness example_fuzzer \
  --run-id example-full-001
```

The wrapper runs `prepare`, `build-target`, and `run`, with all framework state
under `generated/oss-crs-work/` by default. It generates matching build/run IDs
when they are not supplied and prints the authoritative `oss-crs artifacts`
JSON after the run.

For delta analysis, pass the same diff to both the target build and run phase:

```bash
./scripts/run-finder.sh \
  --fuzz-proj-path /path/to/oss-fuzz/projects/example \
  --target-source-path /path/to/example-source \
  --target-harness example_fuzzer \
  --diff /path/to/ref.diff \
  --seed-dir /path/to/seeds \
  --run-id example-delta-001
```

The `--source-override` alias is available for `--target-source-path`. Use
`--early-exit` only when stopping at the first submitted PoV is intended. OSS-
CRS returns exit code `124` for a timeout or early exit; the wrapper still
prints artifacts before returning that code.

## Patcher Run

Run the Patcher directly when evidence already exists:

```bash
./scripts/run-patcher.sh \
  --fuzz-proj-path /path/to/oss-fuzz/projects/example \
  --target-harness example_fuzzer \
  --pov-dir /path/to/povs \
  --run-id example-patch-001
```

It accepts `--pov`, `--pov-dir`, `--diff`, `--seed-dir`,
`--bug-candidate`, and `--bug-candidate-dir`. At least one evidence input is
required. The Patcher wrapper treats a successful no-output run as failure;
only non-empty `.diff` artifacts count as a local patch result.

The checked-in Patcher Bake defaults to local image tags. Do not use
`oss-crs prepare --publish` until its `REGISTRY` is explicitly set to a
registry owned by the derived project.

## Artifacts And Export

Resolve a completed run without guessing workdir paths:

```bash
./scripts/print-artifacts.sh \
  --fuzz-proj-path /path/to/oss-fuzz/projects/example \
  --target-harness example_fuzzer \
  --run-id example-full-001
```

Pass `--crs-name` when resolving a non-Finder compose entry. For example,
Patcher paths are under:

```text
.crs["crs-patcher-claude-code"]
```

Export submitted files and create a framework archive:

```bash
./scripts/collect-submission.sh \
  --crs-name crs-patcher-claude-code \
  --fuzz-proj-path /path/to/oss-fuzz/projects/example \
  --target-harness example_fuzzer \
  --run-id example-patch-001 \
  --compose-file configs/patcher-claude-code.yaml \
  --work-dir generated/oss-crs-work/patcher-claude-code
```

By default this writes copied artifact directories, `artifacts.json`, collection
metadata, and `oss-crs-submission.tar.gz` below:

```text
submissions/<target>/<crs-name>/<resolved-run-id>/
```

Use `--include-all` when the archive should additionally contain exchange data
and logs. The exported directory is local development output and is ignored by
Git.

To remove framework state or Docker resources, use the safe interactive wrapper:

```bash
./scripts/clean.sh --phase run
./scripts/clean.sh --artifacts --yes
```

## Evaluation Boundary

This repository provides developer-facing execution and local self-checks. A
file in `SUBMIT_DIR/povs/`, or a locally reproducible crash, is useful evidence
but is not an organizer score or a final vulnerability verdict.

Organizer-authoritative evaluation belongs in a separate `CRC-Evaluate`
repository backed by CRSBench. That environment owns benchmark versions, ground
truth, scoring policy, and verification. It should run `crsbench verify` for
PoVs and `crsbench patch-verify` for patches against the organizer-controlled
benchmark package. See [docs/evaluation-boundary.md](docs/evaluation-boundary.md).

## Provenance

The Finder and Patcher were imported from Team Atlanta with Git subtree history
preserved. Their upstream revisions, import commits, and licensing follow-up
are recorded in [docs/upstream-provenance.md](docs/upstream-provenance.md).
