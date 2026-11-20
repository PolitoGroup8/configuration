@echo off
setlocal EnableDelayedExpansion

set "COMPOSE_FILE=docker_composes\sales_rabbitmq.yaml"

:menu
cls
echo ========================================
echo       TICKETING - REPOSITORY SETUP
echo ========================================
echo.
echo 1. Clone all repositories
echo 2. Start sales + rabbitMQ
echo 3. Stop everything (removes containers AND volumes)
echo.
echo 0. Exit
echo.
set /p "CHOICE=Select an option: "

if "!CHOICE!"=="1" goto clone_all
if "!CHOICE!"=="2" goto start_sales_rabbit
if "!CHOICE!"=="3" goto down_all
if "!CHOICE!"=="0" goto exit

echo.
echo [ERROR] Invalid option.
pause
goto menu


:clone_all
cls

echo ========================================
echo       TICKETING - REPOSITORY SETUP
echo ========================================

if not exist ".env" (
    echo [ERROR] .env file not found.
    pause
    goto menu
)

REM Load environment variables
for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
    if not "%%A"=="" set "%%A=%%B"
)

if not defined GITHUB_ORG (
    echo [ERROR] GITHUB_ORG is not configured.
    pause
    goto menu
)

if not defined REPOSITORIES (
    echo [ERROR] REPOSITORIES is not configured.
    pause
    goto menu
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
    pause
    goto menu
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
            pause
            goto menu
        )

        echo [INFO] Cloning %%R...

        git clone "https://github.com/!GITHUB_ORG!/%%R.git" "repositories\%%R"

        if errorlevel 1 (
            echo [ERROR] Failed to clone %%R.
            pause
            goto menu
        )

        echo [SUCCESS] %%R cloned.
    ) else (
        echo [SKIP] %%R already exists.
    )
)

echo.
echo [SUCCESS] All repositories are ready.
pause
goto menu


:start_sales_rabbit
cls
echo ========================================
echo       START SALES + RABBITMQ
echo ========================================
echo.

docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running. Start Docker Desktop and retry.
    pause
    goto menu
)

if not exist "env_files\.env" (
    echo [ERROR] env_files\.env file not found.
    exit /b 1
)

if not exist "repositories\sales\.git" (
    echo [ERROR] Repository sales not found. Use option 1 first.
    pause
    goto menu
)

if not exist "repositories\rabbitMQ\.git" (
    echo [ERROR] Repository rabbitMQ not found. Use option 1 first.
    pause
    goto menu
)

if not exist "env_files\.env" (
    echo [ERROR] env_files\.env not found. Copy the .example file and fill it in.
    pause
    goto menu
)

if not exist "!COMPOSE_FILE!" (
    echo [ERROR] !COMPOSE_FILE! not found.
    pause
    goto menu
)

docker compose -f "!COMPOSE_FILE!" up -d
set "EXITCODE=!errorlevel!"

echo.
if not "!EXITCODE!"=="0" (
    echo ========================================
    echo [ERROR] Docker Compose failed with exit code !EXITCODE!.
    echo         Read the messages above before continuing.
    echo ========================================
) else (
    echo [SUCCESS] sales + rabbitMQ started.
)
echo.
pause
goto menu


:down_all
cls
echo ========================================
echo       STOP EVERYTHING
echo ========================================
echo.
echo [WARNING] This stops every stack in docker_composes\ and removes
echo           containers, networks and VOLUMES.
echo           All data (database, queues) will be lost.
echo.

docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running.
    pause
    goto menu
)

set "CONFIRM="
set /p "CONFIRM=Are you sure? (y/n): "
if /i not "!CONFIRM!"=="y" (
    echo Operation cancelled.
    pause
    goto menu
)

for %%F in (docker_composes\*.yaml docker_composes\*.yml) do (
    echo [INFO] Stopping %%F...
    docker compose -f "%%F" down -v --remove-orphans
    if errorlevel 1 (
        echo [ERROR] Failed to stop %%F.
        set "HAS_ERROR=1"
    )
)

echo.
if defined HAS_ERROR (
    echo ========================================
    echo [ERROR] Some stacks failed to stop. Read the messages above.
    echo ========================================
    set "HAS_ERROR="
) else (
    echo [SUCCESS] Everything stopped. Containers and volumes removed.
)
echo.
pause
goto menu


:exit
endlocal
exit /b 0