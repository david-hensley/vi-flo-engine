# Migrations

One-off scripts that alter the structure or contents of the database, kept
separate from `/tools/` so that live utilities and spent scripts are never
confused for each other.

A script here has already been run. It is retained only so the change it made
is legible, and it will be deleted at the next version tag.

## The rule

**Applied on every machine, and released?** Delete it. Git history keeps it if
anyone ever needs to see what was done, and the change itself is recorded in
`CHANGELOG.md`.

**Not yet applied everywhere?** Leave it. A second machine that has not run a
migration still needs the script.

Each file carries an `APPLIED:` line recording when it was run.

## What a migration should do

Every script here follows the same shape, and new ones should too:

- **Back up first.** Before touching anything, so a failure is recoverable.
- **Detect prior application** and exit cleanly. Safe to run twice.
- **Read with `read.csv()`**, not `load_zentra_metadata()`. Reading raw keeps
  every column a character string, so untouched values are written back
  byte-identical and no datetime is silently reformatted.
- **Verify afterwards** and say what it checked. Where a migration renames
  files, verification should confirm that every path recorded in the logs
  still resolves to a file that exists - that is the check which catches a
  half-completed rename.
- **Never guess.** A new column is left blank rather than filled with a
  plausible value. An invented value looks authoritative and will never be
  questioned.

Where a migration is risky enough to want a preview, give it a `dry_run`
argument defaulting to `TRUE`, as `migrate_fb1_to_fb2.R` does.

## Applied

| Script | Applied | What it did |
|---|---|---|
| `migrate_download_type.R` | 2026-08-23 | Added `download_type` to `download_log.csv`, backfilling existing rows as `automatic` |
| `migrate_add_model.R` | 2026-08-26 | Added `model` to `device_metadata.csv`, positioned after `mfger`, left blank |
| `migrate_fb1_to_fb2.R` | 2026-08-26 | Renamed station `fb1_vwc1` to `fb2_vwc1` across metadata, logs, archived files, and photos |
