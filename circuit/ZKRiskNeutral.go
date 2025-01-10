package main

import (
	"fmt"
	"os"

	"github.com/consensys/gnark-crypto/ecc"
	"github.com/consensys/gnark/backend/groth16"
	"github.com/consensys/gnark/constraint"
	"github.com/consensys/gnark/frontend"
	"github.com/consensys/gnark/frontend/cs/r1cs"
)

func saveProof(proof groth16.Proof, path string) error {
	file, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("failed to create proof file: %w", err)
	}
	defer func(file *os.File) {
		err := file.Close()
		if err != nil {
			fmt.Println("failed to close file")
		}
	}(file)

	_, err = proof.WriteRawTo(file)
	if err != nil {
		return fmt.Errorf("failed to write proof: %w", err)
	}
	return nil
}

func loadProof(path string) (groth16.Proof, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("failed to open proof file: %w", err)
	}
	defer func(file *os.File) {
		err := file.Close()
		if err != nil {
			fmt.Println("failed to close file")
		}
	}(file)

	proof := groth16.NewProof(ecc.BN254)
	_, err = proof.ReadFrom(file)
	if err != nil {
		return nil, fmt.Errorf("failed to read proof: %w", err)
	}
	return proof, nil
}

func saveCcs(ccs constraint.ConstraintSystem, path string) error {
	file, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("failed to create ccs file: %w", err)
	}
	defer func(file *os.File) {
		err := file.Close()
		if err != nil {
			fmt.Println("failed to close file")
		}
	}(file)

	_, err = ccs.WriteTo(file)
	if err != nil {
		return fmt.Errorf("failed to write ccs: %w", err)
	}

	return nil
}

func saveKeys(pk groth16.ProvingKey, vk groth16.VerifyingKey, pkPath, vkPath string) error {
	pkFile, err := os.Create(pkPath)
	if err != nil {
		return fmt.Errorf("failed to create pk file: %w", err)
	}
	defer func(pkFile *os.File) {
		err := pkFile.Close()
		if err != nil {
			fmt.Println("failed to close file")
		}
	}(pkFile)

	_, err = pk.WriteRawTo(pkFile)
	if err != nil {
		return fmt.Errorf("failed to write pk: %w", err)
	}

	vkFile, err := os.Create(vkPath)
	if err != nil {
		return fmt.Errorf("failed to create vk file: %w", err)
	}
	defer func(vkFile *os.File) {
		err := vkFile.Close()
		if err != nil {
			fmt.Println("failed to close file")
		}
	}(vkFile)

	_, err = vk.WriteRawTo(vkFile)
	if err != nil {
		return fmt.Errorf("failed to write vk: %w", err)
	}

	return nil
}

func loadKeys(pkPath, vkPath string) (groth16.ProvingKey, groth16.VerifyingKey, error) {
	pkFile, err := os.Open(pkPath)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to open pk file: %w", err)
	}
	defer func(pkFile *os.File) {
		err := pkFile.Close()
		if err != nil {
			fmt.Println("failed to close file")
		}
	}(pkFile)

	pk := groth16.NewProvingKey(ecc.BN254)
	_, err = pk.ReadFrom(pkFile)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to read pk: %w", err)
	}

	vkFile, err := os.Open(vkPath)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to open vk file: %w", err)
	}
	defer func(vkFile *os.File) {
		err := vkFile.Close()
		if err != nil {
			fmt.Println("failed to close file")
		}
	}(vkFile)

	vk := groth16.NewVerifyingKey(ecc.BN254)
	_, err = vk.ReadFrom(vkFile)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to read vk: %w", err)
	}

	return pk, vk, nil
}

type ZKRiskNeutralCircuit struct {
	Leverage        frontend.Variable `gnark:"leverage"`
	DeltaMax        frontend.Variable `gnark:"deltaMax"`
	DeltaMin        frontend.Variable `gnark:"deltaMin"`
	LeverageUpper   frontend.Variable `gnark:"leverageUpper,public"`
	DeltaUpper      frontend.Variable `gnark:"deltaUpper,public"`
	LeverageConfirm frontend.Variable `gnark:"leverageConfirm,public"`
	DeltaConfirm    frontend.Variable `gnark:"deltaConfirm,public"`
}

func (circuit *ZKRiskNeutralCircuit) Define(api frontend.API) error {

	api.AssertIsLessOrEqual(circuit.DeltaMin, circuit.DeltaMax)
	api.AssertIsLessOrEqual(0, circuit.DeltaMin)

	api.AssertIsLessOrEqual(circuit.DeltaUpper, 100)
	api.AssertIsLessOrEqual(0, circuit.DeltaUpper)

	api.AssertIsLessOrEqual(0, circuit.LeverageUpper)
	api.AssertIsLessOrEqual(circuit.LeverageUpper, 100)

	api.AssertIsLessOrEqual(0, circuit.Leverage)

	api.AssertIsEqual(api.Cmp(circuit.Leverage, circuit.LeverageUpper), circuit.LeverageConfirm)

	r1 := api.Sub(circuit.DeltaMax, circuit.DeltaMin)
	r2 := api.Mul(r1, 100)
	r3 := api.Mul(circuit.DeltaUpper, circuit.DeltaMax)
	api.AssertIsEqual(api.Cmp(r2, r3), circuit.DeltaConfirm)
	return nil
}

func main() {

	var circuit ZKRiskNeutralCircuit
	ccs, err := frontend.Compile(ecc.BN254.ScalarField(), r1cs.NewBuilder, &circuit)
	if err != nil {
		panic(fmt.Errorf("compile error: %w", err))
	}
	err = saveCcs(ccs, "circuit.ccs")
	if err != nil {
		panic(fmt.Errorf("save CCS error: %w", err))
	}
	fmt.Println("CCS saved successfully")

	pk, vk, err := groth16.Setup(ccs)
	if err != nil {
		panic(fmt.Errorf("setup error: %w", err))
	}

	err = saveKeys(pk, vk, "proving.key", "verifying.key")
	if err != nil {
		panic(fmt.Errorf("save keys error: %w", err))
	}
	fmt.Println("Keys saved successfully")

	assignment := ZKRiskNeutralCircuit{1, 100, 99, 3, 5, -1, -1}
	witness, err := frontend.NewWitness(&assignment, ecc.BN254.ScalarField())
	if err != nil {
		panic(fmt.Errorf("witness error: %w", err))
	}

	publicWitness, err := witness.Public()
	if err != nil {
		panic(fmt.Errorf("public witness error: %w", err))
	}

	proof, err := groth16.Prove(ccs, pk, witness)
	if err != nil {
		panic(fmt.Errorf("prove error: %w", err))
	}

	err = saveProof(proof, "proof.data")
	if err != nil {
		panic(fmt.Errorf("save proof error: %w", err))
	}
	fmt.Println("Proof saved successfully")

	loadedProof, err := loadProof("proof.data")
	if err != nil {
		panic(fmt.Errorf("load proof error: %w", err))
	}

	_, loadedVk, err := loadKeys("proving.key", "verifying.key")
	if err != nil {
		panic(fmt.Errorf("load keys error: %w", err))
	}

	err = groth16.Verify(loadedProof, loadedVk, publicWitness)
	if err != nil {
		panic(fmt.Errorf("verify error: %w", err))
	}
	fmt.Println("Proof verified successfully!")
}
