// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * SecureVault.sol
 *
 * ✅ Secure version of VulnerableVault.
 * Demonstrates fixes for all SWC issues found by ChainProof.
 *
 * Fixes applied:
 *   ✅ SWC-107: Uses ReentrancyGuard + Checks-Effects-Interactions pattern
 *   ✅ SWC-115: Uses msg.sender (via Ownable) instead of tx.origin
 *   ✅ SWC-101: Solidity ^0.8.20 — overflow reverts natively
 *   ✅ SWC-104: All return values checked with require()
 */
contract SecureVault is ReentrancyGuard, Ownable {
    mapping(address => uint256) public balances;
    uint256 public totalDeposited;
    uint256 public rewardPool;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardSent(address indexed recipient, uint256 amount);

    constructor() Ownable(msg.sender) {}

    function deposit() external payable {
        // ✅ Solidity 0.8 — overflow reverts automatically
        balances[msg.sender] += msg.value;
        totalDeposited += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // ✅ nonReentrant guard from OpenZeppelin
    // ✅ Checks-Effects-Interactions: state updated BEFORE external call
    function withdraw(uint256 amount) external nonReentrant {
        // Check
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // Effect — update state BEFORE the external call
        balances[msg.sender] -= amount;
        totalDeposited -= amount;

        // Interaction — external call LAST
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function addReward(uint256 amount) external onlyOwner {
        rewardPool += amount;
    }

    // ✅ Return value explicitly checked
    function sendReward(address recipient) external onlyOwner nonReentrant {
        uint256 amount = rewardPool;
        rewardPool = 0; // Effects first

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Reward transfer failed");

        emit RewardSent(recipient, amount);
    }

    // ✅ Uses Ownable's transferOwnership — msg.sender based, not tx.origin
    // Inherited from OpenZeppelin Ownable — no need to reimplement.

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
