# Scheduling the weekly download

Two scheduled tasks, created on **one machine only**. The scripts live in the
repo so every clone has them, but nothing runs until the tasks exist — and they
are Windows settings, not repository files, so a second clone does nothing.

**Only one machine should run these.** Two would write `download_log.csv`
independently, and Box keeps whichever file is newer — losing the other's rows.
The `machine` column in `run_log.csv` records which computer ran each job, so
two names alternating there means a task was installed somewhere and forgotten.

---

## Before you start

Check these resolve on the machine you are setting up:

```powershell
$env:VI_FLO_ENGINE_ROOT
$env:VI_FLO_DATA_ROOT
$env:ZENTRACLOUD_V5_TOKEN.Length
Get-ChildItem "C:\Program Files\R" -Directory | Select-Object Name
```

All three variables must be set **machine-wide**, not just for your user — a
scheduled task does not inherit an interactive session's environment. If
`set_api_tokens.py` set them with `setx`, they are machine-wide already.

Note the R version from the last command; you need its path below.

---

## Task 1 — the weekly run

Open **Task Scheduler** → **Create Task** (not "Basic Task").

**General**
- Name: `VI-FLO weekly download`
- Select **Run whether user is logged on or not**
- Select **Run with highest privileges** — not strictly needed, but it avoids
  a class of permission surprises with mapped drives

**Triggers** → New
- Begin the task: **On a schedule**
- **Weekly**, Monday, **7:00 AM**
- Leave "Stop task if it runs longer than" at its default

**Actions** → New
- Action: **Start a program**
- Program: `C:\Program Files\R\R-4.4.1\bin\Rscript.exe`
  *(adjust the version)*
- Add arguments: `"%VI_FLO_ENGINE_ROOT%\code\jobs\download_job.R"`

**Conditions**
- **Untick** "Start the task only if the computer is on AC power" — a laptop on
  battery should still run it
- Tick **Wake the computer to run this task** if you want it to run while the
  machine sleeps. Leave it unticked if you would rather it waited for you,
  since the catch-up prompt below covers that case

**Settings**
- Tick **Allow task to be run on demand**
- **Untick** "Run task as soon as possible after a scheduled start is missed" —
  this is deliberate. An automatic catch-up fires at an unpredictable moment,
  possibly while somebody is writing metadata on the other machine. The prompt
  below asks instead, when a person is there to answer

---

## Task 2 — the catch-up prompt

**Create Task** again.

**General**
- Name: `VI-FLO download catch-up prompt`
- **Run only when user is logged on** — it shows a window, so it needs a desktop

**Triggers** → New
- Begin the task: **At log on**
- Delay task for: **1 minute** — so it does not compete with everything else
  starting up

**Actions** → New
- Program: `powershell.exe`
- Add arguments:

```
-WindowStyle Hidden -ExecutionPolicy Bypass -File "%VI_FLO_ENGINE_ROOT%\tools\download\check_download_due.ps1"
```

**Conditions**
- Untick the AC power condition, as above

---

## Checking it works

**The weekly task**: right-click it in Task Scheduler and choose **Run**. A
console should appear and the job run. Afterwards:

```r
tail(read.csv(file.path(wds("meta_internal"), "run_log.csv")), 1)
```

The `machine` column should name this computer.

**The prompt**: it only appears when a download is overdue, which it is not if
you have just run one. To test it, run the script by hand with the threshold
lowered:

```powershell
powershell -ExecutionPolicy Bypass -Command "& { $env:VI_FLO_TEST=1; & '$env:VI_FLO_ENGINE_ROOT\tools\download\check_download_due.ps1' }"
```

Or simply edit `$ThresholdHours` to `0` in the script, run it, see the dialog,
and set it back.

---

## Moving it to another machine

1. On the old machine: delete both tasks in Task Scheduler
2. On the new machine: follow this document
3. Confirm with the `machine` column in `run_log.csv` after the next run

Deleting first matters. Two machines running the job is the one configuration
that loses data.

---

## When something is wrong

**The job runs but fetches nothing.** Normal if a run happened recently. Check
`devices_up_to_date` in `run_log.csv` — if it equals `devices_seen`, there was
nothing to fetch.

**`ZENTRACLOUD_V5_TOKEN is not set`.** The variable is set for your user but not
machine-wide. Re-run `set_api_tokens.py` from an elevated prompt.

**The push fails.** The data is fetched and on this machine, but nowhere else.
Run the sync tool, or `tools/download/run_download.bat` again once the
connection is back.

**Nothing happens at all on Monday.** The machine was off or asleep, and "Wake
the computer" is unticked. The catch-up prompt will offer it at your next logon.
