@echo off
REM ===========================================================================
REM  VI-FLO - the download job, with the engine updated first
REM
REM  WHAT THIS IS FOR
REM
REM  The scheduled task used to call Rscript directly. That meant the job ran
REM  whatever code happened to be on disk - which on a machine untouched for a
REM  week is a week-old downloader working on today's data.
REM
REM  download_job.R does pull the engine itself, but by then R has already
REM  read the script into memory, so an update only takes effect on the NEXT
REM  run. Pulling out here, before R starts, means the job runs the code it
REM  just fetched.
REM
REM  WHAT IT DOES
REM
REM    1. git pull in the engine repo
REM    2. run code/jobs/download_job.R
REM
REM  No prompts, no window of its own: the scheduled task calls it unattended,
REM  and run_download.bat is the one a person double-clicks.
REM
REM  A failed pull does NOT stop the job. No network is not a reason to skip a
REM  download, and uncommitted changes mean somebody is mid-edit and should be
REM  left alone.
REM
REM  Exit code is the job's, so the scheduler sees what R saw.
REM ===========================================================================

setlocal

if "%VI_FLO_ENGINE_ROOT%"=="" (
  echo X VI_FLO_ENGINE_ROOT is not set.
  exit /b 1
)

REM --- 1. Update the engine ---------------------------------------------------
where git >nul 2>&1
if %ERRORLEVEL%==0 (
  pushd "%VI_FLO_ENGINE_ROOT%"

  REM  Uncommitted work means somebody is editing. Pulling over that is worse
  REM  than running slightly behind.
  REM  A label inside a parenthesised block is a trap: goto exits the whole
  REM  block, including the enclosing if, and execution lands in the else
  REM  branch - which is why this once reported "git is not on PATH"
  REM  immediately after successfully running git status. A flag variable
  REM  stays inside the block.
  set ENGINE_DIRTY=
  for /f "delims=" %%s in ('git status --porcelain 2^>nul') do set ENGINE_DIRTY=1

  if defined ENGINE_DIRTY (
    echo  ! uncommitted changes in the engine - not updating
  ) else (
    echo  Engine - pulling the latest code
    git pull --ff-only
    if errorlevel 1 echo  ! git pull failed - running with the code as it stands
  )
  popd
) else (
  echo  ! git is not on PATH - the engine was not updated
)

REM --- 2. Find Rscript --------------------------------------------------------
set RSCRIPT=

where Rscript.exe >nul 2>&1
if %ERRORLEVEL%==0 set RSCRIPT=Rscript.exe

if "%RSCRIPT%"=="" (
  for /f "delims=" %%i in ('dir /b /o-n "C:\Program Files\R\R-*" 2^>nul') do (
    if exist "C:\Program Files\R\%%i\bin\Rscript.exe" (
      set "RSCRIPT=C:\Program Files\R\%%i\bin\Rscript.exe"
      goto :found_r
    )
  )
)
:found_r

if "%RSCRIPT%"=="" (
  echo X Rscript.exe could not be found.
  exit /b 1
)

REM --- 3. Run the job ---------------------------------------------------------
set JOB_SCRIPT=%VI_FLO_ENGINE_ROOT%\code\jobs\download_job.R

if not exist "%JOB_SCRIPT%" (
  echo X The job script is missing: %JOB_SCRIPT%
  exit /b 1
)

"%RSCRIPT%" "%JOB_SCRIPT%"
exit /b %ERRORLEVEL%
