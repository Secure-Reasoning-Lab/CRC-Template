# crs-finder-codex

Codex CLI bug-finding CRS integrated into `CRC-Template`. The agent inspects
the target source and available boot-time evidence, crafts candidate inputs,
verifies them with `libCRS run-pov`, and writes verified PoVs to the framework
submission directory.

This directory was imported from Team Atlanta's
[`crs-bug-finding-codex`](https://github.com/Team-Atlanta/crs-bug-finding-codex)
repository with its Git history preserved. The exact upstream revision and the
local migration boundary are recorded in the repository-root provenance
document.

The local CRS identity is `crs-finder-codex`. Upstream example compose files
remain as reference material; deployment and model routing are intentionally
owned by the outer OSS-CRS or CRSBench configuration.

## Runtime outline

1. `finder.py` fetches optional diff, seed, and bug-candidate inputs.
2. `agents/codex.py` writes target-specific `AGENTS.md` instructions and starts
   `codex exec` in non-interactive mode.
3. The agent verifies candidate inputs through the provided libCRS tools.
4. Verified files written under `/work/povs/` are submitted by the libCRS
   directory watcher.

The checked-in manifest supports full and delta mode for C, C++, and JVM
targets with the address sanitizer on x86-64.

## Defaults

The prepared image pins `@openai/codex` to `0.144.3`. The agent defaults to
`gpt-5.6-sol` with `model_reasoning_effort = "xhigh"`. Override these with
`CODEX_CLI_VERSION`, `CODEX_MODEL`, or `CODEX_MODEL_REASONING_EFFORT` in the
CRS compose configuration when a run requires different values.
