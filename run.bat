@echo off
echo ========================================
echo    CG CALENDAR - BUILD & RUN
echo ========================================
echo.

echo [1/3] Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)
echo.

echo [2/3] Generating Freezed code...
call flutter pub run build_runner build --delete-conflicting-outputs
if errorlevel 1 (
    echo ERROR: Failed to generate code
    pause
    exit /b 1
)
echo.

echo [3/3] Running app...
echo.
echo ========================================
echo    APP IS STARTING - DEMO MODE
echo ========================================
echo.
echo DEMO SCREENS:
echo   1. Splash Screen
echo   2. Login Screen  
echo   3. Calendar Screen
echo.
echo Use bottom buttons to navigate!
echo ========================================
echo.

call flutter run

pause

