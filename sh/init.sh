#!/bin/sh
set -eu

SHELL_FLD=$(CDPATH= cd "$(dirname "$0")" && pwd -P)

ENV_PATH="$SHELL_FLD/../.env"

if [ -f "$ENV_PATH" ]; then
    echo "Loading configuration from $ENV_PATH"
    set -a
    . "$ENV_PATH"
    set +a
else
    echo "ERROR: No .env file found at $ENV_PATH" >&2
    exit 1
fi

if [ ! -d "$FOUNDRY_FLD" ]; then
    echo "Initializing Foundry..."
    docker compose -f "$COMPOSE_FILE" run --rm init
    echo "Initialization completed successfully."
else
    echo "Project is already initialized."
    echo "Please delete '$FOUNDRY_FLD' if you wish to re-init."
fi