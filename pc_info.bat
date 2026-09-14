@echo off
setlocal
rem ============================================================
rem  pc_info.bat [ESP-IP | install | uninstall | probe | find]
rem
rem  Pushes PC stats (CPU load / memory / temperature) to the
rem  ESP32 side panel over TCP 8889.
rem
rem    *** If you do not want to type anything at all:          ***
rem    *** just DOUBLE-CLICK pc_info_hidden.vbs instead.        ***
rem    *** It starts hidden, then asks one Yes/No question for  ***
rem    *** the logon auto-start.                                ***
rem
rem    pc_info.bat                run in this window, IP from Connection.ini
rem    pc_info.bat 192.168.0.31   run in this window, this IP (all logs shown)
rem    pc_info.bat install        install + start in the BACKGROUND, and make
rem                               it start automatically at every logon.
rem                               Do this ONCE - after that you never have to
rem                               type any command again. Windows shows one
rem                               UAC prompt; the task then runs with HIGHEST
rem                               privileges, which is what the temperature
rem                               sensors need (a normal startup shortcut can
rem                               not read them).
rem    pc_info.bat uninstall      undo the line above
rem    pc_info.bat probe          one-shot self test of THIS PC only
rem                               (prints CPU%/MEM%/temps + Lenovo WMI
rem                                channel name, does NOT connect to ESP32)
rem    pc_info.bat find           scan YOUR subnet for the ESP32 (it listens
rem                               on 8888 and 8889) and write its current IP
rem                               into Connection.ini. Use this after the
rem                               router gave the ESP32 a new address - the
rem                               panel then goes back to life.
rem
rem  RSSI / heap / uptime / cast status are measured on the ESP32 itself,
rem  so this script does not touch them.
rem
rem  Only needs the built-in Windows PowerShell.
rem
rem  The numbers are read with the same logic Lenovo Vantage / Lenovo PC
rem  Manager use on their device status page:
rem      CPU% = PDH \Processor Information(_Total)\% Processor Time
rem      MEM% = GlobalMemoryStatusEx().dwMemoryLoad
rem      CPUT = Lenovo BIOS WMI (root\WMI, LENOVO_GAMEZONE_DATA.Get*Temp,
rem             called on the INSTANCE - class level calls always fail;
rem             enumerating the class needs administrator rights)
rem  Models whose BIOS does not report a temperature on that channel (this
rem  Legion Y9000P 2021 / GMZN returns 0 there - verified) fall back to
rem  LENOVO_FAN_METHOD.Fan_GetCurrentSensorTemperature, then to
rem  LibreHardwareMonitor/OpenHardwareMonitor, then to the ACPI thermal zone,
rem  then to the Thermal Zone Information performance counter.
rem  When no CPU temperature can be read at all, the panel temperature row
rem  falls back to the disk temperature (Get-StorageReliabilityCounter,
rem  built into Windows, nothing to install, but its Temperature field also
rem  needs administrator rights) and the label switches to SSD-T.
rem  Everything may still be "--" on some machines (e.g. disk behind a USB
rem  bridge / RAID, or a BIOS that exposes neither channel).
rem
rem  Run pc_info.bat probe once to see, for THIS PC, exactly which of the
rem  four temperature channels works and which does not.
rem
rem  Keep this window open only when you start it this way.
rem ============================================================

if /i "%~1"=="install"   goto do_install
if /i "%~1"=="uninstall" goto do_uninstall
if /i "%~1"=="probe"     goto do_probe
if /i "%~1"=="find"      goto do_find

set "PS1=%~dp0pc_info.ps1"
if not exist "%PS1%" (
  echo [pc_info] cannot find pc_info.ps1 next to this .bat:
  echo           %PS1%
  echo.
  pause
  exit /b 1
)

echo [pc_info] running in THIS window - leave it open, close it to stop.
echo.

if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" "%~1"
)
if errorlevel 1 echo [pc_info] powershell exited with an error - read the messages above.

echo.
echo [pc_info] stopped.
pause
exit /b 0

::do_probe
rem  one sample of everything, this PC only - does NOT connect to the ESP32
set "PS1=%~dp0pc_info.ps1"
if not exist "%PS1%" (
  echo [pc_info] cannot find pc_info.ps1 next to this .bat:
  echo           %PS1%
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Probe
if errorlevel 1 echo [pc_info] powershell exited with an error - read the messages above.
echo.
pause
exit /b 0

::do_find
rem  scan the local subnet for the ESP32 and update Connection.ini
set "PS1=%~dp0pc_info.ps1"
if not exist "%PS1%" (
  echo [pc_info] cannot find pc_info.ps1 next to this .bat:
  echo           %PS1%
  echo.
  pause
  exit /b 1
)
echo [pc_info] looking for the ESP32 on your subnet - make sure it is ON.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Find
if errorlevel 1 echo [pc_info] no ESP32 found - read the messages above.
echo.
pause
exit /b 0

::do_install
set "PS1=%~dp0pc_info.ps1"
if not exist "%PS1%" (
  echo [pc_info] cannot find pc_info.ps1 next to this .bat:
  echo.
  pause
  exit /b 1
)
echo [pc_info] installing the logon auto-start task.
echo [pc_info] Windows will ask for administrator rights ONCE - that is what
echo [pc_info] lets the script read the temperature sensors afterwards.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -InstallAuto
if errorlevel 1 echo [pc_info] install returned an error - read the messages above.
echo.
pause
exit /b 0

::do_uninstall
set "PS1=%~dp0pc_info.ps1"
if not exist "%PS1%" (
  echo [pc_info] cannot find pc_info.ps1 next to this .bat:
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -UninstallAuto
if errorlevel 1 echo [pc_info] uninstall returned an error - read the messages above.
echo.
pause
exit /b 0
