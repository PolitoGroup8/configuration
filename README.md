# Configuration

Scripts for setting up and managing the local Ticketing development environment.

## Setup

Run:

```bat
setup.bat
```

The script creates a `repositories` directory and clones all the repositories configured in `.env` inside it.

```text
configuration/
├── repositories/
│   ├── rabbitMQ/
│   ├── sales/
│   ├── ...
│   └── ...
├── .env
└── setup.bat
```