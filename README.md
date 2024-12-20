# Zerobase

[Zerobase](https://zerobase.pro/) is a real-time zero-knowledge (ZK) prover network designed for rapid proof generation, decentralization, and regulatory compliance. It generates ZK proofs within hundreds of milliseconds, enabling large-scale commercial applications.

We introduce a smart contract system, hereafter referred to as `Vault`, it is a secure staking and rewards management system built on the Ethereum Virtual Machine (EVM) blockchain. It allows users to stake supported tokens and earn rewards.

You could find more details in the [document](./docs/zerobase-vault-1212.pdf).

## Installation

Initialize and configure this project through the following steps:

1. Install the [Foundry](https://github.com/foundry-rs/foundry).
2. Clone this repository.
3. Compile the project: `forge compile`.

> If you encounter issues with dependency errors, you can use the `forge install` command to download, or manually download using the following commands:
>
> ```
> forge install foundry-rs/forge-std
> forge install openzeppelin/openzeppelin-contracts
> ```

## Audit

- Salus: [Salus_ZeroBase_report_2024-12-16](./docs/Salus_ZeroBase_report_2024-12-16.pdf)
- Peckshield: [PeckShield-Audit-Report-ZeroBase-Vault-v1.0.pdf](./docs/PeckShield-Audit-Report-ZeroBase-Vault-v1.0.pdf)

## Supported Chains

The `Vault` address on all chains is: `0x59f6E226a1055D05a9BD07f40AC2aa87e303CC33`. Currently supported:

- Ethereum
- BSC
- Polygon
- Arbitrum
- AVAX-C
