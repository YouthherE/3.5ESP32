@echo off
setlocal

rem ============================================================
rem  Wireless cast - PC sender (Windows + ffmpeg)
rem
rem  Usage:   pc_cast.bat <ESP32-IP>
rem  Example: pc_cast.bat 192.168.1.50
rem
rem  Tunables:
rem   -framerate 10   capture frame rate (lower it if the ESP keeps dropping)
rem   -q:v N          JPEG quality, 2=best/largest .. 31=worst/smallest
rem                   ***This is the #1 frame-rate knob on the ESP32 side.***
rem                   The panel can only show ~5-10 fps, and the ESP32 must
rem                   fully JPEG-decode every frame before pushing it over SPI.
rem                   Decode time is roughly proportional to the frame size, so:
rem                     -q:v 2  ->  ~45 KB/frame -> decode ~90 ms  -> ~5 fps
rem                     -q:v 16 ->  ~15 KB/frame -> decode ~45 ms  -> ~8 fps
rem                   Try 14..20. ffmpeg's mjpeg encoder always uses 4:2:0 chroma,
rem                   which is already the cheap-to-decode option.
rem   scale=480:320   panel size. NOTE: the ESP32 always draws JPEG 1:1 (it never
rem                   scales - scaling is 2-4x slower) and clips to its cast area,
rem                   so the right 120 columns are covered by the info panel.
rem                   Send 360:320 instead to see the whole frame in the cast
rem                   area, or keep the aspect ratio with:
rem   -vf "scale=360:320:force_original_aspect_ratio=decrease,pad=360:320:(ow-iw)/2:(oh-ih)/2:color=black"
rem
rem  Capture one window instead of the whole desktop:
rem   -i title="Some Window"
rem ============================================================

set ESPIP=%~1
if "%ESPIP%"=="" (
  echo [CAST] Usage: pc_cast.bat ^<ESP32-IP^>
  echo [CAST] Example: pc_cast.bat 192.168.1.50
  pause
  exit /b 1
)

where ffmpeg >nul 2>nul
if errorlevel 1 (
  echo [CAST] ffmpeg not found in PATH. Install it first: winget install Gyan.FFmpeg
  pause
  exit /b 1
)

:CAST
echo [CAST] streaming to %ESPIP%:8888   (Ctrl+C to stop)
ffmpeg -hide_banner -loglevel warning ^
  -f gdigrab -framerate 10 -i desktop ^
  -vf "scale=480:320" ^
  -q:v 16 -f mjpeg tcp://%ESPIP%:8888
echo [CAST] ffmpeg exited, retry in 2s ...
timeout /t 2 /nobreak >nul
goto CAST
