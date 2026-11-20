
@echo off
setlocal EnableDelayedExpansion

echo ========================================
echo       TICKETING - REPOSITORY SETUP
echo ========================================

if not exist ".env" (
    echo [ERROR] .env file not found.
    exit /b 1
)

REM Load environment variables
for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
    if not "%%A"=="" set "%%A=%%B"
)

if not defined GITHUB_ORG (
    echo [ERROR] GITHUB_ORG is not configured.
    exit /b 1
)

if not defined REPOSITORIES (
    echo [ERROR] REPOSITORIES is not configured.
    exit /b 1
)

echo.
echo ========================================
echo       LOADED ENVIRONMENT
echo ========================================
echo GITHUB_ORG: !GITHUB_ORG!
echo REPOSITORIES: !REPOSITORIES!
echo ========================================
echo.

REM Check Git installation
where git >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git is not installed or not available in PATH.
    exit /b 1
)

REM Create repositories directory
if not exist "repositories" mkdir "repositories"

REM Normalize repository list
set "REPOSITORIES=!REPOSITORIES:,= !"

echo.
echo ========================================
echo       CLONING REPOSITORIES
echo ========================================

for %%R in (!REPOSITORIES!) do (
    if not exist "repositories\%%R\.git" (
        if exist "repositories\%%R" (
            echo [ERROR] Invalid directory: %%R
            exit /b 1
        )

        echo [INFO] Cloning %%R...

        git clone "https://github.com/!GITHUB_ORG!/%%R.git" "repositories\%%R"

        if errorlevel 1 (
            echo [ERROR] Failed to clone %%R.
            exit /b 1
        )

        echo [SUCCESS] %%R cloned.
    ) else (
        echo [SKIP] %%R already exists.
    )
)

echo.
echo [SUCCESS] All repositories are ready.

endlocal
