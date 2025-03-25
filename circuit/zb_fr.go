package main

import (
	"encoding/json"
	"fmt"
	"math"
	"math/big"
	"os"

	"github.com/consensys/gnark-crypto/ecc"
	"github.com/consensys/gnark-crypto/ecc/bn254/fr"
	"github.com/consensys/gnark/backend/groth16"
	"github.com/consensys/gnark/backend/witness"
	"github.com/consensys/gnark/constraint"
	"github.com/consensys/gnark/frontend"
	"github.com/consensys/gnark/frontend/cs/r1cs"
	"github.com/consensys/gnark/std/math/cmp"
)

func SaveToJSON(filePath string, v interface{}) error {
	if witness, ok := v.(witness.Witness); ok {
		rawVector, ok := witness.Vector().(fr.Vector)
		if !ok {
			return fmt.Errorf("failed to assert type of publicWitness.Vector() to fr.Vector")
		}

		witnessPublicStrings := make([]string, len(rawVector))
		for i, val := range rawVector {
			witnessPublicStrings[i] = val.String()
		}

		return SaveToJSON(filePath, witnessPublicStrings)
	}

	jsonData, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal data to JSON: %v", err)
	}

	err = os.WriteFile(filePath, jsonData, 0644)
	if err != nil {
		return fmt.Errorf("failed to save JSON file: %v", err)
	}

	return nil
}

// saveProof 保存proof到文件
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

// loadProof 从文件加载proof
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

// saveCcs 保存r1cs到文件
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

// saveKeys 保存proving key和verification key
func saveKeys(pk groth16.ProvingKey, vk groth16.VerifyingKey, pkPath, vkPath string) error {
	// 保存 proving key
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

	// 保存 verification key
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

// loadKeys 加载proving key和verification key
func loadKeys(pkPath, vkPath string) (groth16.ProvingKey, groth16.VerifyingKey, error) {
	// 加载 proving key
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

	// 加载 verification key
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

type ZbFrCircuit struct {
	Leverage       frontend.Variable
	DeltaSpot      frontend.Variable
	DeltaPerpLong  frontend.Variable
	DeltaPerpShort frontend.Variable
	LeverageUpper  frontend.Variable `gnark:",public"`
	DeltaUpper     frontend.Variable `gnark:",public"`
	ProjectId      frontend.Variable `gnark:",public"`
}

func (circuit *ZbFrCircuit) Define(api frontend.API) error {

	api.AssertIsEqual(circuit.ProjectId, frontend.Variable(10005))

	deltaCheck := cmp.NewBoundedComparator(api, big.NewInt(math.MaxInt64), false)

	deltaCheck.AssertIsLessEq(frontend.Variable(0), circuit.DeltaSpot)
	deltaCheck.AssertIsLessEq(frontend.Variable(0), circuit.DeltaPerpLong)
	deltaCheck.AssertIsLessEq(circuit.DeltaPerpShort, frontend.Variable(0))

	percent := cmp.NewBoundedComparator(api, big.NewInt(100), false)

	api.AssertIsLessOrEqual(circuit.DeltaUpper, frontend.Variable(100))
	percent.AssertIsLessEq(frontend.Variable(0), circuit.DeltaUpper)

	api.AssertIsLessOrEqual(circuit.LeverageUpper, frontend.Variable(100))
	percent.AssertIsLessEq(frontend.Variable(0), circuit.LeverageUpper)

	percent.AssertIsLessEq(frontend.Variable(1), circuit.Leverage)

	api.AssertIsDifferent(api.Cmp(circuit.Leverage, circuit.LeverageUpper), frontend.Variable(1))

	deltaCheck.AssertIsLessEq(api.Add(circuit.DeltaPerpLong, circuit.DeltaPerpShort), frontend.Variable(0))

	net := api.Add(circuit.DeltaPerpLong, circuit.DeltaPerpShort)

	boolHelper := api.IsZero(api.Add(api.Cmp(api.Neg(net), circuit.DeltaSpot), 1))

	max := api.Select(boolHelper, circuit.DeltaSpot, api.Neg(net))

	r1 := api.Select(boolHelper, api.Add(circuit.DeltaPerpLong, circuit.DeltaPerpShort, circuit.DeltaSpot), api.Neg(api.Add(circuit.DeltaPerpLong, circuit.DeltaPerpShort, circuit.DeltaSpot))) // abs(long + short + spot)

	r2 := api.Mul(r1, frontend.Variable(100))
	r3 := api.Mul(circuit.DeltaUpper, max)
	api.AssertIsDifferent(api.Cmp(r2, r3), frontend.Variable(1))
	return nil
}

func main() {

	var circuit ZbFrCircuit
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

	err = SaveToJSON("vk.json", vk)
	if err != nil {
		fmt.Println("Error saving VK to JSON:", err)
		return
	}

	assignment := ZbFrCircuit{1, 0, 0, 0, 3, 5, 10005}

	witness, err := frontend.NewWitness(&assignment, ecc.BN254.ScalarField())
	if err != nil {
		panic(fmt.Errorf("witness error: %w", err))
	}

	publicWitness, err := witness.Public()
	if err != nil {
		panic(fmt.Errorf("public witness error: %w", err))
	}
	fmt.Println("Public witness:", publicWitness.Vector().(fr.Vector))

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
