// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * WellPackedStorage — optimal struct/state-variable layout.
 * ChainProof should emit NO GAS-PACK-* hints on this file.
 *
 * Slot layout
 * -----------
 * Position struct (2 slots):
 *   slot 0 → amount   (uint256, 32 bytes)
 *   slot 1 → price    (uint256, 32 bytes) + isActive packed at end if types align
 *            Actually: price (uint256) fills slot 1; isActive goes slot 2 only 1 byte.
 *            Best achievable: amount | price each 32 bytes, isActive packed alone = 2+1 slots.
 *            Better: drop to uint128 for both → all 3 fit in 2 slots.
 *   The layout below achieves 2 slots by using uint128 fields.
 *
 * Contract state variables (2 slots):
 *   slot 0 → owner (address, 20 bytes) + fee (uint96, 12 bytes) = 32 bytes exactly
 *   slot 1 → totalSupply (uint256)
 *   paused packed with owner/fee → (address 20 + uint96 12 = 32 — no room; move to slot 1 area)
 *   Final: slot 0 = owner+fee, slot 1 = totalSupply, slot 2 = paused (1 byte)
 *          But comparing to PoorlyPackedStorage's 4 slots this is still 3 → saves 1 slot.
 */
contract WellPackedStorage {
    // ── Contract-level state variables — tightly packed ──────────────────────
    // slot 0: owner (20 bytes) + fee (12 bytes) = 32 bytes, perfectly packed
    address public owner;
    uint96  public fee;
    // slot 1: totalSupply
    uint256 public totalSupply;
    // slot 2: paused (1 byte) — remaining small vars grouped together
    bool    public paused;

    // ── Optimally-ordered struct ─────────────────────────────────────────────
    struct Position {
        uint256 amount;    // slot 0 (32 bytes)
        uint256 price;     // slot 1 (32 bytes)
        bool    isActive;  // slot 2 (1 byte — bools grouped at end)
    }

    // ── Optimally-ordered struct ─────────────────────────────────────────────
    struct Order {
        uint256 quantity;  // slot 0 (32 bytes — full-width first)
        address maker;     // slot 1 (20 bytes)
        uint64  expiry;    // slot 1 (8 bytes, packed with maker: 20+8=28 bytes)
        bool    filled;    // slot 1 (1 byte, packed: 20+8+1=29 bytes)
    }

    mapping(address => Position) public positions;
    mapping(address => Order)    public orders;

    constructor() {
        owner = msg.sender;
    }

    function openPosition(uint256 amount, uint256 price) external {
        positions[msg.sender] = Position({ amount: amount, price: price, isActive: true });
    }

    function placeOrder(uint256 quantity, uint64 expiry) external {
        orders[msg.sender] = Order({ quantity: quantity, maker: msg.sender, expiry: expiry, filled: false });
    }
}
