# =============================================================================
#  VI-FLO - offer a missed download
#
#  Run at logon and unlock by Task Scheduler. Works out when the weekly job
#  was last DUE, and if no download has run since, offers one now.
#
#  Silent when there is nothing to say: no console, no window, nothing. The
#  only time you see it is when a download was actually missed.
#
#  WHY A PROMPT RATHER THAN A CATCH-UP
#
#  Task Scheduler can run a missed task automatically on the next wake. That
#  was rejected deliberately: it would fire at an unpredictable moment,
#  possibly while somebody is writing metadata on the other machine, which is
#  exactly the collision the job is meant to avoid. A prompt fires when a
#  person is at the keyboard and can answer the question.
#
#  Set up with: tools/download/SCHEDULING.md
# =============================================================================

# --- When the weekly job is due ---------------------------------------------
#
# Monday 07:00 local, matching the scheduled task.
#
# This is measured from the SCHEDULE, not from the last download. Measuring
# from the last download asks "is the data stale?" when the question is "did
# the scheduled run happen?" - and those diverge exactly when it matters. A
# Monday missed because the machine was off would not have been noticed until
# the Wednesday, because the previous Thursday's run was still inside a
# seven-day window.
$DueDayOfWeek = [DayOfWeek]::Monday
$DueHour      = 7
$GraceHours   = 1       # a run at 07:00 is not late at 07:30

# --- Where things are -------------------------------------------------------
$DataRoot   = $env:VI_FLO_DATA_ROOT
$EngineRoot = $env:VI_FLO_ENGINE_ROOT

if ([string]::IsNullOrWhiteSpace($DataRoot) -or
    [string]::IsNullOrWhiteSpace($EngineRoot)) {
    # Nothing to do - this machine is not set up for VI-FLO. Silent, because a
    # logon task that complains on a machine it was never meant for is noise.
    exit 0
}

$RunLog = Join-Path $DataRoot "metadata\internal\run_log.csv"
if (-not (Test-Path $RunLog)) { exit 0 }

# --- When did a download last succeed? --------------------------------------
try {
    $rows = Import-Csv $RunLog | Where-Object {
        $_.job -eq "zentra_download" -and $_.status -eq "ok"
    }
} catch {
    exit 0
}

if (-not $rows) { exit 0 }

$last = $rows[-1]

try {
    # started_utc is UTC, as the column name says
    $lastRun = [datetime]::ParseExact($last.started_utc, "yyyy-MM-dd HH:mm:ss",
                                      [Globalization.CultureInfo]::InvariantCulture,
                                      [Globalization.DateTimeStyles]::AssumeUniversal -bor
                                      [Globalization.DateTimeStyles]::AdjustToUniversal)
} catch {
    exit 0
}

# --- When was the job last due? ---------------------------------------------
# The most recent Monday 07:00 local at or before now.
$now = Get-Date
$daysBack = ([int]$now.DayOfWeek - [int]$DueDayOfWeek + 7) % 7
$lastDue  = $now.Date.AddDays(-$daysBack).AddHours($DueHour)
if ($lastDue -gt $now) { $lastDue = $lastDue.AddDays(-7) }

# Still inside the grace period - a run at 07:00 is not late at 07:30
if (($now - $lastDue).TotalHours -lt $GraceHours) { exit 0 }

# Did a download run since then? Compared in UTC, because that is what the
# run log holds.
$lastDueUtc = $lastDue.ToUniversalTime()
if ($lastRun -ge $lastDueUtc) { exit 0 }

$age = (Get-Date).ToUniversalTime() - $lastRun

# --- Ask ---------------------------------------------------------------------
# Read in whatever units make sense at that distance. "0 days ago" is how a
# naive day count reads for anything under 24 hours, which is both wrong and
# faintly absurd.
$days    = [math]::Floor($age.TotalDays)
$hours   = [math]::Floor($age.TotalHours) - ($days * 24)
$minutes = [math]::Floor($age.TotalMinutes) - ([math]::Floor($age.TotalHours) * 60)

$plural = { param($n, $word) if ($n -eq 1) { "1 $word" } else { "$n ${word}s" } }

if ($days -ge 1) {
    $ageText = & $plural $days "day"
    if ($hours -gt 0) { $ageText += " and " + (& $plural $hours "hour") }
} elseif ($hours -ge 1) {
    $ageText = & $plural $hours "hour"
    if ($minutes -gt 0) { $ageText += " and " + (& $plural $minutes "minute") }
} else {
    $ageText = & $plural ([math]::Max($minutes, 1)) "minute"
}

Add-Type -AssemblyName System.Windows.Forms | Out-Null

# --- Is the engine repo current? --------------------------------------------
#
# The job pulls Box before downloading, but nothing checks the CODE. A run
# from a stale checkout uses old functions against fresh data, which is the
# kind of thing that is only obvious afterwards. A warning, not a block: git
# may not be on PATH, and being unable to check is not a reason to refuse.
$repoNote = ""
try {
    Push-Location $EngineRoot
    git fetch --quiet 2>$null
    $behind = (git rev-list --count HEAD..'@{u}' 2>$null)
    Pop-Location
    if ($behind -match '^\d+$' -and [int]$behind -gt 0) {
        $repoNote = "`n`nNOTE: the engine repo is $behind commit(s) behind." +
                    "`nPull before running, or this uses stale code."
    }
} catch {
    try { Pop-Location } catch { }
}

$message = @"
The weekly download was due on $($lastDue.ToString("dddd d MMMM")) at 07:00.

It last ran $ageText ago.

Running it will:
   1. Update the engine code from GitHub
   2. Pull anything newer from Box
   3. Fetch new readings from ZentraCloud
   4. Push the result back to Box

Do NOT run this if you or anyone else is currently writing
data on this or any other machine - metadata, an ingested
file, a station photo.$repoNote

Run it now?
"@

$answer = [System.Windows.Forms.MessageBox]::Show(
    $message,
    "VI-FLO data downloader",
    [System.Windows.Forms.MessageBoxButtons]::OKCancel,
    [System.Windows.Forms.MessageBoxIcon]::Question)

if ($answer -ne [System.Windows.Forms.DialogResult]::OK) { exit 0 }

# --- Run it ------------------------------------------------------------------
# run_download_job.bat, the SAME wrapper the scheduled task calls: git pull,
# then the job. Not run_download.bat, which is the interactive one and does
# not update the engine - a prompted catch-up that skipped the code update
# would run stale code precisely on the machine most likely to be behind,
# since being behind is why it is prompting.
#
# The wrapper has no confirmation of its own. It does not need one: the
# dialog above already asked, and asking twice teaches people to click
# through.
$Bat = Join-Path $EngineRoot "tools\download\run_download_job.bat"

if (Test-Path $Bat) {
    # -WindowStyle Normal matters. This script is launched by Task Scheduler
    # with -WindowStyle Hidden, so it has no console of its own - which is
    # what keeps it silent on every unlock when there is nothing to say. A
    # child process inheriting that absent console cannot start, and fails
    # with 0xc0000142, "the application was unable to start correctly".
    #
    # Asking for a normal window makes Windows create a fresh console for the
    # job rather than hand it the parent's.
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$Bat`"" `
                  -WindowStyle Normal
} else {
    [System.Windows.Forms.MessageBox]::Show(
        "Could not find:`n$Bat",
        "VI-FLO data downloader",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
}

exit 0
