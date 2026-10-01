# =============================================================================
#  VI-FLO - offer a missed download
#
#  Run at logon by Task Scheduler. Reads run_log.csv, and if the last
#  successful download is older than the threshold, offers to run one now.
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

$ThresholdHours = 170   # 7 days 2 hours - so a Monday job missed by a few
                        # hours can still be dealt with the same morning

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

$age = (Get-Date).ToUniversalTime() - $lastRun
if ($age.TotalHours -lt $ThresholdHours) { exit 0 }

# --- Ask ---------------------------------------------------------------------
$days  = [math]::Floor($age.TotalDays)
$hours = [math]::Floor($age.TotalHours) - ($days * 24)

$ageText = if ($days -eq 1) { "1 day" } else { "$days days" }
if ($hours -eq 1) { $ageText += " and 1 hour" }
elseif ($hours -gt 0) { $ageText += " and $hours hours" }

Add-Type -AssemblyName System.Windows.Forms | Out-Null

$message = @"
The weekly download last ran $ageText ago.

Run it now?

Do NOT run this if you or anyone else is currently writing
to the database on this or any other machine.
"@

$answer = [System.Windows.Forms.MessageBox]::Show(
    $message,
    "VI-FLO data downloader",
    [System.Windows.Forms.MessageBoxButtons]::OKCancel,
    [System.Windows.Forms.MessageBoxIcon]::Question)

if ($answer -ne [System.Windows.Forms.DialogResult]::OK) { exit 0 }

# --- Run it ------------------------------------------------------------------
# The same .bat a person would double-click, so there is one way the job runs
# and one place to fix it.
$Bat = Join-Path $EngineRoot "tools\download\run_download.bat"

if (Test-Path $Bat) {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$Bat`""
} else {
    [System.Windows.Forms.MessageBox]::Show(
        "Could not find:`n$Bat",
        "VI-FLO data downloader",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
}

exit 0
