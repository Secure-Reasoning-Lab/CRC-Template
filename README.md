# CRC-Template

`CRC-Template` is a starter repository for running Finder-to-Patcher Cyber Reasoning System (CRS) workflows with [OSS-CRS](https://github.com/ossf/oss-crs). It includes Claude Code and Codex implementations that share the same local workflow and artifact layout.

## Included CRSes

| Agent | Finder | Patcher |
| --- | --- | --- |
| Claude Code | `crs/crs-finder-claude-code` | `crs/crs-patcher-claude-code` |
| Codex | `crs/crs-finder-codex` | `crs/crs-patcher-codex` |

The E2E wrappers run the selected Finder, collect its submitted PoVs, and pass them to the matching Patcher.

## Submission Manifest

[`submission.yaml`](submission.yaml) identifies the Finder and Patcher that form the submission.
Both paths are relative to the repository root and must point to OSS-CRS-compatible source directories containing `oss-crs/crs.yaml`.

```yaml
schema_version: 1

submission:
  name: my-crs

crs:
  finder:
    path: crs/my-finder
  patcher:
    path: crs/my-patcher
```

The selected Finder must declare `type: [bug-finding]`; the selected Patcher must declare `type: [bug-fixing]`.
Model dependencies belong in each CRS's `required_llms` declaration.
Runtime resources, credentials, timeouts, budgets, and benchmark selection are supplied by the evaluator.

Files under `configs/` are local execution profiles used by the scripts in this repository.
They are not part of the evaluation policy.

## Requirements

- Linux with Git and submodule support
- [uv](https://docs.astral.sh/uv/)
- Docker Engine with Docker Compose v2
- At least 8 logical CPUs and approximately 24 GB of memory for the default configuration
- An upstream OpenAI-compatible LLM endpoint and API key

## Configure the LLM Endpoint

Create a root `.env` file from the provided example:

```bash
cp .env.example .env
```

Set the endpoint and key:

```dotenv
LITELLM_UPSTREAM_BASE_URL=https://api.example.com/v1
LITELLM_UPSTREAM_API_KEY=...
```

The checked-in configurations start an OSS-CRS-managed LiteLLM proxy using `configs/litellm-config.yaml`. The upstream endpoint must expose `gpt-5.5`, `gpt-5.4`, and `gpt-5.4-mini`; the LiteLLM config pins input, cached-input, and output prices for those models.

Claude Code OAuth is also supported. Comment out the complete `llm_config` block in `configs/finder-claude-code.yaml` and `configs/patcher-claude-code.yaml`, set `CLAUDE_CODE_OAUTH_TOKEN` in `.env`, and run the Claude wrapper with `--auth-mode oauth`.

## Setup

Run the setup script to initialize the OSS-CRS submodule and check local prerequisites:

```bash
./scripts/setup.sh
```

Use `./scripts/setup.sh --check` to check the current setup without changing submodule state.

## Bundled Smoke Target

`targets/sanity-mock-c-delta-01` contains the blinded project files and `ref.diff` from the CRSBench synthetic C sanity fixture. Ground truth is not included.

## Run the Claude Code E2E

```bash
./scripts/run-claude-e2e.sh \
  --fuzz-proj-path "$PWD/targets/sanity-mock-c-delta-01" \
  --target-harness fuzz_parse_buffer_section \
  --diff "$PWD/targets/sanity-mock-c-delta-01/ref.diff" \
  --finder-timeout 720 \
  --patcher-timeout 720 \
  --finder-early-exit \
  --patcher-early-exit
```

## Run the Codex E2E

```bash
./scripts/run-codex-e2e.sh \
  --fuzz-proj-path "$PWD/targets/sanity-mock-c-delta-01" \
  --target-harness fuzz_parse_buffer_section \
  --diff "$PWD/targets/sanity-mock-c-delta-01/ref.diff" \
  --finder-timeout 720 \
  --patcher-timeout 720 \
  --finder-early-exit \
  --patcher-early-exit
```

Run either wrapper with `--help` to see all target, evidence, timeout, work-directory, and output options.

## Run a Single Stage

Run the default Claude Code Finder:

```bash
./scripts/run-finder.sh \
  --fuzz-proj-path /path/to/oss-fuzz/project \
  --target-harness example_fuzzer \
  --diff /path/to/ref.diff
```

Run the default Claude Code Patcher with existing PoVs:

```bash
./scripts/run-patcher.sh \
  --fuzz-proj-path /path/to/oss-fuzz/project \
  --target-harness example_fuzzer \
  --diff /path/to/ref.diff \
  --pov-dir /path/to/povs
```

Use `--compose-file` and `--crs-name` to select a different checked-in CRS configuration.

## Outputs

OSS-CRS build and run state is stored under `generated/oss-crs-work/`. Completed E2E bundles are exported under `submissions/<target>/e2e-<id>/` with Finder and Patcher artifact metadata, staged PoVs, and submitted patches.

Use the included helpers to inspect or export a completed run:

```bash
./scripts/print-artifacts.sh --help
./scripts/collect-submission.sh --help
```

Clean generated state with:

```bash
./scripts/clean.sh --phase run
./scripts/clean.sh --artifacts --yes
```


## Upstream Sources

The integrated CRSes retain their upstream Git histories. Source revisions and import details are listed in [docs/upstream-provenance.md](docs/upstream-provenance.md).
