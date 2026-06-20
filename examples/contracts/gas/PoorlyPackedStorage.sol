// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * PoorlyPackedStorage — intentionally bad struct/state-variable layout.
 * ChainProof should emit GAS-PACK-001 and GAS-PACK-002 on this file.
 *
 * Slot waste analysis (state variables — 5 slots, optimal is 3)
 * ---------------------------------------------------------------
 *   slot 0 → totalSupply (uint256)
 *   slot 1 → paused      (bool, 1 byte — 31 bytes wasted; could pack with fee+decimals)
 *   slot 2 → maxSupply   (uint256)
 *   slot 3 → decimals    (uint8, 1 byte — 31 bytes wasted)
 *   slot 4 → fee         (uint16, 2 bytes — 30 bytes wasted)
 *   Optimal: slot 0=totalSupply, slot 1=maxSupply, slot 2=paused+decimals+fee (4 bytes)
 *
 * Slot waste analysis (Position struct — 4 slots, optimal is 2)
 * --------------------------------------------------------------
 *   slot 0 → amount   (uint256)
 *   slot 1 → isActive (bool)    — 31 bytes wasted
 *   slot 2 → price    (uint256)
 *   slot 3 → flags    (uint8)   — 31 bytes wasted
 *   Optimal: amount, price (slot 0,1) then isActive+flags packed in slot 2
 */
contract PoorlyPackedStorage {
    // ── Contract-level state variables (GAS-PACK-002 expected) ──────────────
    uint256 public totalSupply;   // slot 0
    bool    public paused;        // slot 1 — isolated bool, wastes 31 bytes
    uint256 public maxSupply;     // slot 2 — breaks packing of small types
    uint8   public decimals;      // slot 3 — isolated, wastes 31 bytes
    uint16  public fee;           // slot 4 — isolated, wastes 30 bytes

    // ── Poorly-ordered struct (GAS-PACK-001 expected) ────────────────────────
    struct Position {
        uint256 amount;    // slot 0
        bool    isActive;  // slot 1 (1 byte, wastes 31 bytes)
        uint256 price;     // slot 2
        uint8   flags;     // slot 3 (1 byte, wastes 31 bytes)
    }

    // ── Another bad struct (GAS-PACK-001 expected) ───────────────────────────
    struct Order {
        address maker;    // slot 0 (20 bytes)
        uint256 quantity; // slot 1 (breaks packing — could share slot 0 remainder)
        uint64  expiry;   // slot 2 (8 bytes — isolated)
        bool    filled;   // slot 3 (1 byte — isolated)
    }

    mapping(address => Position) public positions;
    mapping(address => Order)    public orders;

    constructor() {}

    function openPosition(uint256 amount, uint256 price) external {
        positions[msg.sender] = Position({ amount: amount, isActive: true, price: price, flags: 0 });
    }

    function placeOrder(uint256 quantity, uint64 expiry) external {
        orders[msg.sender] = Order({ maker: msg.sender, quantity: quantity, expiry: expiry, filled: false });
    }
}
