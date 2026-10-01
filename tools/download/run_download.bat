@echo off
REM ===========================================================================
REM  VI-FLO - download the latest data
REM
REM  Double-click this to pull from Box, fetch whatever ZentraCloud has that
REM  you do not, and push it back.
REM
REM  The same job the weekly scheduled task runs. Safe to run whenever you
REM  want the current data - it only fetches what is missing.
REM
REM  DO NOT run it while you or anyone else is writing data on another
REM  machine - metadata, an ingested file, a station photo. Box carries whole
REM  files, so two machines writing the same file means one version is kept
REM  and the other lost.
REM ===========================================================================

setlocal

echo.
echo  ==========================================
echo    VI-FLO - download the latest data
echo  ==========================================
echo.
echo  This will:
echo    1. Pull anything newer from Box
echo    2. Fetch new readings from ZentraCloud
echo    3. Push the result back to Box
echo.
echo  Do NOT continue if you or anyone else is currently
echo  writing data on this or another machine - metadata,
echo  an ingested file, a station photo. This pushes the whole
echo  data root, and Box keeps one version of a file.
echo.

set /p CONFIRM="  Continue? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
  echo.
  echo  Cancelled - nothing was changed.
  echo.
  pause
  exit /b 0
)

REM --- Find Rscript -----------------------------------------------------------
REM  On PATH is the normal case. The fallbacks cover a default install where
REM  the installer did not add it.
set RSCRIPT=

where Rscript.exe >nul 2>&1
if %ERRORLEVEL%==0 set RSCRIPT=Rscript.exe

if "%RSCRIPT%"=="" (
  for /f "delims=" %%i in ('dir /b /o-n "C:\Program Files\R\R-*" 2^>nul') do (
    if exist "C:\Program Files\R\%%i\bin\Rscript.exe" (
      set "RSCRIPT=C:\Program Files\R\%%i\bin\Rscript.exe"
      goto :found
    )
  )
)
:found

if "%RSCRIPT%"=="" (
  echo.
  echo  X Rscript.exe could not be found.
  echo    Add R to your PATH, or edit this file to point at it directly.
  echo.
  pause
  exit /b 1
)

if "%VI_FLO_ENGINE_ROOT%"=="" (
  echo.
  echo  X VI_FLO_ENGINE_ROOT is not set.
  echo    Run setup_win.exe in the engine repo, then try again.
  echo.
  pause
  exit /b 1
)

set JOB_SCRIPT=%VI_FLO_ENGINE_ROOT%\code\jobs\download_job.R

if not exist "%JOB_SCRIPT%" (
  echo.
  echo  X The job script is missing:
  echo    %JOB_SCRIPT%
  echo    Pull the latest engine repo, then try again.
  echo.
  pause
  exit /b 1
)

echo.
"%RSCRIPT%" "%JOB_SCRIPT%"
set JOB_STATUS=%ERRORLEVEL%

echo.
if %JOB_STATUS%==0 (
  echo  Finished.
) else (
  echo  Finished WITH PROBLEMS - read the messages above.
)
echo.
pause
exit /b %JOB_STATUS%
