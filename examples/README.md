# Gambit Mutation Testing Example

This directory contains a minimal end-to-end example demonstrating the Gambit mutation testing workflow.

## Files

- `SimpleMath.sol`: A simple Solidity contract with basic arithmetic operations
- `SimpleMath.spec`: A CVL specification for the contract (minimal example)
- `prover.conf`: Configuration file for mutation testing

## Running the Workflow

### Prerequisites

1. Install Gambit mutation testing tool
2. Install Certora Prover
3. Ensure you have the required dependencies installed

### Commands

#### 1. Run Gambit Mutate (Optional)

```bash
# Generate mutants using Gambit
gambit mutate --config examples/prover.conf
```

This will generate mutant versions of the SimpleMath contract in the output directory.

#### 2. Run Certora Mutate (Required)

```bash
# Run mutation testing with Certora Prover
certoraMutate --prover_config examples/prover.conf \
              --contract examples/SimpleMath.sol \
              --spec examples/SimpleMath.spec
```

This will:
1. Generate mutants based on the configuration
2. Run the Certora Prover on each mutant
3. Report which mutants were killed (detected) and which survived (undetected)

#### 3. Expected Output

The workflow should:
- Generate 5 mutants (as specified in prover.conf)
- Run the CVL specification against each mutant
- Report the mutation score and details about killed/survived mutants

## Configuration Details

The `prover.conf` file specifies:
- `num_mutants`: 5 mutants to generate
- `mutation_operators`: binary_operator, unary_operator, and require_statement mutations
- Target file: `examples/SimpleMath.sol`

## Notes

- This is a minimal example for demonstration purposes
- The CVL spec is intentionally simple to focus on the mutation workflow
- For real-world usage, you would want more comprehensive specifications