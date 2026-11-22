# VI-FLO Engine: Contributor Guide

How work on the engine actually happens: setting a machine up, the loop for a
change, and the rules the code depends on. The README says what the engine
does; this says how to change it without breaking it.

---

## Setting up a machine

Once per computer:

1. **Install** R 4 or later (RStudio recommended), Git, and rclone configured
   with the Box remote (see `RCLONE_SETUP.md` in VI-FLO Tools)
2. **Clone** this repository and
   [VI-FLO Tools](https://github.com/david-hensley/vi-flo-tools) beside it
3. **Run `setup_win.exe`** from this repository. It sets the environment
   variables (`VI_FLO_ENGINE_ROOT`, `VI_FLO_DATA_ROOT`) and writes this
   machine's `datamap_engine.csv`, which never travels between machines
4. **Add the ZentraCloud key** with `tools/set_api_tokens.py`. It goes in
   `api_tokens.csv`, which git ignores - never commit it
5. **Install the R packages**: `zentraR`, `jsonlite`, and for the tests
   `testthat` and `withr`

---

## The loop for a change

1. **Pull first**, with VI-FLO Tools' Pull tab - git, and Box if the data
   may have moved. Two machines that both changed the same file make a merge
   to sort out; pulling first avoids most of them
2. **Start a session**: `source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
   "code/start.R"))`. It loads everything and says what state things are in,
   including whether the metadata is valid
3. **Make the change**, small and one thing at a time
4. **Try it on a copy** if it touches a metadata manager workflow:
   `source("tools/sandbox.R")`, `sandbox_start()`, run the workflow,
   `sandbox_changes()` to see what it did, `sandbox_end()`
5. **Run the tests**: `source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"),
   "tests/run_tests.R"))`. Every test must pass. A fixed bug arrives with the
   test that would have caught it
6. **Write the CHANGELOG entry** under `## [Unreleased]` - what changed and
   why, for someone with no context. Group it under Added, Changed or Fixed
7. **Commit and push with VI-FLO Tools**: Push tab, Engine, a one-line
   message, *Upload data to Box* ticked if the data changed. After the
   upload it offers to clear retired product files from Box; it asks before
   deleting anything. GitHub runs the tests again on the push

A change to code Product 2 runs makes its files stale, and the weekly job
rebuilds them. `build_p2_stale(dry_run = TRUE)` shows what a change will
cost before you commit it. A build refuses uncommitted code, so commit first.

---

## Releases

Versions follow the product ladder rather than strict semantic versioning -
see *Versions ahead* in `docs/ROADMAP.md`. To release:

1. Rename `## [Unreleased]` in `CHANGELOG.md` to `## [vX.Y] - YYYY-MM-DD`, and
   update the status line at the top of the README
2. Move that version's migrations from *In progress* to *Applied* in
   `tools/migrations/README.md`, and delete the spent scripts
3. Commit and push with VI-FLO Tools, with *Version update* ticked and the
   version typed. It pushes the commit first and tags it after, so the tag
   always names a commit already on GitHub

---

## Migrations

A change to a table's shape, or a one-off repair of its contents, is a script
in `tools/migrations/`. Its README sets out the rules: back up first, safe to
run twice, read raw, write through the data layer, verify afterwards, never
guess a value. In practice:

1. Run it as a **dry run** first - `dry_run = TRUE` is the default - and read
   what it would do
2. **Apply** it: `dry_run = FALSE`
3. Mark it **APPLIED** with the date, in the script's header and the README
4. Run it on **every machine** before deleting it at the next release

---

## Rules the code depends on

Each of these exists because breaking it once caused a real problem. Several
are enforced by a test, which fails if they are broken.

- **Every table goes through the data layer.** `read_table()`,
  `write_table()` and `append_rows()` in `table_functions.R`, where
  `TABLE_SCHEMA` describes each table once - its columns, their types, its
  key. Nothing reads or writes a metadata CSV itself
- **A save never makes the metadata worse.** `write_table()` runs the
  validation and refuses a save that adds a problem. A change made of several
  saves goes inside `with_metadata_change()`, so it is checked once at the
  end and rolled back whole if it fails
- **Statuses are defined once**, in `table_functions.R`
  (`ACTIVE_STATUSES`, `TERMINAL_STATUSES`, `STATUS_MEANINGS`). A list of
  status words spelled out anywhere else fails a test
- **ZentraCloud is reached only through `zc_call()`.** The test suite closes
  it, so no test can touch the real account. A `zentraR::` call anywhere else
  fails a test
- **Devices are named, not numbered.** Show a logger with `device_label()`
  ("Glynn weather (z6-12866)") or `device_display_name()`; a bare serial
  means nothing to whoever reads it
- **A deployment ends everything on it.** Ports close and surveys stay with
  the deployment they were measured on; retiring a row goes through
  `retire_row()`, with the moment the logger actually left
- **Times are local to the project** (`America/Puerto_Rico`) on screen and in
  products, UTC in logs - each column says which
- **Workflows are tested by their answers.** A metadata manager workflow test
  feeds scripted answers through `with_inputs()` and checks what the workflow
  left in the tables and logs, in a throwaway root from
  `local_test_root()`

---

## When git needs a hand

VI-FLO Tools covers the everyday cases. When it reports something it cannot
resolve:

- **Push rejected - "fetch first"**: another machine pushed since you last
  pulled. Pull (git only), then push again
- **Merge conflict on pull**: git has marked the clashing lines in the named
  files between `<<<<<<<`, `=======` and `>>>>>>>`. Keep the right version of
  each, delete the marker lines, and commit - the commit finishes the merge
- **"Unable to create index.lock"**: another git process is running, or one
  crashed. Close other git programs; if it persists, delete `.git/index.lock`
