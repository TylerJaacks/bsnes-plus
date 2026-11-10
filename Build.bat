@echo off
rem ===========================================================================
rem  bsnes-plus (XBAND) release build
rem
rem  Builds the accuracy, performance and compatibility profiles plus all
rem  plugins, gathers every runtime file into release\bsnes-plus-<version>\
rem  and zips it.  Run from cmd.exe or by double-click; lives in the repo root.
rem
rem    release.bat            clean build of everything
rem    release.bat noclean    reuse existing objects (faster, for testing)
rem
rem  Toolchain: MSYS2 MinGW-w64 (mingw-w64-x86_64-gcc, -make, -binutils).
rem  Override its location with:  set MINGW=D:\path\to\mingw64\bin
rem ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "ROOT=%CD%"

rem ---- toolchain -------------------------------------------------------------
if not defined MINGW set "MINGW=C:\msys64\mingw64\bin"
if not exist "%MINGW%\g++.exe" (
  echo [!] g++.exe not found in "%MINGW%"
  echo     Install it in MSYS2:  pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-make
  echo     or point MINGW at your toolchain's bin folder.
  goto :fail
)
if not exist "%MINGW%\mingw32-make.exe" (
  echo [!] mingw32-make.exe not found. In MSYS2:  pacman -S mingw-w64-x86_64-make
  goto :fail
)
set "PATH=%MINGW%;%PATH%"

rem ---- Qt submodule ----------------------------------------------------------
if not exist "external\qt\mingw-w64\bin\Qt5Core.dll" (
  echo [*] Qt submodule missing, initializing...
  git submodule update --init external/qt || goto :fail
)

rem ---- version ---------------------------------------------------------------
set "HASH=local"
for /f %%h in ('git rev-parse --short HEAD 2^>nul') do set "HASH=%%h"
set "VERSION=05-xband-%HASH%"
set "PKG=bsnes-plus-%VERSION%"
set "STAGE=%ROOT%\release\%PKG%"
set "JOBS=%NUMBER_OF_PROCESSORS%"
if not defined JOBS set "JOBS=4"
echo [*] Building %PKG% with %JOBS% jobs

rem ---- clean -----------------------------------------------------------------
if /i not "%~1"=="noclean" (
  echo [*] Cleaning old build output...
  for %%d in (bsnes\obj\accuracy bsnes\obj\performance bsnes\obj\compatibility) do (
    if exist "%%d\*.o" del /q "%%d\*.o"
  )
  if exist "bsnes\obj\*.moc" del /q "bsnes\obj\*.moc"
  if exist "bsnes\obj\*.rcc" del /q "bsnes\obj\*.rcc"
  if exist "bsnes\out\*.exe" del /q "bsnes\out\*.exe"
  for %%d in (snesreader snesfilter snesmusic supergameboy) do (
    if exist "%%d\obj\*.o"   del /q "%%d\obj\*.o"
    if exist "%%d\obj\*.moc" del /q "%%d\obj\*.moc"
    if exist "%%d\*.dll"     del /q "%%d\*.dll"
    if exist "%%d\*.a"       del /q "%%d\*.a"
  )
)
if not exist "bsnes\out" mkdir "bsnes\out"

rem ---- build -----------------------------------------------------------------
pushd bsnes
echo [*] Building accuracy profile...
mingw32-make -j%JOBS% build platform=win profile=accuracy version=%VERSION% || (popd & goto :fail)
echo [*] Building performance profile...
mingw32-make -j%JOBS% build platform=win profile=performance version=%VERSION% || (popd & goto :fail)
echo [*] Building compatibility profile and plugins...
mingw32-make -j%JOBS% platform=win profile=compatibility version=%VERSION% || (popd & goto :fail)
popd

rem ---- stage -----------------------------------------------------------------
echo [*] Staging %STAGE%
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%" || goto :fail

for %%p in (accuracy performance compatibility) do (
  copy /y "bsnes\out\bsnes-%%p.exe" "%STAGE%\" >nul || goto :fail
)
for %%d in (snesreader snesfilter snesmusic supergameboy) do (
  copy /y "%%d\%%d.dll" "%STAGE%\" >nul || goto :fail
)

xcopy /e /i /q /y "bsnes\data\bsxdat" "%STAGE%\bsxdat" >nul || goto :fail
copy /y "external\qt\mingw-w64\bin\*.dll" "%STAGE%\" >nul || goto :fail
xcopy /e /i /q /y "external\qt\mingw-w64\plugins" "%STAGE%" >nul || goto :fail

for %%r in (libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll libgomp-1.dll) do (
  if exist "%MINGW%\%%r" (
    copy /y "%MINGW%\%%r" "%STAGE%\" >nul
  ) else (
    echo [!] Runtime DLL %%r not found in %MINGW%
    goto :fail
  )
)

rem ---- XBAND manifest template (rename to match the XBAND BIOS ROM) ----------
> "%STAGE%\xband-manifest.xml" (
  echo ^<?xml version='1.0' encoding='UTF-8'?^>
  echo ^<cartridge region='NTSC'^>
  echo   ^<xband^>
  echo     ^<rom^>
  echo       ^<map mode='direct' address='00-3f:8000-ffff'/^>
  echo       ^<map mode='direct' address='80-bf:8000-ffff'/^>
  echo       ^<map mode='direct' address='40-7d:0000-ffff'/^>
  echo       ^<map mode='direct' address='c0-df:0000-ffff'/^>
  echo     ^</rom^>
  echo     ^<ram size='10000'^>
  echo       ^<map mode='linear' address='e0-e0:0000-ffff'/^>
  echo     ^</ram^>
  echo     ^<mmio^>
  echo       ^<map mode='direct' address='e0-ff:0000-ffff'/^>
  echo     ^</mmio^>
  echo   ^</xband^>
  echo ^</cartridge^>
)
> "%STAGE%\XBAND-README.txt" (
  echo XBAND usage
  echo -----------
  echo 1. Copy xband-manifest.xml next to your XBAND BIOS ROM and rename it to the
  echo    ROM's base name, e.g. XBAND.sfc -^> XBAND.xml
  echo 2. System -^> Load Special -^> Load XBAND Cartridge, pick the BIOS as the base.
  echo 3. Server, port and box identity are compiled in; see
  echo    bsnes/snes/chip/xband/xband_base.cpp
  echo.
  echo Built from commit %HASH%
)

rem ---- dependency check --------------------------------------------------------
echo [*] Checking DLL dependencies...
set "MISSING="
for %%f in ("%STAGE%\*.exe" "%STAGE%\*.dll") do (
  for /f "tokens=3" %%d in ('objdump -p "%%~f" 2^>nul ^| findstr /c:"DLL Name:"') do (
    set "DEP=%%d"
    if /i not "!DEP:~0,11!"=="api-ms-win-" (
      if not exist "%STAGE%\%%d" if not exist "%SystemRoot%\System32\%%d" (
        echo [!] %%~nxf needs %%d, which is not in the package
        set "MISSING=1"
      )
    )
  )
)
if defined MISSING goto :fail

rem ---- zip -------------------------------------------------------------------
set "ZIP=%ROOT%\release\%PKG%.zip"
if exist "%ZIP%" del /q "%ZIP%"
echo [*] Zipping...
tar -a -c -f "%ZIP%" -C "%ROOT%\release" "%PKG%" 2>nul
if errorlevel 1 (
  powershell -NoProfile -Command "Compress-Archive -Path '%STAGE%' -DestinationPath '%ZIP%' -Force" || goto :fail
)

echo.
echo [+] Done: %ZIP%
endlocal
exit /b 0

:fail
echo.
echo [X] Release build failed.
endlocal
exit /b 1
