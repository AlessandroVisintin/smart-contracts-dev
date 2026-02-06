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
    echo "Foundry repository not found at '$FOUNDRY_FLD'. Use 'init.sh' to create it."
    exit 1
fi

if [ ! -d "$OUTPUT_FLD" ]; then
    echo "Output folder not found at '$OUTPUT_FLD'. Use 'build.sh' to build the contracts."
    exit 1
fi

if [ ! -d "$TESTS_FLD" ]; then
    echo "Tests folder not found at '$TESTS_FLD'."
    exit 1
fi

echo "Launching tests..."
docker compose -f "$COMPOSE_FILE" run --rm test