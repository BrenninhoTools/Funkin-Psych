@echo off
setlocal EnableExtensions
title Funkin-Psych Build Manager
cd /d "%~dp0.."

set "ROOT=%CD%"
set "TARGET=windows"
set "MODE=release"
set "ACTION=build"

if not exist "project.hxp" if not exist "Project.xml" if not exist "project.xml" (
    echo [ERROR] Project configuration not found.
    echo Expected project.hxp or Project.xml.
    pause
    exit /b 1
)

where haxe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Haxe is not installed or not in PATH.
    pause
    exit /b 1
)

where haxelib >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Haxelib was not found.
    pause
    exit /b 1
)

:menu
cls
echo ============================================
echo          FUNKIN-PSYCH BUILD MANAGER
echo ============================================
echo.
echo   [1] Build Windows Release
echo   [2] Build Windows Debug
echo   [3] Build and Run
echo   [4] Clean Build
echo   [5] Install Dependencies
echo   [6] Show Versions
echo   [0] Exit
echo.
set /p "CHOICE=Select an option: "

if "%CHOICE%"=="1" (
    set "ACTION=build"
    set "MODE=release"
    goto compile
)
if "%CHOICE%"=="2" (
    set "ACTION=build"
    set "MODE=debug"
    goto compile
)
if "%CHOICE%"=="3" (
    set "ACTION=test"
    set "MODE=release"
    goto compile
)
if "%CHOICE%"=="4" goto clean
if "%CHOICE%"=="5" goto dependencies
if "%CHOICE%"=="6" goto versions
if "%CHOICE%"=="0" exit /b 0

goto menu

:compile
cls
echo ============================================
echo             BUILD INFORMATION
echo ============================================
echo.
echo Target: %TARGET%
echo Mode: %MODE%
echo Action: %ACTION%
echo Directory: %ROOT%
echo.

call :checklime
if errorlevel 1 goto failed

set "FLAGS="
if /i "%MODE%"=="debug" set "FLAGS=-debug"

echo [INFO] Starting compilation...
echo.

call haxelib run lime %ACTION% %TARGET% %FLAGS%
if errorlevel 1 goto failed

echo.
echo [SUCCESS] Build completed successfully!
echo.
pause
goto menu

:clean
cls
echo [INFO] Cleaning Windows build...

call :checklime
if errorlevel 1 goto failed

call haxelib run lime clean windows
if errorlevel 1 goto failed

echo.
echo [SUCCESS] Windows build cleaned!
pause
goto menu

:dependencies
cls
echo ============================================
echo          DEPENDENCY INSTALLATION
echo ============================================
echo.

if exist "hmm.json" (
    where hmm >nul 2>&1
    if errorlevel 1 (
        echo [INFO] Installing HMM...
        call haxelib install hmm
        if errorlevel 1 goto failed
    )

    echo [INFO] Installing dependencies from hmm.json...
    call haxelib run hmm install
    if errorlevel 1 goto failed
) else (
    echo [ERROR] hmm.json not found.
    echo Use the repository's setup instructions.
    pause
    goto menu
)

echo.
echo [SUCCESS] Dependencies installed!
pause
goto menu

:versions
cls
echo ============================================
echo              TOOL VERSIONS
echo ============================================
echo.
echo Haxe:
call haxe --version
echo.
echo Haxelib:
call haxelib version
echo.
echo Lime:
call haxelib run lime --version
echo.
pause
goto menu

:checklime
call haxelib path lime >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Lime is not installed.
    echo Install the project dependencies first.
    exit /b 1
)
exit /b 0

:failed
echo.
echo [ERROR] Operation failed.
echo Check the messages above.
echo.
pause
goto menu
