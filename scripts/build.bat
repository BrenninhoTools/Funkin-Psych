@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Funkin' Psych Build
cd /d "%~dp0.."
set "ROOT=%CD%"
set "LOG_DIR=%ROOT%\export\logs"

set "TARGET=%~1"
set "MODE=%~2"
set "ACTION=%~3"
if not "%TARGET%"=="" goto prepare

:menu
cls
echo ==================================================
echo                FUNKIN' PSYCH BUILD
echo ==================================================
echo.
echo   [1] Windows release        [6] Install dependencies
echo   [2] Windows debug          [7] Rebuild Lime (host)
echo   [3] Windows release + run  [8] Clean exports
echo   [4] Android release        [9] Show versions
echo   [5] Android debug          [0] Exit
echo.
set "CHOICE="
set /p "CHOICE=Option: "
set "ACTION=build"
if "%CHOICE%"=="1" (set "TARGET=windows" & set "MODE=release" & goto prepare)
if "%CHOICE%"=="2" (set "TARGET=windows" & set "MODE=debug" & goto prepare)
if "%CHOICE%"=="3" (set "TARGET=windows" & set "MODE=release" & set "ACTION=test" & goto prepare)
if "%CHOICE%"=="4" (set "TARGET=android" & set "MODE=release" & goto prepare)
if "%CHOICE%"=="5" (set "TARGET=android" & set "MODE=debug" & goto prepare)
if "%CHOICE%"=="6" (call :dependencies & call :pause_menu & goto menu)
if "%CHOICE%"=="7" (call :rebuild_lime windows -64 & call :pause_menu & goto menu)
if "%CHOICE%"=="8" (call :clean & call :pause_menu & goto menu)
if "%CHOICE%"=="9" (call :versions & call :pause_menu & goto menu)
if "%CHOICE%"=="0" exit /b 0
goto menu

:prepare
if "%MODE%"=="" set "MODE=release"
if "%ACTION%"=="" set "ACTION=build"
if /i not "%TARGET%"=="windows" if /i not "%TARGET%"=="android" if /i not "%TARGET%"=="linux" if /i not "%TARGET%"=="hl" (
    echo [ERROR] Unknown target "%TARGET%". Use windows, android, linux or hl.
    exit /b 1
)
if /i not "%MODE%"=="release" if /i not "%MODE%"=="debug" (
    echo [ERROR] Unknown mode "%MODE%". Use release or debug.
    exit /b 1
)
if /i not "%ACTION%"=="build" if /i not "%ACTION%"=="test" if /i not "%ACTION%"=="run" (
    echo [ERROR] Unknown action "%ACTION%". Use build, test or run.
    exit /b 1
)

call :check_tools || goto failed
call :check_dependencies || goto failed
if /i "%TARGET%"=="android" (call :setup_android || goto failed)

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set "LOG=%LOG_DIR%\%TARGET%-%MODE%.log"

set "FLAGS=-%MODE%"
if /i "%TARGET%"=="android" set "FLAGS=%FLAGS% -arm64"
if not "%EXTRA_FLAGS%"=="" set "FLAGS=%FLAGS% %EXTRA_FLAGS%"

echo.
echo [INFO] Target: %TARGET%  Mode: %MODE%  Action: %ACTION%
echo [INFO] Log: %LOG%
echo.
call haxelib run lime %ACTION% %TARGET% %FLAGS% > "%LOG%" 2>&1
set "RESULT=%ERRORLEVEL%"
type "%LOG%" | findstr /i /c:"error" /c:"warning :" 2>nul
if not "%RESULT%"=="0" goto failed

echo.
echo [DONE] %TARGET% %MODE% finished. Output: export\%MODE%\%TARGET%\bin
if "%~1"=="" (call :pause_menu & goto menu)
exit /b 0

:check_tools
for %%T in (haxe haxelib git) do (
    where %%T >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] %%T was not found in PATH.
        exit /b 1
    )
)
if not exist "project.hxp" (
    echo [ERROR] project.hxp not found in %ROOT%.
    exit /b 1
)
exit /b 0

:check_dependencies
for %%L in (hxcpp lime openfl flixel) do (
    call haxelib libpath %%L >nul 2>&1
    if errorlevel 1 (
        echo [INFO] %%L is missing, installing dependencies...
        call :dependencies || exit /b 1
        goto check_dependencies_done
    )
)
:check_dependencies_done
call :lime_path || exit /b 1
if not exist "%LIME_DIR%\ndll\Windows64\lime.ndll" (
    echo [INFO] Lime host library not found, rebuilding it...
    call :rebuild_lime windows -64 || exit /b 1
)
exit /b 0

:dependencies
echo [INFO] Installing haxelib with FunkinCrew patches and hxpkg...
call haxelib --global --never install haxelib 4.1.0 >nul
call haxelib --global set haxelib 4.1.0 >nul
call haxelib --global --never git haxelib https://github.com/FunkinCrew/haxelib.git funkin-patches --skip-dependencies || exit /b 1
call haxelib --global --never install hxpkg || exit /b 1
echo [INFO] Installing project libraries from .hxpkg...
call haxelib --global run hxpkg install --force || exit /b 1
call :lime_path || exit /b 1
echo [INFO] Fetching Lime submodules...
git -C "%LIME_DIR%" submodule update --init --recursive --depth 1 || exit /b 1
echo [INFO] Compiling hxcpp tools...
for /f "delims=" %%P in ('haxelib libpath hxcpp') do set "HXCPP_DIR=%%P"
pushd "!HXCPP_DIR!tools\hxcpp" || exit /b 1
call haxe compile.hxml
set "HXCPP_RESULT=!ERRORLEVEL!"
popd
if not "!HXCPP_RESULT!"=="0" exit /b 1
echo [DONE] Dependencies installed.
exit /b 0

:lime_path
set "LIME_DIR="
for /f "delims=" %%P in ('haxelib libpath lime 2^>nul') do if not defined LIME_DIR set "LIME_DIR=%%P"
if not defined LIME_DIR (
    echo [ERROR] Lime is not installed. Run option 6 first.
    exit /b 1
)
if "%LIME_DIR:~-1%"=="\" set "LIME_DIR=%LIME_DIR:~0,-1%"
if "%LIME_DIR:~-1%"=="/" set "LIME_DIR=%LIME_DIR:~0,-1%"
exit /b 0

:rebuild_lime
call :lime_path || exit /b 1
echo [INFO] Rebuilding Lime for %~1 %~2...
call haxelib run lime rebuild %~1 %~2 -release || exit /b 1
exit /b 0

:setup_android
if "%ANDROID_HOME%"=="" if not "%ANDROID_SDK_ROOT%"=="" set "ANDROID_HOME=%ANDROID_SDK_ROOT%"
if "%ANDROID_HOME%"=="" if exist "%LOCALAPPDATA%\Android\Sdk" set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
if "%ANDROID_HOME%"=="" (
    echo [ERROR] Android SDK not found. Set ANDROID_HOME.
    exit /b 1
)
if "%ANDROID_NDK_ROOT%"=="" if exist "%ANDROID_HOME%\ndk\27.2.12479018" set "ANDROID_NDK_ROOT=%ANDROID_HOME%\ndk\27.2.12479018"
if "%ANDROID_NDK_ROOT%"=="" (
    echo [ERROR] NDK r27c not found. Install "ndk;27.2.12479018" with sdkmanager or set ANDROID_NDK_ROOT.
    exit /b 1
)
if "%JAVA_HOME%"=="" (
    echo [ERROR] JAVA_HOME is not set. Install JDK 17 and set JAVA_HOME.
    exit /b 1
)
call haxelib run lime config ANDROID_SDK "%ANDROID_HOME%" >nul
call haxelib run lime config ANDROID_NDK_ROOT "%ANDROID_NDK_ROOT%" >nul
call haxelib run lime config JAVA_HOME "%JAVA_HOME%" >nul
call haxelib run lime config ANDROID_SETUP true >nul
if not exist "%LIME_DIR%\ndll\Android\liblime-64.so" (
    call :rebuild_lime android -arm64 || exit /b 1
)
exit /b 0

:clean
echo [INFO] Removing export folder...
if exist "%ROOT%\export" rmdir /s /q "%ROOT%\export"
echo [DONE] Clean finished.
exit /b 0

:versions
echo Haxe:
call haxe --version
echo Haxelib:
call haxelib version
for %%L in (hxcpp lime openfl flixel haxeui-core haxeui-flixel) do (
    for /f "delims=" %%P in ('haxelib libpath %%L 2^>nul') do echo %%L: %%P
)
exit /b 0

:pause_menu
echo.
pause
exit /b 0

:failed
echo.
echo [FAILED] See the messages above.
if defined LOG echo Full log: %LOG%
if "%~1"=="" (call :pause_menu & goto menu)
exit /b 1
