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

if [ ! -d "$OUTPUT_FLD" ]; then
    echo "Building source contracts..."
    docker compose -f "$COMPOSE_FILE" run --rm build
    echo "Building completed successfully."
else
    echo "Project has already an output folder."
    echo "Please delete '$OUTPUT_FLD' if you wish to re-build."
fi