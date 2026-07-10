# Evaluation Boundary

## Purpose

`CRC-Template` is a team development repository. It makes it practical to build
and run a CRS locally, inspect OSS-CRS artifacts, and export a repeatable
submission bundle. It is not the organizer's source of truth for a finding,
patch, score, or leaderboard result.

## Local Self-Check

The local workflow has useful but limited checks:

1. `scripts/setup.sh --check` validates the checked-in compose and Finder
   manifest without requiring Docker or credentials.
2. `scripts/run-finder.sh` drives OSS-CRS preparation, target building, and a
   finder run for a selected harness.
3. `scripts/print-artifacts.sh` resolves `SUBMIT_DIR` and exchange paths through
   the OSS-CRS JSON interface.
4. `scripts/collect-submission.sh` copies the finder artifacts and asks
   `oss-crs archive` to create a transport archive.

The Finder prompts agents to use `libCRS run-pov` before writing a PoV. That is
an implementation-level gate, not an independent organizer verification
result. A local target image, source override, Docker version, and framework
revision can all differ from the official evaluation environment.

## Organizer Evaluation

`CRC-Evaluate` should be a separate organizer-controlled repository or service.
It should pin and own:

- benchmark and OSS-Fuzz inputs
- source and patch variants
- CRSBench and OSS-CRS revisions
- execution limits and isolation policy
- result retention, deduplication, and scoring rules

For a submitted PoV directory, the authoritative verification operation is:

```text
crsbench verify <benchmark> --pov-dir <submitted-povs>
```

For patches, the authoritative operation is:

```text
crsbench patch-verify <benchmark> --patch-dir <submitted-patches> --pov-dir <verified-povs>
```

Those commands determine whether a PoV actually triggers the intended variant
and whether a patch fixes the verified vulnerability without unacceptable
regressions. CRSBench can also provide the evaluator/queue infrastructure when
an organizer needs distributed verification.

## Interface Between Repositories

The development repository should export only reproducible artifacts and
metadata. For the current Finder, `collect-submission.sh` writes:

```text
artifacts.json
collection-metadata.txt
povs/
seeds/
bug-candidates/
patches/
oss-crs-submission.tar.gz
```

`CRC-Evaluate` should define its own accepted submission schema and validate it
before invoking CRSBench. It should not trust a team-local `verified` label,
timing report, or archive layout as a score. Keeping this boundary explicit
lets teams iterate on CRS implementations without coupling organizer policy or
private benchmark material into `CRC-Template`.
