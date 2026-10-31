@echo off
rem Run the twin-stick proof of concept in Godot 4.7 (desktop). Looks for Godot in the GODOT variable, next to this
rem folder, in Desktop and Downloads, then on PATH.
setlocal
if defined GODOT if exist "%GODOT%" goto run
set "GODOT="
for %%G in ("%~dp0..\Godot_v4.7.2-stable_win64.exe" "%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe" "%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe") do if not defined GODOT if exist "%%~G" set "GODOT=%%~G"
if defined GODOT goto run
for /d %%D in ("%USERPROFILE%\Desktop\Godot*" "%USERPROFILE%\Downloads\Godot*") do if not defined GODOT if exist "%%~D\Godot_v4.7.2-stable_win64.exe" set "GODOT=%%~D\Godot_v4.7.2-stable_win64.exe"
if defined GODOT goto run
for /f "delims=" %%G in ('where godot 2^>nul') do if not defined GODOT set "GODOT=%%G"
if defined GODOT goto run
echo Could not find Godot 4.7.2. Get it from https://godotengine.org/download/archive/ (standard, not .NET),
echo or just open docs\index.html through the GitHub Pages link in README.md.
pause
exit /b 1
:run
start "" "%GODOT%" --path "%~dp0."
