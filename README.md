# Ticketing Configuration

Centralized repository for setting up and managing the local Ticketing development and testing environments.

It provides scripts and Docker Compose configurations to clone the microservice repositories and run different combinations of services locally.

## Repository Structure

```text
configuration/
│
├── docker_composes/
│   └── sales_rabbitmq.yaml
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
├── .env.example
├── .gitignore
├── README.md
└── setup.bat
```

### Directories

- **`docker_composes/`**: Contains the Docker Compose configurations for the different local environments. Each configuration combines the Compose files of the required microservices using Docker Compose `include`.
- **`env_files/`**: Contains environment configuration examples for each testing environment. Each example combines the variables required by the microservices included in that environment.
- **`repositories/`**: Contains the microservice repositories cloned from the GitHub organization.

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

## Usage

Run the main setup script:

```bat
setup.bat
```

The script provides the following options:

| Option | Description |
|---|---|
| `1` | Clone all configured repositories from GitHub |
| `2` | Start the Sales + RabbitMQ environment |
| `3` | Stop all configured environments and remove containers and volumes |
| `0` | Exit |

### Clone all repositories

Select option `1`.

The script reads the root `.env` file, creates the `repositories/` directory if necessary, and clones all configured repositories.

Already cloned repositories are skipped.

### Start Sales + RabbitMQ

Select option `2`.

The script checks that:

- Docker is running.
- `env_files/.env` exists.
- The Sales repository has been cloned.
- The RabbitMQ repository has been cloned.
- The corresponding Docker Compose configuration exists.

It then starts the environment using:

```bat
docker compose -f docker_composes/sales_rabbitmq.yaml up -d
```

### Stop everything

Select option `3`.

After confirmation, the script executes `docker compose down -v --remove-orphans` for every YAML configuration inside `docker_composes/`.

**Warning:** This operation removes containers, networks and persistent volumes. All stored data, including database contents and RabbitMQ data, will be lost.