# ZbFrCircuit: Zero-Knowledge Financial Risk Assessment and Leverage Constraint Circuit with Gnark

## Overview

**ZbFrCircuit** demonstrates how to construct a zk-SNARK circuit using the Gnark library. This circuit evaluates financial risk parameters, including Delta risk neutrality and leverage constraints, and verifies whether they meet predefined conditions. Operating in a zero-knowledge environment, the circuit ensures input data privacy while providing proof of compliance.

---

## Key Features

### Delta Risk Assessment
- **Delta Value Constraints:** 
  - **DeltaSpot** must be non-negative.
  - **DeltaPerpLong** must be non-negative.
  - **DeltaPerpShort** must be non-positive.
- **Risk Neutrality Ratio Constraint:**  
  The circuit computes the ratio of the absolute total exposure (i.e., `|DeltaPerpLong + DeltaPerpShort + DeltaSpot|`) scaled by 100 to the maximum exposure between `DeltaSpot` and the absolute value of `DeltaPerpLong + DeltaPerpShort`. This ratio is required to be less than or equal to the public parameter `DeltaUpper` (expressed as a percentage).

### Leverage Constraint
- **Leverage Lower Bound:** The provided `Leverage` must be at least 1.
- **Upper Limit Enforcement:** Using a public input `LeverageUpper`, the circuit ensures that the actual `Leverage` does not exceed this upper bound.

### Public Inputs and Validation
- **Public Inputs:** The circuit exposes three public variables:
  - `LeverageUpper` – Maximum allowed leverage (0–100 scale).
  - `DeltaUpper` – Upper limit for the delta risk neutrality ratio (0–100 scale).
  - `ProjectId` – Fixed project identifier (must be 10005).
- **Boundary Checks:** Both `DeltaUpper` and `LeverageUpper` are checked to be within the range of 0 to 100.

---

## Usage

### 1. Compile and Save the Circuit

The circuit is defined in the `ZbFrCircuit` struct and compiled into a constraint system (CCS). Upon compilation, the following files are generated:
- **circuit.ccs:** Compiled constraint system file.
- **proving.key & verifying.key:** Keys for generating and verifying proofs.

### 2. Generating Proofs

The main routine:
- Compiles the circuit.
- Performs a trusted setup using `groth16.Setup`.
- Creates a witness from an assignment.
- Generates a zero-knowledge proof.
- Saves the proof (both in raw binary and JSON format).

Additionally, JSON exports are created for:
- **gnark_vk.json:** The verifying key in JSON format.
- **gnark_inputs.json:** The public witness (input values) in JSON format.
- **gnark_proof.json:** The proof in JSON format.

### 3. Verification

After generating the proof, the code demonstrates:
- Loading the proof and keys from disk.
- Verifying the proof against the public witness to ensure all constraints are met.

### 4. Running the Circuit

To compile the circuit, generate the keys, produce a proof, and perform verification, simply run:

```bash
go run zb_fr.go
```

---

## Technical Details

- **No Floating-Point Arithmetic:**  
  All calculations are performed using integer arithmetic with scaling (e.g., percentages are scaled by 100) to accommodate zk-SNARK arithmetic constraints.
  
- **Comparator Helpers:**  
  The circuit leverages bounded comparators from the Gnark standard library to enforce inequality constraints and to calculate maximum values.

- **Conditional Selections:**  
  The circuit uses conditional selection to correctly compute absolute values and maximum exposures, ensuring robust delta risk evaluation.

---

## Example Assignment

Below is an example of an assignment used to generate a witness for the circuit:

```go
assignment := ZbFrCircuit{
    Leverage:       1,    // Actual leverage ratio
    DeltaSpot:      0,    // Spot delta exposure (non-negative)
    DeltaPerpLong:  0,    // Perpetual long delta exposure (non-negative)
    DeltaPerpShort: 0,    // Perpetual short delta exposure (non-positive)
    LeverageUpper:  3,    // Maximum allowed leverage (public input, 0–100)
    DeltaUpper:     5,    // Delta risk neutrality upper limit (public input, as a percentage)
    ProjectId:      10005 // Fixed project identifier
}
```

---

## Output

After successful execution:
- The CCS, keys, and proof files will be saved.
- The proof will be verified, confirming that both the delta risk neutrality and leverage constraints are satisfied under the provided assignment.

