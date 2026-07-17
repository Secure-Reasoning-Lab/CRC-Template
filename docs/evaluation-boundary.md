# Evaluation Boundary

## Purpose

`CRC-Template` is a team development repository. It makes it practical to build
and run a CRS locally, inspect OSS-CRS artifacts, and export a repeatable
submission bundle. It is not the organizer's source of truth for a finding,
patch, score, or leaderboard result.

## Local Self-Check

The local workflow has useful but limited checks:

1. `scripts/setup.sh --check` validates the checked-in Finder and Patcher
   compose/manifests without requiring Docker or credentials.
2. `scripts/run-finder.sh` drives OSS-CRS preparation, target building, and a
   finder run for a selected harness.
3. `scripts/run-patcher.sh` accepts startup evidence and produces a local patch
   artifact only after the Patcher submits a non-empty `.diff`.
4. `scripts/run-claude-e2e.sh` and `scripts/run-codex-e2e.sh` serialize the two
   components through one shared OSS-CRS implementation: they resolve Finder
   PoVs, stage them as Patcher startup input, and export a local handoff bundle.
5. `scripts/print-artifacts.sh` and `scripts/collect-submission.sh` resolve a
   selected compose entry through the OSS-CRS JSON interface and export an
   individual CRS run.

The Finder prompts agents to use `libCRS run-pov` before writing a PoV. That is
an implementation-level gate, not an independent organizer verification
result. A local target image, source override, Docker version, and framework
revision can all differ from the official evaluation environment.

## Organizer Evaluation

The organizer-controlled evaluation service should pin and own:

- benchmark and OSS-Fuzz inputs
- source and patch variants
- CRSBench and OSS-CRS revisions
- execution limits and isolation policy
- result retention, deduplication, and scoring rules

Independent organizer checks determine whether a PoV triggers the intended
variant and whether a patch fixes the verified vulnerability without
unacceptable regressions. Those checks and their infrastructure are not part
of this participant-facing repository.

## Interface Between Repositories

The development repository should export only reproducible artifacts and
metadata. For an individual Finder or Patcher run, `collect-submission.sh`
writes:

```text
artifacts.json
collection-metadata.txt
povs/
seeds/
bug-candidates/
patches/
oss-crs-submission.tar.gz
```

The local E2E wrapper produces a separate bundle containing both stage artifact
JSON files, staged PoVs, exported patches, and `handoff-metadata.json`. It does
not combine the two independent OSS-CRS archives into an official submission:
each stage has its own compose and work directory. The organizer should define
the accepted combined schema, validate it, and retain the mapping between a
Finder result and a Patcher result.

The organizer should validate its accepted submission schema independently. It
should not trust a team-local `verified` label, timing report, or archive layout
as a score. Keeping this boundary explicit lets teams iterate on CRS
implementations without coupling organizer policy or private benchmark
material into `CRC-Template`.
