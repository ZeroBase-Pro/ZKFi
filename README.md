# Zerobase Staking

The [Zerobase](https://zerobase.pro/)  staking mechanism is an incentive and constraint system designed to ensure the security and reliability of prover nodes during ZKP generation. Prover nodes must stake stablecoins to join the proof network. These staked stablecoins are used for trading arbitrage via CEFFU, generating additional returns.

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

## V1 Version Auditor

- Salus: [Salus_ZeroBase_report_2024-12-16](./docs/Salus_ZeroBase_report_2024-12-16.pdf)
- Peckshield: [PeckShield-Audit-Report-ZeroBase-Vault-v1.0.pdf](./docs/PeckShield-Audit-Report-ZeroBase-Vault-v1.0.pdf)

## V1 Version Supported Chains

The `Vault` address on all chains is: `0x59f6E226a1055D05a9BD07f40AC2aa87e303CC33`. Currently supported:

- Ethereum
- BSC
- Polygon
- Arbitrum
- AVAX-C

## V2 Version Change

- Emergency Withdrawal Automation:
Emergency withdrawals are now fully automated, allowing users to interact directly with the contract without manual intervention. Users will only need to pay a 0.5% emergency withdrawal fee based on the withdrawn amount.

- LP Token for Deposits:
Users will receive LP tokens (zkUSDT/zkUSDC) upon depositing, representing their stake in the ZEROBASE Staking product.

- Borrowing Feature:
Users will be able to stake zkUSDT/zkUSDC and borrow USDT/USDC against their holdings.

- Risk-Neutral ZK Functionality for Trading Strategies:
A new ZK functionality for risk-neutral validation of trading strategies will be launched, along with the open-source release of the circuit code.

- Proof Browser:
A proof browser will be introduced, enabling users to verify zero-knowledge proof results transparently.

- Enhanced User Interface:
Improvements to the front-end user interaction experience will be implemented for better usability.

- Seamless V1 Compatibility:
The V2 contract will be fully compatible with V1, allowing V1 users to access all V2 features without disruption, ensuring a seamless contract migration.

## V2 Version Auditor

## V2 Version Supported Chains

The `Vault` address on all chains is: ``. Currently supported:

- Ethereum
- BSC
- Polygon
- Arbitrum
- AVAX-C
- OP
- Base




## Circuit Logic

### Delta Neutrality Verification
- Calculates the absolute difference between the maximum and minimum Delta values.
- Verifies whether this difference (scaled) satisfies the Delta upper limit constraint.

### Leverage Ratio Verification
- Ensures the leverage value is non-negative and does not exceed the predefined limit.
- Confirms that the provided leverage value matches the computed result.

### Boundary Condition Validation
- Verifies that input values (e.g., `DeltaUpper` and `LeverageUpper`) are within reasonable ranges.

---


## Usage

The circuit is implemented in `ZKRiskNeutralCircuit` and compiled into a constraint system (CCS).
```bash
go run ZKRiskNeutral.go
```

## Example

### Input Assignment
```go
assignment := ZKRiskNeutralCircuit{
    Leverage:        1,   // Leverage ratio
    DeltaMax:        100, // Maximum Delta in the position
    DeltaMin:        99,  // Minimum Delta in the position
    LeverageUpper:   3,   // Leverage upper limit
    DeltaUpper:      5,   // Delta risk neutrality upper limit
    LeverageConfirm: -1,  // Leverage result: -1 less than, 0 equal to, 1 greater than
    DeltaConfirm:    -1,  // Delta result: -1 less than, 0 equal to, 1 greater than
}
```

## Output

Proof file saved as `proof.data`.

Verification passed, confirming that Delta neutrality and leverage constraints are satisfied.
