# ZKRiskNeutralCircuit: Risk Assessment and Leverage Constraint Circuit Based on Gnark

## Overview
ZKRiskNeutralCircuit demonstrates how to construct a zk-SNARK circuit using the Gnark library. This circuit evaluates financial risk parameters, including Delta risk neutrality and leverage constraints, and verifies whether they meet predefined conditions. Operating in a zero-knowledge environment, the circuit ensures input data privacy while providing proof of compliance.

---

## Key Features

### Delta Risk Neutrality Evaluation
- Computes whether the Delta risk neutrality of a position is within a reasonable range (e.g., < 5%).
- Percentage values are scaled and adjusted to avoid floating-point calculations to meet zk-SNARK constraints.

### Leverage Ratio Verification
- Verifies whether the leverage ratio is below a predefined limit (e.g., < 3x).
- Ensures the provided leverage value is valid.

---

## Circuit Logic

### Delta Neutrality Verification
1. Calculates the absolute difference between the maximum and minimum Delta values.
2. Verifies whether this difference (scaled) satisfies the Delta upper limit constraint.

### Leverage Ratio Verification
1. Ensures the leverage value is non-negative and does not exceed the predefined limit.
2. Confirms that the provided leverage value matches the computed result.

### Boundary Condition Validation
- Verifies that input values (e.g., `DeltaUpper` and `LeverageUpper`) are within reasonable ranges.

---

## Dependencies
- **Gnark**: Library for building and verifying zk-SNARK circuits.
- **gnark-crypto**: Cryptographic primitives supporting the Gnark ecosystem.

---

## Usage

### 1. Compile the Circuit
The circuit is implemented in `ZKRiskNeutralCircuit` and compiled into a constraint system (CCS).
```bash
go run ZKRiskNeutral.go
```
## File Descriptions

- **ZKRiskNeutral.go**: Main project implementation containing circuit logic and file operations.
- **circuit.ccs**: Compiled constraint system representing circuit logic.
- **proving.key & verifying.key**: Generated proving and verifying keys for proof generation and verification.
- **proof.data**: Zero-knowledge proof file generated for a given Witness.

---

## Technical Details

To adapt to zk-SNARK computational constraints:
- All calculations avoid floating-point operations.
- For instance, the Delta upper limit is scaled by multiplying by 100 for percentage adjustments.

The circuit ensures strict validation of input validity and compliance while maintaining privacy.

---

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

Proof file saved as proof.data.

Verification passed, confirming that Delta neutrality and leverage constraints are satisfied.
