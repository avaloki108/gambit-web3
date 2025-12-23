# Gambit Mutation Testing Troubleshooting Playbook

This playbook provides step-by-step guidance for diagnosing and resolving common issues when working with Gambit mutation testing and the Certora Prover integration.

## Table of Contents

- [Quick Diagnostics Checklist](#quick-diagnostics-checklist)
- [Debugging certoraMutate Failures](#debugging-certoramutate-failures)
- [Running Gambit-Only Debug Sessions](#running-gambit-only-debug-sessions)
- [Package Path Configuration Issues](#package-path-configuration-issues)
- [Platform-Specific Caveats](#platform-specific-caveats)
- [Common Error Messages](#common-error-messages)

---

## Quick Diagnostics Checklist

Before diving into specific issues, verify these prerequisites:

```bash
# 1. Check Gambit is installed and accessible
gambit --version

# 2. Check certora-cli is installed
certora-cli --version

# 3. Check certoraMutate is available
which certoraMutate

# 4. Verify Solidity compiler is installed
solc --version
```

If any of these commands fail, see the [Platform-Specific Caveats](#platform-specific-caveats) section.

---

## Debugging certoraMutate Failures

### Step 1: Identify the Failure Type

When `certoraMutate` fails, first determine the failure category:

| Symptom | Likely Cause | Go To |
|---------|--------------|-------|
| "gambit is not built or not in PATH" | Missing binary | [Platform Caveats](#platform-specific-caveats) |
| "Config file does not exist" | Wrong path | [Config Validation](#step-2-validate-configuration-files) |
| No mutants generated | Invalid config | [Step 3](#step-3-check-mutation-generation) |
| Mutants generated but prover fails | Spec/contract issue | [Step 4](#step-4-isolate-prover-issues) |
| Timeout errors | Resource constraints | [Step 5](#step-5-address-timeout-issues) |

### Step 2: Validate Configuration Files

**Check your prover.conf structure:**

```bash
# Validate JSON syntax
cat prover.conf | jq .

# If you see parse errors, fix JSON formatting first
```

**Required fields in mutation config:**

```json
{
  "mutations": {
    "gambit": [
      {
        "filename": "contracts/MyContract.sol",  // Must be valid path
        "num_mutants": 5,                        // Positive integer
        "mutation_operators": ["binary_operator"] // Valid operators
      }
    ]
  }
}
```

**Valid mutation operators:**

- `binary_operator` / `binary-op-mutation`
- `unary_operator` / `unary-operator-mutation`
- `require_statement` / `require-mutation`
- `assignment` / `assignment-mutation`
- `function_call` / `function-call-mutation`
- `if_statement` / `if-statement-mutation`
- `swap_arguments_function` / `swap-arguments-function-mutation`
- `swap_arguments_operator` / `swap-arguments-operator-mutation`
- `swap_lines` / `swap-lines-mutation`
- `delete_expression` / `delete-expression-mutation`
- `eliminate_delegate` / `elim-delegate-mutation`

### Step 3: Check Mutation Generation

Run Gambit in verbose mode to see detailed output:

```bash
# Run gambit directly to check mutation generation
gambit mutate --json your-config.gconf --outdir ./debug_mutants 2>&1 | tee gambit_debug.log

# Check if mutants were created
ls -la ./debug_mutants/mutants/
```

**If no mutants are generated:**

1. Verify the source file exists at the specified path
2. Check that the contract compiles successfully with solc
3. Ensure mutation operators are valid for the code patterns in your contract

### Step 4: Isolate Prover Issues

If mutants are generated but the prover fails:

```bash
# Test a single mutant manually
certoraMutate --prover_config prover.conf \
              --contract path/to/mutant.sol \
              --spec your_spec.spec \
              --debug

# Check the Certora output directory
ls -la .certora_internal/
```

**Review prover logs:**

```bash
# Find the latest job log
cat .certora_internal/*/logs/*.log | grep -i "error\|fail\|exception"
```

### Step 5: Address Timeout Issues

If mutations time out:

```bash
# Increase timeout in your configuration
# In prover.conf or gambit config:
{
  "mutation_timeout": 600,  // Increase from default 300
  "smt_timeout": 120        // Increase SMT solver timeout
}
```

**Resource optimization tips:**

1. Reduce `num_mutants` for initial testing
2. Limit mutation operators to most relevant ones
3. Run on fewer functions using `functions_to_mutate` filter

---

## Running Gambit-Only Debug Sessions

When you want to test mutation generation independently of certoraMutate, use this workflow.

### Step 1: Create a Minimal Test Configuration

Create a file named `debug.gconf`:

```json
[
  {
    "filename": "path/to/YourContract.sol",
    "sourceroot": ".",
    "mutations": [
      "binary-op-mutation"
    ]
  }
]
```

### Step 2: Run Gambit Standalone

```bash
# Generate mutants with verbose output
gambit mutate --json debug.gconf --outdir ./gambit_debug_output

# Check execution status
echo "Exit code: $?"
```

### Step 3: Inspect Generated Mutants

**Location of generated mutants:**

```
gambit_debug_output/
├── gambit_results.json      # Summary of all mutations
├── input_json/              # Parsed AST files
│   └── YourContract.sol_json.ast.json
└── mutants/
    ├── 1/
    │   └── path/to/YourContract.sol
    ├── 2/
    │   └── path/to/YourContract.sol
    └── ...
```

**Examine the mutation summary:**

```bash
# View all generated mutations
cat gambit_debug_output/gambit_results.json | jq .

# Count mutants by type
cat gambit_debug_output/gambit_results.json | jq '[.[] | .operator] | group_by(.) | map({operator: .[0], count: length})'
```

**Compare original vs mutant:**

```bash
# View differences for mutant #1
diff -u path/to/YourContract.sol gambit_debug_output/mutants/1/path/to/YourContract.sol

# Side-by-side comparison
diff -y path/to/YourContract.sol gambit_debug_output/mutants/1/path/to/YourContract.sol | head -50
```

### Step 4: Verify Mutant Compilability

```bash
# Test that each mutant compiles
for mutant_dir in gambit_debug_output/mutants/*/; do
  mutant_num=$(basename "$mutant_dir")
  sol_file=$(find "$mutant_dir" -name "*.sol" | head -1)
  echo "Testing mutant #$mutant_num..."
  if solc "$sol_file" --bin 2>/dev/null; then
    echo "  ✓ Compiles"
  else
    echo "  ✗ Compilation failed"
  fi
done
```

### Step 5: Debug Specific Mutants

If a specific mutant causes issues:

```bash
# Extract mutant details from results
cat gambit_debug_output/gambit_results.json | jq '.[] | select(.id == 5)'

# View the mutation location and type
cat gambit_debug_output/gambit_results.json | jq '.[] | select(.id == 5) | {id, operator, original, replacement, line}'
```

---

## Package Path Configuration Issues

### Common Path Problems

#### Issue: Paths Ending with "/"

**Problem:** Package paths should NOT end with a trailing slash.

```json
// ❌ INCORRECT - trailing slash
{
  "solc_remappings": {
    "@openzeppelin/": "node_modules/@openzeppelin/"
  }
}

// ✅ CORRECT - no trailing slash
{
  "solc_remappings": {
    "@openzeppelin": "node_modules/@openzeppelin"
  }
}
```

**Validation script to check for trailing slashes:**

```bash
#!/bin/bash
# save as: check_paths.sh

CONFIG_FILE="${1:-gambit.json}"

echo "Checking configuration file: $CONFIG_FILE"
echo "==========================================="

# Check for trailing slashes in paths
if grep -E '": ".*/$' "$CONFIG_FILE"; then
  echo ""
  echo "⚠️  WARNING: Found paths ending with '/'"
  echo "Remove trailing slashes from all path values."
  exit 1
fi

# Check sourceroot
SOURCEROOT=$(jq -r '.sourceroot // empty' "$CONFIG_FILE")
if [[ "$SOURCEROOT" == */ ]]; then
  echo "⚠️  WARNING: sourceroot ends with '/': $SOURCEROOT"
  exit 1
fi

# Check filename paths
jq -r '.. | .filename? // empty' "$CONFIG_FILE" 2>/dev/null | while read -r filepath; do
  if [[ "$filepath" == */ ]]; then
    echo "⚠️  WARNING: filename ends with '/': $filepath"
  fi
done

echo "✓ No trailing slash issues found"
```

**Run the validation:**

```bash
chmod +x check_paths.sh
./check_paths.sh your-config.json
```

#### Issue: Relative vs Absolute Paths

**Best practice:** Use relative paths from the project root.

```json
{
  "filename": "contracts/MyContract.sol",     // ✅ Relative
  "filename": "./contracts/MyContract.sol",   // ✅ Also valid
  "filename": "/home/user/project/contracts/MyContract.sol"  // ❌ Avoid absolute
}
```

#### Issue: sourceroot Misconfiguration

The `sourceroot` field affects how paths are resolved:

```json
// If your project structure is:
// project/
//   ├── contracts/
//   │   └── MyContract.sol
//   └── gambit.json

// Configuration in project/gambit.json:
{
  "filename": "contracts/MyContract.sol",
  "sourceroot": "."  // Relative to gambit.json location
}

// If running from project/config/ subdirectory:
{
  "filename": "../contracts/MyContract.sol",
  "sourceroot": ".."
}
```

### Path Debugging Commands

```bash
# Verify file exists at configured path
jq -r '.filename' gambit.json | xargs ls -la

# Check all referenced files exist
jq -r '.. | .filename? // empty' config.gconf 2>/dev/null | while read -r f; do
  if [[ -f "$f" ]]; then
    echo "✓ Found: $f"
  else
    echo "✗ Missing: $f"
  fi
done

# Resolve paths relative to sourceroot
SOURCEROOT=$(jq -r '.sourceroot // "."' gambit.json)
FILENAME=$(jq -r '.filename' gambit.json)
RESOLVED="$SOURCEROOT/$FILENAME"
echo "Resolved path: $RESOLVED"
ls -la "$RESOLVED"
```

---

## Platform-Specific Caveats

### Supported Platforms

| Platform | Architecture | Binary Available | Build Required |
|----------|-------------|------------------|----------------|
| Linux | x86_64 | ✅ Yes | Optional |
| macOS | x86_64 (Intel) | ✅ Yes | Optional |
| macOS | aarch64 (Apple Silicon) | ✅ Yes | Optional |
| Windows | x86_64 | ❌ No | **Required** |
| Linux | ARM64 | ❌ No | **Required** |

### Linux x86_64

**Pre-built binary installation:**

```bash
# Download from releases (if available)
curl -LO https://github.com/Certora/gambit/releases/latest/download/gambit-linux-x86_64
chmod +x gambit-linux-x86_64
sudo mv gambit-linux-x86_64 /usr/local/bin/gambit
```

**Build from source:**

```bash
# Install Rust if not present
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Clone and build
git clone https://github.com/Certora/gambit.git
cd gambit
make linux

# Verify installation
gambit --version
```

### macOS (Intel and Apple Silicon)

**Pre-built binary installation:**

For Intel Macs:
```bash
curl -LO https://github.com/Certora/gambit/releases/latest/download/gambit-macos-x86_64
chmod +x gambit-macos-x86_64
sudo mv gambit-macos-x86_64 /usr/local/bin/gambit
```

For Apple Silicon Macs:
```bash
curl -LO https://github.com/Certora/gambit/releases/latest/download/gambit-macos-aarch64
chmod +x gambit-macos-aarch64
sudo mv gambit-macos-aarch64 /usr/local/bin/gambit
```

**Build from source:**

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Clone and build (handles both architectures)
git clone https://github.com/Certora/gambit.git
cd gambit
make macos

# Verify
gambit --version
```

**Troubleshooting macOS Gatekeeper:**

If you see "cannot be opened because the developer cannot be verified":

```bash
# Option 1: Remove quarantine attribute
xattr -d com.apple.quarantine /usr/local/bin/gambit

# Option 2: Allow in System Preferences
# Go to: System Preferences > Security & Privacy > General
# Click "Allow Anyway" for gambit
```

### Windows (WSL Required)

Gambit does not have native Windows binaries. Use Windows Subsystem for Linux (WSL):

```bash
# 1. Install WSL2 (in PowerShell as Administrator)
wsl --install

# 2. After restart, open WSL terminal and follow Linux instructions
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Clone and build
git clone https://github.com/Certora/gambit.git
cd gambit
cargo build --release
cargo install --path . --force
```

### Linux ARM64 (Raspberry Pi, AWS Graviton, etc.)

Build from source is required:

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Clone and build
git clone https://github.com/Certora/gambit.git
cd gambit
cargo build --release --target aarch64-unknown-linux-gnu
cargo install --path . --force

# Verify
gambit --version
```

### Docker Alternative (All Platforms)

If you cannot install Gambit natively, use Docker:

```dockerfile
# Dockerfile
FROM rust:1.70 as builder
WORKDIR /gambit
RUN git clone https://github.com/Certora/gambit.git .
RUN cargo build --release

FROM debian:bullseye-slim
COPY --from=builder /gambit/target/release/gambit /usr/local/bin/
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["gambit"]
```

**Build and run:**

```bash
docker build -t gambit .
docker run -v $(pwd):/workspace -w /workspace gambit mutate --json config.gconf
```

---

## Common Error Messages

### "Error: gambit is not built or not in PATH"

**Solution:**

```bash
# Check if gambit is in PATH
which gambit

# If not found, add to PATH (after building)
export PATH="$PATH:$HOME/.cargo/bin"

# Make permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export PATH="$PATH:$HOME/.cargo/bin"' >> ~/.bashrc
source ~/.bashrc
```

### "Error: Config file 'X' does not exist"

**Solution:**

```bash
# Verify the file exists
ls -la your-config.json

# Use absolute path if relative path issues
./scripts/mutate.sh --json "$(pwd)/your-config.json"
```

### "Error: Could not extract filename from config"

**Solution:**

Ensure your config has the required `filename` field:

```json
{
  "filename": "contracts/MyContract.sol",
  "contract_name": "MyContract"
}
```

### "solc not found" or Compilation Errors

**Solution:**

```bash
# Install solc via solc-select
pip install solc-select
solc-select install 0.8.20
solc-select use 0.8.20

# Verify
solc --version
```

### "No mutants were generated"

**Possible causes and solutions:**

1. **Empty or trivial contract:** Add meaningful code to mutate
2. **Invalid mutation operators:** Use operators that match your code patterns
3. **Solidity version mismatch:** Ensure solc version matches pragma

```bash
# Debug: run with verbose output
gambit mutate --json config.gconf --outdir ./debug 2>&1 | tee debug.log
grep -i "error\|warning\|skip" debug.log
```

### "Mutation testing timed out"

**Solution:**

```json
{
  "mutation_timeout": 600,
  "num_mutants": 3
}
```

Start with fewer mutants and increase gradually.

---

## Getting Help

If you're still experiencing issues:

1. **Check the issue tracker:** [GitHub Issues](https://github.com/Certora/gambit/issues)
2. **Enable debug logging:**
   ```bash
   RUST_LOG=debug gambit mutate --json config.gconf 2>&1 | tee full_debug.log
   ```
3. **Include in bug reports:**
   - Operating system and version
   - Gambit version (`gambit --version`)
   - Full command line used
   - Configuration file (sanitized of sensitive data)
   - Error output
   - Debug log if available