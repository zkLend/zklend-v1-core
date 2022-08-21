<p align="center">
  <h1 align="center">zklend-v1-core</h1>
</p>

**Core smart contracts of zkLend v1**

[![lint-badge](https://github.com/zkLend/zklend-v1-core/actions/workflows/lint.yaml/badge.svg)](https://github.com/zkLend/zklend-v1-core/actions/workflows/lint.yaml)
[![test-badge](https://github.com/zkLend/zklend-v1-core/actions/workflows/test.yaml/badge.svg)](https://github.com/zkLend/zklend-v1-core/actions/workflows/test.yaml)

## Getting started

### Cloning

This repository uses Git submodules for managing dependencies. Use the `--recursive` flag to clone the repository with submodules:

```sh
$ git clone --recursive https://github.com/zkLend/zklend-v1-core
```

If you already cloned the repostiroy without submodules, execute this command inside the repostiroy to fetch the submodules:

```sh
$ git submodule update --init --recursive
```

### Compiling

To stay as flexible as possible, this repository is not using any smart contract development framework at the moment and invokes `starknet-compile` directly for compiling contracts. A [helper script](./scripts/compile.sh) is available for compiling all the contracts:

```sh
$ ./scripts/compile.sh
```

Note that the script requires [cairo-lang](https://github.com/starkware-libs/cairo-lang) to be [installed](https://www.cairo-lang.org/docs/quickstart.html).

Alternatively, the compilation process can be done inside a Docker container for deterministic output:

```sh
$ ./scripts/compile_with_docker.sh
```

In either case, contract artifacts are generated in the `build` folder.

### Running tests

`pytest` and `pytest-asyncio` must be installed to run tests. `pytest-xdist` is also needed if you want to run tests in parallel:

```sh
$ pip install pytest pytest-asyncio pytest-xdist
```

To run tests:

```sh
$ pytest -n 16 -v ./tests/*_test.py ./tests/**/*_test.py
```

Alternatively, run the tests inside a Docker container:

```sh
$ ./scripts/run_tests_with_docker.sh
```

## Documentation

A brief overview of the smart contracts are available [here](./src/README.md).

## License

Licensed under [Business Source License 1.1](./LICENSE).
