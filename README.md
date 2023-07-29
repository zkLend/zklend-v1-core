<p align="center">
  <h1 align="center">zklend-v1-core</h1>
</p>

**Core smart contracts of zkLend v1**

[![lint-badge](https://github.com/zkLend/zklend-v1-core/actions/workflows/lint.yaml/badge.svg)](https://github.com/zkLend/zklend-v1-core/actions/workflows/lint.yaml)
[![test-badge](https://github.com/zkLend/zklend-v1-core/actions/workflows/test.yaml/badge.svg)](https://github.com/zkLend/zklend-v1-core/actions/workflows/test.yaml)

## Getting started

### Compiling

To stay as flexible as possible, this repository is not using any smart contract development framework at the moment and invokes `starknet-compile` directly for compiling contracts. A [helper script](./scripts/compile.sh) is available for compiling all the contracts:

```sh
$ ./scripts/compile.sh
```

Note that the script requires the `starknet-compile` command from [starkware-libs/cairo](https://github.com/starkware-libs/cairo) to be installed.

Alternatively, the compilation process can be done inside a Docker container for deterministic output:

```sh
$ ./scripts/compile_with_docker.sh
```

In either case, contract artifacts are generated in the `build` folder.

### Running tests

The `cairo-test` command from [starkware-libs/cairo](https://github.com/starkware-libs/cairo) must be installed to run tests. To run the tests:

```sh
$ cairo-test --starknet .
```

Alternatively, run the tests inside a Docker container:

```sh
$ ./scripts/run_tests_with_docker.sh
```

## Documentation

A brief overview of the smart contracts are available [here](./src/README.md).

## License

Licensed under [Business Source License 1.1](./LICENSE).
