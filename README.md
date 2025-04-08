# sBTC Yield Vaults - Smart Contract Documentation

## Overview

A non-custodial yield aggregation protocol enabling sBTC holders to optimize Bitcoin-native yield generation through automated strategy allocation on Stacks L2. Combines Clarity's verifiable smart contracts with Bitcoin's security model for trustless operations.

## Key Features

- **Multi-Strategy Architecture**: Simultaneous support for 5 yield protocols
- **Dynamic Allocation Engine**: Auto-balances deposits across strategies based on:
  - Protocol-specific APY (0.01% precision)
  - Risk-adjusted allocation caps (1-100%)
  - Real-time TVL utilization
- **Block-Based Yield Accrual**: Interest calculated per block (52596 blocks/year basis)
- **Institutional-Grade Safeguards**:
  - Multi-sig protocol administration
  - Strategy-specific circuit breakers
  - Deposit amount ceilings (1B satoshi equivalent)
- **Compliance-Ready Design**:
  - Immutable deposit audit trails
  - Principal/yield separation tracking
  - Withdrawal request nonce protection

## Technical Architecture

### Core Components

1. **Strategy Registry**  
   `supported-protocols` map storing:

   - Protocol ID (1-5)
   - APY (100% = 1,000,000 units)
   - Allocation cap (% of total TVL)
   - Activation status

2. **Deposit Ledger**  
   Nested mapping structure:

   - User-level: `user-deposits` tracks per-strategy positions
   - Protocol-level: `protocol-total-deposits` aggregates TVL

3. **Yield Computer**  
   Real-time APR calculation via:
   ```
   Accrued Yield = (Base APY * Deposit Amount * Elapsed Blocks) / 52596
   ```

### Security Model

- **Bitcoin-Anchored**: Settlements finalized on Bitcoin L1
- **Clarity Runtime**: Deterministic execution prevents:
  - Reentrancy attacks
  - Integer overflows
  - Unauthorized state changes
- **Circuit Breakers**:
  - Protocol deactivation triggers
  - Hard TVL limits per strategy
  - 24-hour withdrawal cooldown (block-based)

## User Flow

### Deposit Process

1. User calls `deposit(protocol-id, amount)`
2. System:
   - Validates protocol active status
   - Checks allocation cap availability
   - Updates user position & protocol TVL
3. sBTC transferred to target strategy contract

### Yield Accrual

- Computed on-demand during withdrawals
- Block-based calculation:
  ```clarity
  annual_yield = (protocol_apy * deposit_amount) / 1,000,000
  blocks_yield = (annual_yield * elapsed_blocks) / 52596
  ```

### Withdrawal Process

1. User calls `withdraw(protocol-id, amount)`
2. System:
   - Calculates accrued yield
   - Burns vault shares
   - Transfers principal + yield
   - Updates TVL records

## Core Functions

### Protocol Management

| Function              | Parameters                           | Description                           |
| --------------------- | ------------------------------------ | ------------------------------------- |
| `add-protocol`        | (protocol-id, name, apy, allocation) | Governance-only strategy whitelisting |
| `deactivate-protocol` | (protocol-id)                        | Emergency protocol suspension         |

### User Operations

| Function   | Parameters            | Description                        |
| ---------- | --------------------- | ---------------------------------- |
| `deposit`  | (protocol-id, amount) | Allocate sBTC to yield strategy    |
| `withdraw` | (protocol-id, amount) | Withdraw principal + accrued yield |

### View Functions

| Function            | Parameters          | Output                       |
| ------------------- | ------------------- | ---------------------------- |
| `calculate-yield`   | (protocol-id, user) | Returns accrued yield amount |
| `get-protocol-info` | (protocol-id)       | Returns strategy parameters  |

## Security Parameters

### Error Codes

| Code | Description          | Trigger Condition               |
| ---- | -------------------- | ------------------------------- |
| u1   | Unauthorized access  | Non-admin protocol modification |
| u2   | Insufficient balance | Over-withdrawal attempt         |
| u3   | Invalid protocol     | Disabled strategy access        |
| u4   | Withdrawal failure   | Yield transfer error            |
| u5   | Deposit failure      | Strategy allocation error       |
| u6   | Capacity exceeded    | TVL limit violation             |
| u7   | Invalid input        | Parameter validation failure    |

### Risk Controls

- **Deposit Limits**: 1,000,000,000 sats per transaction
- **APY Ceiling**: 100.00% maximum
- **Strategy Caps**: 1-100% of total TVL
- **Admin Safeguards**: 3/5 multi-sig required for:
  - Protocol additions
  - Emergency deactivations
  - Parameter updates

## Development Guide

### Prerequisites

- Clarinet SDK v2.0.0+
- Stacks.js v6.0.0+
- sBTC testnet token
