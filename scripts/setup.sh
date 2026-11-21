#!/usr/bin/env bash
# ------------------------------------------------------------
# setup.sh - equivalent of setup.bat (Linux / macOS)
# ------------------------------------------------------------

pause() {
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    echo
}

# Find the project root: go up from the script folder until docker_composes/ is found
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT=""
dir="$SCRIPT_DIR"
for _ in 1 2 3 4; do
    if [[ -d "$dir/docker_composes" ]]; then
        ROOT="$dir"
        break
    fi
    dir="$(dirname "$dir")"
done

if [[ -z "$ROOT" ]]; then
    echo "[ERROR] docker_composes/ folder not found in any parent directory of the script."
    pause
    exit 1
fi

cd "$ROOT" || exit 1

COMPOSES=()
COMPOSE_FILE=""
COMPOSE_BASE=""

scan_composes() {
    COMPOSES=()
    local f
    for f in docker_composes/*.yaml docker_composes/*.yml; do
        [[ -e "$f" ]] && COMPOSES+=("$f")
    done
}

# ------------------------------------------------------------
# Clone all repositories
# ------------------------------------------------------------
clone_all() {
    clear
    echo "========================================"
    echo "      TICKETING - REPOSITORY SETUP"
    echo "========================================"

    if [[ ! -f ".env" ]]; then
        echo "[ERROR] .env file not found."
        return 1
    fi

    # Load environment variables (skip comments and empty lines, strip CR)
    local line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        [[ -z "$line" || "$line" == \#* || "$line" != *=* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        [[ -z "$key" ]] && continue
        printf -v "$key" '%s' "$value"
    done < ".env"

    if [[ -z "${GITHUB_ORG:-}" ]]; then
        echo "[ERROR] GITHUB_ORG is not configured."
        return 1
    fi

    if [[ -z "${REPOSITORIES:-}" ]]; then
        echo "[ERROR] REPOSITORIES is not configured."
        return 1
    fi

    echo
    echo "========================================"
    echo "      LOADED ENVIRONMENT"
    echo "========================================"
    echo "GITHUB_ORG: $GITHUB_ORG"
    echo "REPOSITORIES: $REPOSITORIES"
    echo "========================================"
    echo

    if ! command -v git >/dev/null 2>&1; then
        echo "[ERROR] Git is not installed or not available in PATH."
        return 1
    fi

    mkdir -p "repositories"

    # Normalize repository list (commas -> spaces)
    local repos="${REPOSITORIES//,/ }"

    echo
    echo "========================================"
    echo "      CLONING REPOSITORIES"
    echo "========================================"

    local repo
    for repo in $repos; do
        if [[ ! -d "repositories/$repo/.git" ]]; then
            if [[ -d "repositories/$repo" ]]; then
                echo "[ERROR] Invalid directory: $repo"
                return 1
            fi

            echo "[INFO] Cloning $repo..."

            if ! git clone "https://github.com/${GITHUB_ORG}/${repo}.git" "repositories/$repo"; then
                echo "[ERROR] Failed to clone $repo."
                return 1
            fi

            echo "[SUCCESS] $repo cloned."
        else
            echo "[SKIP] $repo already exists."
        fi
    done

    echo
    echo "[SUCCESS] All repositories are ready."
    return 0
}

# ------------------------------------------------------------
# Start selected stack
# ------------------------------------------------------------
start_stack() {
    clear
    echo "========================================"
    echo "      START: $COMPOSE_FILE"
    echo "========================================"
    echo

    if ! docker info >/dev/null 2>&1; then
        echo "[ERROR] Docker is not running. Start Docker and retry."
        return 1
    fi

    if [[ ! -f "env_files/.env" ]]; then
        echo "[ERROR] env_files/.env not found. Copy the .example file and fill it in."
        return 1
    fi

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        echo "[ERROR] $COMPOSE_FILE not found."
        return 1
    fi

    # Required repositories for this stack (optional file: <compose name>.repos)
    local repos_file="${COMPOSE_BASE}.repos"
    if [[ -f "$repos_file" ]]; then
        local required=""
        read -r required < "$repos_file" || true
        required="${required%$'\r'}"
        local repo
        for repo in $required; do
            if [[ ! -d "repositories/$repo/.git" ]]; then
                echo "[ERROR] Repository $repo not found. Use the clone option first."
                return 1
            fi
        done
    fi

    docker compose -f "$COMPOSE_FILE" up -d
    local exitcode=$?

    echo
    if [[ $exitcode -ne 0 ]]; then
        echo "========================================"
        echo "[ERROR] Docker Compose failed with exit code $exitcode."
        echo "        Read the messages above before continuing."
        echo "========================================"
    else
        echo "[SUCCESS] $COMPOSE_FILE started."
    fi
    return 0
}

# ------------------------------------------------------------
# Down selected stack
# ------------------------------------------------------------
down_stack() {
    clear
    echo "========================================"
    echo "      DOWN: $COMPOSE_FILE"
    echo "========================================"
    echo
    echo "[WARNING] This stops this stack and removes"
    echo "          containers, networks and VOLUMES."
    echo "          All data (database, queues) will be lost."
    echo

    if ! docker info >/dev/null 2>&1; then
        echo "[ERROR] Docker is not running."
        return 1
    fi

    local confirm=""
    read -r -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Operation cancelled."
        return 0
    fi

    docker compose -f "$COMPOSE_FILE" down -v --remove-orphans
    local exitcode=$?

    echo
    if [[ $exitcode -ne 0 ]]; then
        echo "========================================"
        echo "[ERROR] Failed to stop $COMPOSE_FILE (exit code $exitcode)."
        echo "        Read the messages above."
        echo "========================================"
    else
        echo "[SUCCESS] $COMPOSE_FILE stopped. Containers and volumes removed."
    fi
    return 0
}

# ------------------------------------------------------------
# Stop everything
# ------------------------------------------------------------
down_all() {
    clear
    echo "========================================"
    echo "      STOP EVERYTHING"
    echo "========================================"
    echo
    echo "[WARNING] This stops every stack in docker_composes/ and removes"
    echo "          containers, networks and VOLUMES."
    echo "          All data (database, queues) will be lost."
    echo

    if ! docker info >/dev/null 2>&1; then
        echo "[ERROR] Docker is not running."
        return 1
    fi

    local confirm=""
    read -r -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Operation cancelled."
        return 0
    fi

    local has_error=0 f
    scan_composes
    for f in "${COMPOSES[@]}"; do
        echo "[INFO] Stopping $f..."
        if ! docker compose -f "$f" down -v --remove-orphans; then
            echo "[ERROR] Failed to stop $f."
            has_error=1
        fi
    done

    echo
    if [[ $has_error -eq 1 ]]; then
        echo "========================================"
        echo "[ERROR] Some stacks failed to stop. Read the messages above."
        echo "========================================"
    else
        echo "[SUCCESS] Everything stopped. Containers and volumes removed."
    fi
    return 0
}

# ------------------------------------------------------------
# Stack menu (Start / Down)
# ------------------------------------------------------------
stack_menu() {
    local action
    while true; do
        clear
        echo "========================================"
        echo "      STACK: $COMPOSE_FILE"
        echo "========================================"
        echo
        echo "1. Start"
        echo "2. Down (removes containers AND volumes)"
        echo
        echo "0. Back"
        echo
        action=""
        read -r -p "Select an option: " action

        case "$action" in
            1) start_stack; pause ;;
            2) down_stack; pause ;;
            0) return 0 ;;
            *) echo; echo "[ERROR] Invalid option."; pause ;;
        esac
    done
}

# ------------------------------------------------------------
# Main menu
# ------------------------------------------------------------
while true; do
    clear
    echo "========================================"
    echo "      TICKETING - SELECT STACK"
    echo "========================================"
    echo

    scan_composes
    count=${#COMPOSES[@]}

    i=0
    for f in "${COMPOSES[@]}"; do
        i=$((i + 1))
        echo "$i. $(basename "$f")"
    done

    if [[ $count -eq 0 ]]; then
        echo "[WARNING] No compose files found in docker_composes/."
    fi

    clone_num=$((count + 1))
    downall_num=$((count + 2))

    echo
    echo "$clone_num. Clone all repositories"
    echo "$downall_num. Stop everything (removes containers AND volumes)"
    echo
    echo "0. Exit"
    echo

    choice=""
    read -r -p "Select an option: " choice

    if [[ "$choice" == "0" ]]; then
        exit 0
    elif [[ "$choice" == "$clone_num" ]]; then
        clone_all; pause
        continue
    elif [[ "$choice" == "$downall_num" ]]; then
        down_all; pause
        continue
    fi

    # Validate: must be a number between 1 and count
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
        COMPOSE_FILE="${COMPOSES[$((choice - 1))]}"
        COMPOSE_BASE="${COMPOSE_FILE%.*}"
        stack_menu
    else
        echo
        echo "[ERROR] Invalid option."
        pause
    fi
done