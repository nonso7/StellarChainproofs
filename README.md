# ⛓️ ChainProof

**Smart Contract Audit Copilot** — real-time vulnerability scanner, gas advisor, and audit report generator for Solidity.

---

## Why ChainProof?

- 🔴 **$1.8B+ lost** to smart contract exploits in 2023 — most are preventable
- 🐢 **6-week wait** for professional audits, costing $30k–$100k
- 🌍 **Zero accessible tooling** for indie devs and small DAOs in emerging markets

ChainProof gives every developer a security copilot in their editor, CLI, and CI pipeline.

---

## Monorepo Structure

```
chainproof/
├── packages/
│   ├── core/               # Shared scanning engine
│   │   └── src/
│   │       ├── ast/        # Solidity parser + Slither wrapper
│   │       ├── rules/      # SWC vulnerability detectors
│   │       ├── llm/        # AI-powered explanation layer
│   │       └── report/     # Markdown / JSON / table generators
│   ├── cli/                # `chainproof` CLI tool
│   ├── vscode-extension/   # VS Code extension with inline diagnostics
│   └── github-action/      # GitHub Action for CI/CD gates
├── examples/
│   └── contracts/
│       ├── VulnerableVault.sol   # Intentionally vulnerable (test target)
│       └── SecureVault.sol       # Fixed version
└── .github/workflows/audit.yml   # CI pipeline example
```

---

## Quick Start

### CLI

```bash
# Install globally
npm install -g @chainproof/cli

# Scan a file or directory
chainproof scan contracts/

# Scan with LLM enhancement
chainproof scan contracts/ --api-key YOUR_ANTHROPIC_KEY

# Generate a markdown audit report
chainproof scan contracts/ --format markdown --output audit.md

# Fast CI check (exits 1 on critical/high)
chainproof check contracts/

# Create a config file
chainproof init
```

### VS Code Extension

1. Install from the VS Code Marketplace (search "ChainProof")
2. Open any `.sol` file — diagnostics appear automatically
3. Right-click → **ChainProof: Scan Current File**
4. Command Palette → **ChainProof: Generate Audit Report**

Configure in Settings → ChainProof:
- `chainproof.enableOnSave` — auto-scan on save (default: true)
- `chainproof.useSlither` — enable Slither (default: true)
- `chainproof.useLLM` — enable AI explanations (default: false)
- `chainproof.apiKey` — Anthropic API key
- `chainproof.minSeverity` — minimum severity to show

### GitHub Action

```yaml
# .github/workflows/audit.yml
- name: ChainProof Audit
  uses: your-org/chainproof@v1
  with:
    targets: "contracts/"
    min-severity: "high"
    use-slither: "true"
    api-key: ${{ secrets.ANTHROPIC_API_KEY }}
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

The action will:
- ✅ Scan all `.sol` files in `contracts/`
- 💬 Post a summary comment on PRs
- 📎 Upload the full audit report as an artifact
- ❌ Fail CI if critical/high findings are detected
- 📝 Annotate the changed files with inline findings

---

## Vulnerability Rules

| ID | SWC | Name | Severity |
|----|-----|------|----------|
| CP-107 | SWC-107 | Reentrancy | 🔴 Critical |
| CP-115 | SWC-115 | tx.origin authentication | 🟠 High |
| CP-101 | SWC-101 | Integer overflow / underflow | 🟠 High |
| CP-104 | SWC-104 | Unchecked call return value | 🟡 Medium |
| GAS-* | — | Gas optimizations | ⛽ Gas |

Plus all [Slither detectors](https://github.com/crytic/slither/wiki/Detector-Documentation) when Slither is installed.

---

## Development

### Prerequisites

- Node.js ≥ 18
- Python ≥ 3.10 (for Slither)
- `pip install slither-analyzer` (optional but recommended)

### Setup

```bash
git clone https://github.com/your-org/chainproof
cd chainproof
npm install            # installs all workspaces
npm run build          # builds all packages
```

### Test against example contracts

```bash
# After building
node packages/cli/dist/cli.js scan examples/contracts/VulnerableVault.sol

# Expected: critical + high findings
# Then try the secure version:
node packages/cli/dist/cli.js scan examples/contracts/SecureVault.sol
# Expected: clean ✅
```

### Adding a new rule

1. Create `packages/core/src/rules/swcXXX-your-rule.ts`
2. Export a `detectXxx(ast, source, filePath): Finding[]` function
3. Import and call it in `packages/core/src/scanner.ts`
4. Add an entry to the rules table above

### LLM Enhancement

Set your Anthropic API key and pass `--llm`:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
chainproof scan contracts/ --llm
```

Critical and high findings get enhanced with:
- Developer-friendly explanation of the exact risk
- Copy-paste ready fix for the specific code
- Real-world exploit scenario

---

## Roadmap

- [ ] SWC-103: Floating pragma detector
- [ ] SWC-116: Timestamp dependency
- [ ] SWC-120: Weak randomness (block.timestamp / blockhash)
- [ ] Foundry test generation for detected vulnerabilities
- [ ] Hardhat plugin
- [ ] SARIF output for GitHub Security tab
- [ ] Web dashboard with project-level history
- [ ] Support for Vyper

---

## License

MIT © ChainProof Contributors

---

> ⚠️ ChainProof is a developer tool, not a substitute for a professional security audit.
> Always have critical contracts audited by qualified humans before mainnet deployment.
