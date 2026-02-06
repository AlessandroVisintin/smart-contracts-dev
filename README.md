# SmartContractsDev

This repository is a small Solidity smart-contract playground that builds and runs tests using **Foundry** (a Solidity development toolkit) inside Docker containers.

It includes a few example contracts and Foundry-style tests, plus shell scripts that load a `.env` file and call `docker compose` for init/build/test tasks.

## Key features

- Docker Compose services to initialize a Foundry workspace, build contracts, and run tests (`init`, `build`, `test`).
- Shell scripts (`sh/init.sh`, `sh/build.sh`, `sh/test.sh`) that load `./.env` and run the corresponding Compose service.
- Example Solidity contracts under `src/` (including simple storage, a counter, and hash managers).
- Foundry tests under `tests/` using `forge-std/Test.sol` patterns (unit tests and fuzz tests).
- Configurable Solidity compiler version and EVM (Ethereum Virtual Machine) version via environment variables.

## What you need (prerequisites)

- **Docker** and **Docker Compose** (the scripts call `docker compose …`)
- A **POSIX-compatible shell** to run the `.sh` scripts (they start with `#!/bin/sh`)

On Windows, run the scripts from Git Bash, WSL, or a similar environment so `/bin/sh` and Unix-style paths work correctly.

## Quick start

### Install

1. Clone or download this repository.
2. Ensure Docker is running (Docker Desktop on Windows/macOS or Docker Engine on Linux).

### Configure

1. Copy `.env.example` to `.env` at the repository root:

   ```bash
   cp .env.example .env
   ```

2. Edit `.env` to match your local paths. Example structure:

   ```env
   COMPOSE_FILE="/path/to/SmartContractsDev/docker/docker-compose.yml"
   
   FOUNDRY_FLD="/path/to/SmartContractsDev/foundry"
   SOURCE_FLD="/path/to/SmartContractsDev/src"
   OUTPUT_FLD="/path/to/SmartContractsDev/out"
   TESTS_FLD="/path/to/SmartContractsDev/tests"
   
   FOUNDRY_VERSION="v1.4.3"
   SOLIDITY_VERSION="0.8.25"
   EVM_VERSION="shanghai"
   ```

### Run

1. **Initialize** the Foundry workspace (creates the directory at `FOUNDRY_FLD` and runs `forge init --empty --no-git`):
   ```sh
   ./sh/init.sh
   ```

2. **Build** contracts (compiles Solidity sources and writes artifacts to `OUTPUT_FLD`):
   ```sh
   ./sh/build.sh
   ```

3. **Run tests** (mounts `tests/` into the container and executes `forge test`):
   ```sh
   ./sh/test.sh
   ```

### Included contracts

- **Counter.sol** – A simple unsigned integer counter with `setNumber(uint256)` and `increment()` methods.
- **SimpleStorage.sol** – Stores a `string`, emits a `DataChanged` event on updates, and intentionally reverts when given the input `"Trigger Error"` (useful for testing revert handling).
- **HashManager.sol** – A registry for unique `bytes32` hashes with an owner field; supports add, read, and "deprecate" (removal with swap-and-pop array compaction to save gas).
- **DagHashManager.sol** – Extends hash management by tracking directed links between hashes, prevents cycle creation, and cleans up all incoming and outgoing links when a hash is deleted.

## Configuration

### Environment variables

`.env` at repository root ir required by all shell scripts; they exit with an error if missing. Use `.env.example` as a template.

All variables are read by the shell scripts (`./sh/*.sh`) and injected into Docker Compose services (`docker/docker-compose.yml`).


| Name | Required | What it does |
|---|---:|---|
| `COMPOSE_FILE` | Yes | Path to the Compose file to run (`docker compose -f "$COMPOSE_FILE" ...`). |
| `FOUNDRY_FLD` | Yes | Host folder mounted to `/app/foundry` in containers (the Foundry workspace location). |
| `SOURCE_FLD` | Yes (for build/test) | Host folder mounted to `/app/foundry/src` (your Solidity sources). |
| `OUTPUT_FLD` | Yes (for build/test) | Host folder mounted to `/app/foundry/out` (build artifacts). |
| `TESTS_FLD` | Yes (for test) | Host folder mounted to `/app/foundry/test` (Foundry test folder). |
| `FOUNDRY_VERSION` | Yes |  Selects the Foundry Docker image tag/version to run. |
| `SOLIDITY_VERSION` | Yes (for build/test) | Passed to `forge build/test --use "$SOLIDITY_VERSION"` to pick the Solidity compiler version. |
| `EVM_VERSION` | Yes (for build/test) | Passed to `forge build/test --evm-version "$EVM_VERSION"` to select the EVM target version. |

## Project structure

```text
SmartContractsDev/
├── README.md
├── LICENSE
├── .env.example              # Template for environment configuration
├── docker/
│   └── docker-compose.yml    # Defines init, build, and test Compose services
├── sh/
│   ├── init.sh               # Creates Foundry workspace (runs once)
│   ├── build.sh              # Compiles contracts (skips if OUTPUT_FLD exists)
│   └── test.sh               # Runs Foundry test suite
├── src/
│   ├── Counter.sol           # Simple counter contract
│   ├── SimpleStorage.sol     # String storage with event and intentional revert
│   ├── HashManager.sol       # Hash registry with owner and deprecate
│   └── DagHashManager.sol    # DAG-based hash manager with link tracking
└── tests/
    ├── Counter.t.sol
    ├── SimpleStorage.t.sol
    ├── HashManager.t.sol
    └── DagHashManager.t.sol
```

## Development

### Install dev dependencies

All dependencies are managed by the Foundry Docker image (`ghcr.io/foundry-rs/foundry`). No additional local installation is required.

### Run in dev/watch mode

The current scripts do not include a watch mode. To recompile after changes, delete the `OUTPUT_FLD` directory and re-run `./sh/build.sh`.

### Tests

Run the full test suite with `./sh/test.sh`.

This executes `forge test` inside the `test` Docker service. Tests are located in `tests/` and use the `forge-std/Test.sol` library for assertions, pranks (caller spoofing), and event matching.

## License

This project is licensed under the **MIT License**. See the `LICENSE` file for full details.