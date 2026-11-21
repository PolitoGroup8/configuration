@echo off
setlocal EnableDelayedExpansion

REM Find the project root: go up from the script folder until docker_composes\ is found
pushd "%~dp0"
set "ROOT_FOUND="
for /l %%I in (1,1,4) do (
    if not defined ROOT_FOUND (
        if exist "docker_composes\" (
            set "ROOT_FOUND=1"
        ) else (
            cd ..
        )
    )
)

if not defined ROOT_FOUND (
    echo [ERROR] docker_composes\ folder not found in any parent directory of the script.
    pause
    popd
    endlocal
    exit /b 1
)

:menu
cls
echo ========================================
echo       TICKETING - SELECT STACK
echo ========================================
echo.

REM Scan available compose files
set "COUNT=0"
for %%F in (docker_composes\*.yaml docker_composes\*.yml) do (
    set /a COUNT+=1
    set "COMPOSE_!COUNT!=%%F"
    set "BASE_!COUNT!=%%~dpnF"
    echo !COUNT!. %%~nxF
)

if "!COUNT!"=="0" echo [WARNING] No compose files found in docker_composes\.

set /a CLONE_NUM=COUNT+1
set /a DOWNALL_NUM=COUNT+2

echo.
echo !CLONE_NUM!. Clone all repositories
echo !DOWNALL_NUM!. Stop everything (removes containers AND volumes)
echo.
echo 0. Exit
echo.
set "CHOICE="
set /p "CHOICE=Select an option: "

if "!CHOICE!"=="0" goto exit
if "!CHOICE!"=="!CLONE_NUM!" goto clone_all
if "!CHOICE!"=="!DOWNALL_NUM!" goto down_all

REM Validate: must be a number between 1 and COUNT
set "COMPOSE_FILE="
for /l %%I in (1,1,!COUNT!) do (
    if "!CHOICE!"=="%%I" (
        set "COMPOSE_FILE=!COMPOSE_%%I!"
        set "COMPOSE_BASE=!BASE_%%I!"
    )
)

if defined COMPOSE_FILE goto stack_menu

echo.
echo [ERROR] Invalid option.
pause
goto menu


:stack_menu
cls
echo ========================================
echo       STACK: !COMPOSE_FILE!
echo ========================================
echo.
echo 1. Start
echo 2. Down (removes containers AND volumes)
echo.
echo 0. Back
echo.
set "ACTION="
set /p "ACTION=Select an option: "

if "!ACTION!"=="1" goto start_stack
if "!ACTION!"=="2" goto down_stack
if "!ACTION!"=="0" goto menu

echo.
echo [ERROR] Invalid option.
pause
goto stack_menu


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


:start_stack
cls
echo ========================================
echo       START: !COMPOSE_FILE!
echo ========================================
echo.

docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running. Start Docker Desktop and retry.
    pause
    goto stack_menu
)

if not exist "env_files\.env" (
    echo [ERROR] env_files\.env not found. Copy the .example file and fill it in.
    pause
    goto stack_menu
)

if not exist "!COMPOSE_FILE!" (
    echo [ERROR] !COMPOSE_FILE! not found.
    pause
    goto stack_menu
)

REM Required repositories for this stack (optional file: <compose name>.repos)
set "REPOS_FILE=!COMPOSE_BASE!.repos"
if exist "!REPOS_FILE!" (
    set "REQUIRED="
    set /p REQUIRED=<"!REPOS_FILE!"
    for %%R in (!REQUIRED!) do (
        if not exist "repositories\%%R\.git" (
            echo [ERROR] Repository %%R not found. Use the clone option first.
            pause
            goto stack_menu
        )
    )
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
    echo [SUCCESS] !COMPOSE_FILE! started.
)
echo.
pause
goto stack_menu


:down_stack
cls
echo ========================================
echo       DOWN: !COMPOSE_FILE!
echo ========================================
echo.
echo [WARNING] This stops this stack and removes
echo           containers, networks and VOLUMES.
echo           All data (database, queues) will be lost.
echo.

docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running.
    pause
    goto stack_menu
)

set "CONFIRM="
set /p "CONFIRM=Are you sure? (y/n): "
if /i not "!CONFIRM!"=="y" (
    echo Operation cancelled.
    pause
    goto stack_menu
)

docker compose -f "!COMPOSE_FILE!" down -v --remove-orphans
set "EXITCODE=!errorlevel!"

echo.
if not "!EXITCODE!"=="0" (
    echo ========================================
    echo [ERROR] Failed to stop !COMPOSE_FILE! ^(exit code !EXITCODE!^).
    echo         Read the messages above.
    echo ========================================
) else (
    echo [SUCCESS] !COMPOSE_FILE! stopped. Containers and volumes removed.
)
echo.
pause
goto stack_menu


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
popd
endlocal
exit /b 0