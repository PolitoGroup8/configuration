# Ticketing Configuration

Centralized repository for setting up and managing the local Ticketing development and testing environments.

It provides scripts and Docker Compose configurations to clone the microservice repositories and run different combinations of services locally.

## Repository Structure

```text
configuration/
│
├── docker_composes/
│   ├── sales_rabbitmq.yaml
│   └── sales_rabbitmq.repos
│
├── env_files/
│   └── .env.example.sales_rabbitmq
│
├── repositories/
│   ├── sales/
│   ├── rabbitMQ/
│   ├── tickets/
│   └── notifications/
│
├── scripts/
│   ├── setup.bat
│   └── setup.sh
│
├── .env.example
├── .gitignore
└── README.md
```

### Directories

- **`docker_composes/`**: Contains the Docker Compose configurations for the different local environments. Each configuration combines the Compose files of the required microservices using Docker Compose `include`. Each configuration can have an optional `.repos` file listing the repositories it requires (see below).
- **`env_files/`**: Contains environment configuration examples for each testing environment. Each example combines the variables required by the microservices included in that environment.
- **`repositories/`**: Contains the microservice repositories cloned from the GitHub organization.
- **`scripts/`**: Contains the setup scripts: `setup.bat` for Windows and `setup.sh` for Linux and macOS. Both behave identically.

## Prerequisites

- [Git](https://git-scm.com/)
- [Docker](https://www.docker.com/) (Docker Desktop on Windows and macOS) with Docker Compose v2

## Configuration

The repository uses two levels of environment configuration.

### Main environment

The root `.env` file contains the GitHub organization and the list of repositories to clone.

Example:

```dotenv
GITHUB_ORG=your-github-organization
REPOSITORIES=rabbitMQ, sales, tickets, notifications
```

Create it by copying the root `.env.example` and filling in the required values.

### Local environment

The `env_files/` directory contains the environment configurations used by the Docker Compose environments.

Each environment has its own example file containing the combined variables required by its microservices.

For example, to configure the `sales_rabbitmq` environment:

1. Copy the corresponding example file.
2. Name the resulting file `.env`.
3. Configure the required variables.

The resulting file must be located at:

```text
env_files/.env
```

## Docker Compose Environments

Each file inside `docker_composes/` represents a local environment.

Instead of duplicating service configurations, these files include the original Docker Compose files maintained by the individual microservice repositories.

Example: `docker_composes/sales_rabbitmq.yaml`

```yaml
name: sales_rabbitmq

include:
  - path: ../repositories/sales/docker-compose.yaml
    env_file: ../env_files/.env
  - path: ../repositories/rabbitMQ/docker-compose.yml
    env_file: ../env_files/.env
```

This approach allows multiple microservices to be started together while keeping their individual Docker Compose configurations independent.

### Adding a new environment

1. Create a new `.yaml` (or `.yml`) file in `docker_composes/`.
2. Optionally create a `.repos` file with the same name (see below).

No script changes are needed: the scripts scan `docker_composes/` every time and list every environment they find.

### Required repositories (`.repos`)

A `.repos` file with the same name as a Compose file declares which repositories that environment needs. It contains a single line of space-separated repository names.

Example: `docker_composes/sales_rabbitmq.repos`

```text
sales rabbitMQ
```

Before starting an environment, the scripts check that each listed repository has been cloned. If the `.repos` file does not exist, the check is skipped.

## Usage

Run the setup script from any location. It automatically finds the project root by looking for the `docker_composes/` folder in the script's parent directories.

**Windows:**

```bat
scripts\setup.bat
```

**Linux / macOS:**

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### Main menu

The menu is built dynamically. Every Compose file found in `docker_composes/` is listed as a numbered entry, followed by the two global actions. For example, with one environment:

```text
1. sales_rabbitmq.yaml

2. Clone all repositories
3. Stop everything (removes containers AND volumes)

0. Exit
```

The numbers of the global actions shift as environments are added.

| Option | Description |
|---|---|
| `1..N` | Select an environment and open its menu |
| `N+1` | Clone all configured repositories from GitHub |
| `N+2` | Stop all environments and remove containers and volumes |
| `0` | Exit |

### Environment menu

After selecting an environment:

| Option | Description |
|---|---|
| `1` | Start the environment |
| `2` | Stop the environment and remove its containers and volumes |
| `0` | Back to the main menu |

### Clone all repositories

The script reads the root `.env` file, creates the `repositories/` directory if necessary, and clones all configured repositories.

Already cloned repositories are skipped.

### Start an environment

The script checks that:

- Docker is running.
- `env_files/.env` exists.
- The Compose file exists.
- All repositories listed in the `.repos` file (if present) have been cloned.

It then starts the environment using:

```bash
docker compose -f docker_composes/<environment>.yaml up -d
```

### Stop an environment

After confirmation, the script executes:

```bash
docker compose -f docker_composes/<environment>.yaml down -v --remove-orphans
```

### Stop everything

After confirmation, the script executes `docker compose down -v --remove-orphans` for every YAML configuration inside `docker_composes/`.

**Warning:** Both stop operations remove containers, networks and persistent volumes. All stored data, including database contents and RabbitMQ data, will be lost.

## Line endings

Files mounted into containers (for example shell scripts such as RabbitMQ's `entrypoint.sh`) must use LF line endings. With CRLF, the container shell fails with errors like `Illegal option -`.

On Windows, Git may convert files to CRLF on clone (`core.autocrlf=true`). To avoid this, every microservice repository must contain a `.gitattributes` file that forces LF:

```text
* text=auto
*.sh       text eol=lf
*.conf     text eol=lf
*.template text eol=lf
*.json     text eol=lf
*.yaml     text eol=lf
*.yml      text eol=lf
```

This takes precedence over the local Git configuration, so it works on any machine. Apply it to existing files with:

```bash
git add --renormalize .
git commit -m "Force LF line endings"
```

To check the line endings of a cloned repository, run `git ls-files --eol`: the `w/` column must be `w/lf` for the files mounted into containers.

## Troubleshooting

| Problem | Cause and fix |
|---|---|
| `docker_composes\ folder not found` | The script could not find `docker_composes/` in any parent directory. Check that the folder exists and that the script is inside the project. |
| `No compose files found` | `docker_composes/` has no `.yaml` or `.yml` files. |
| `env_files/.env not found` | Copy the example file from `env_files/` and name it `.env`. |
| `Repository ... not found` | Run **Clone all repositories** first. |
| Container fails with `Illegal option -` | A script has CRLF line endings. See [Line endings](#line-endings). |
| `bash\r` or `$'\r': command not found` on Linux/macOS | `setup.sh` was saved with CRLF. Run `sed -i 's/\r$//' scripts/setup.sh` (on macOS: `sed -i '' 's/\r$//' scripts/setup.sh`). |