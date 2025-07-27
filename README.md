# NusaQuest : Beaches aren't gonna clean themselves. 🚀

## ✨ Overview

🌏 NusaQuest is an impact-to-earn platform powered by AI 🤖 and DAO 🧠, built on the Lisk Sepolia network 🛰️, that turns real-world environmental actions into meaningful digital rewards. Through beach cleanups across Indonesia 🇮🇩, anyone can earn NUSA tokens 💰 and redeem them for NFT concert tickets 🎫. With KYC verification via OCR of KTP 🪪🔍, NusaQuest ensures trusted participation while bridging Web3 🌐 with real-world impact 🌱. It makes caring for the environment fun and rewarding — while empowering communities through transparent, decentralized systems and meaningful incentives.

## 🧩 Architecture

    ```
    ├── smart-contract/
    │   ├── lib/              # External dependencies or libraries (via forge install)
    │   ├── scripts/          # Deployment and automation scripts using Forge
    │   ├── src/              # Main smart contract source files
    │   │   └── lib/          # Contains reusable code like custom errors and event declarations
    │   ├── test/             # Smart contract test files (e.g., unit tests)
    │   ├── .env              # Environment variables (e.g., RPC URL, private key)
    │   ├── .gitignore        # Git ignore rules
    │   ├── .gitmodules       # Tracks git submodules (e.g., external contracts/libs)
    │   ├── Makefile          # Automation commands for building, testing, and deploying
    │   └── foundry.toml      # Foundry configuration file (e.g., compiler version, optimizer)
    ```

## 🧭 How to Run

This project uses [Foundry](https://book.getfoundry.sh/) and a custom `Makefile` for a smoother development experience.  
Just run `make <task>` without remembering long commands!

### 📦 1. Install Foundry

If you haven’t installed Foundry yet:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 📁 2. Clone Repository

```bash
> git clone https://github.com/NusaQuest/smart-contract
> cd smart-contract
```

### 📚 3. Install Dependencies

```bash
> make install
```

### 🔨 4. Compile Contracts

```bash
> make build
```

### 🧪 5. Run Test

```bash
> make test
```

### 🎯 6. Deploy and Verify Contracts

```bash
> make deploy-verify
```

## 🔐 .env Configuration

Before running deploy or verification commands, make sure your `.env` file is properly set up in the root directory.

```env
# 🔑 Private key of your deployer wallet (NEVER share this)
PRIVATE_KEY=your_private_key_here

# 🌐 RPC URL of the target network
RPC_URL=https://sepolia.optimism.io

# 🛡️ Set verifier type: "etherscan" or "blockscout"
VERIFIER=blockscout

# 🔗 Custom verifier URL (needed for blockscout)
VERIFIER_URL=https://sepolia-blockscout.lisk.com/api/


## 🤝 Contributors

- 🧑 Yobel Nathaniel Filipus :
  - 🐙 Github : [View Profile](https://github.com/yebology)
  - 💼 Linkedin : [View Profile](https://linkedin.com/in/yobelnathanielfilipus)
  - 📧 Email : [yobelnathaniel12@gmail.com](mailto:yobelnathaniel12@gmail.com)
```
