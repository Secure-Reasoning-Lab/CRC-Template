# CRC-Template

`CRC-Template` is the local development repository for Cyber Reasoning System
(CRS) implementations. It keeps the OSS-CRS framework as one submodule and
keeps CRS implementations in this repository as normal source trees. The
currently integrated path is the Claude Code bug finder:

```text
crs/crs-finder-claude-code
```

The Claude patcher and both Codex directories remain placeholders. There is no
supported Claude end-to-end finder-to-patcher workflow yet.

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

The finder compose deliberately omits `llm_config`; it uses Claude Code OAuth
instead of an OSS-CRS-managed LiteLLM sidecar. The token placeholder is defined
in the Finder run module, not the team-level compose entry, so it is not passed
into the target's build containers.

## Setup

Initialize the framework and inspect the local machine:

```bash
./scripts/setup.sh
```

`./scripts/setup.sh --check` does not alter submodule state. It validates the
root compose and local Finder manifest without Docker, then reports missing
runtime prerequisites. The Finder compose uses a relative `source.local_path`;
all root scripts change to the repository root before calling OSS-CRS so that
path is stable.

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

## Artifacts And Export

Resolve a completed run without guessing workdir paths:

```bash
./scripts/print-artifacts.sh \
  --fuzz-proj-path /path/to/oss-fuzz/projects/example \
  --target-harness example_fuzzer \
  --run-id example-full-001
```

Finder-specific paths are under:

```text
.crs["crs-finder-claude-code"]
```

Export submitted files and create a framework archive:

```bash
./scripts/collect-submission.sh \
  --fuzz-proj-path /path/to/oss-fuzz/projects/example \
  --target-harness example_fuzzer \
  --run-id example-full-001
```

By default this writes copied artifact directories, `artifacts.json`, collection
metadata, and `oss-crs-submission.tar.gz` below:

```text
submissions/<target>/<resolved-run-id>/
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

The Finder was imported from Team Atlanta with Git subtree history preserved.
The upstream revision, import commit, and licensing follow-up are recorded in
[docs/upstream-provenance.md](docs/upstream-provenance.md).
