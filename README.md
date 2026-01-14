# 🚰 Test Token Faucet

A rate-limited token faucet smart contract built with Clarity for Stacks blockchain. Perfect for learning token mechanics and rate limiting patterns! 💧

## 🌟 Features

- 🪙 **SIP-010 Compliant**: Standard fungible token implementation
- ⏰ **Rate Limiting**: Users can only claim tokens once per cooldown period
- 🔧 **Admin Controls**: Owner can configure faucet parameters
- 🛡️ **Security**: Built-in protection against abuse
- 📊 **Transparency**: Full balance and allowance tracking
- 💰 **Flexible Claims**: Configurable claim amounts and cooldowns

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) installed
- Basic understanding of Clarity smart contracts

### Installation

1. Clone this repository
2. Navigate to the project directory
3. Run `clarinet check` to validate the contract

### Usage

#### 💧 Claiming Tokens

```clarity
(contract-call? .test-token-faucet claim-tokens)
```

Users can claim test tokens once per cooldown period (default: 24 hours).

#### 🔍 Check Eligibility

```clarity
(contract-call? .test-token-faucet can-claim 'SP1234567890ABCDEF)
```

#### ⏳ Time Until Next Claim

```clarity
(contract-call? .test-token-faucet time-until-next-claim 'SP1234567890ABCDEF)
```

#### 💰 Check Balance

```clarity
(contract-call? .test-token-faucet get-balance 'SP1234567890ABCDEF)
```

#### 📤 Transfer Tokens

```clarity
(contract-call? .test-token-faucet transfer u1000 tx-sender 'SP1234567890ABCDEF none)
```

## 🛠️ Admin Functions

### 🎛️ Configure Faucet Amount

```clarity
(contract-call? .test-token-faucet set-faucet-amount u2000000)
```

### ⏱️ Set Claim Cooldown

```clarity
(contract-call? .test-token-faucet set-claim-cooldown u43200)
```

### 🔄 Toggle Faucet On/Off

```clarity
(contract-call? .test-token-faucet toggle-faucet)
```

### 🏭 Admin Mint

```clarity
(contract-call? .test-token-faucet admin-mint 'SP1234567890ABCDEF u5000000)
```

### 🔥 Admin Burn

```clarity
(contract-call? .test-token-faucet admin-burn u1000000)
```

## 📋 Contract Details

### Token Information
- **Name**: Test Token
- **Symbol**: TEST
- **Decimals**: 6
- **Default Faucet Amount**: 1,000,000 tokens (1 TEST)
- **Default Cooldown**: 86,400 blocks (~24 hours)
- **Max Supply**: 100,000,000,000,000 tokens

### Error Codes
- `u100`: Owner only action
- `u101`: Not token owner
- `u102`: Insufficient balance
- `u103`: Already claimed (deprecated)
- `u104`: Claim too soon
- `u105`: Invalid amount
- `u106`: Faucet disabled
- `u107`: Invalid recipient

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

## 📖 Learning Objectives

This contract teaches:

1. **Rate Limiting**: How to implement time-based restrictions
2. **Token Standards**: SIP-010 fungible token implementation
3. **Access Control**: Owner-only administrative functions
4. **State Management**: Using maps and data variables effectively
5. **Error Handling**: Proper assertion and error reporting
6. **Event Logging**: Using print statements for transparency

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Useful Links

- [Stacks Documentation](https://docs.stacks.co)
- [Clarity Language Reference](https://docs.stacks.co/clarity)
- [SIP-010 Token Standard](https://github.com/stacksgov/sips/blob/main/sips/sip-010/sip-010-fungible-token-standard.md)

---

Built with ❤️ for the Stacks ecosystem
