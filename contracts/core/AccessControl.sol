// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ParadiseAccessControl
 * @notice Role-based access control for Paradise Tycoon contracts
 * @dev Extends OpenZeppelin AccessControl with game-specific roles
 */
contract ParadiseAccessControl is AccessControl {
    /// @notice Admin role - full control over all contracts
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Game contract role - can mint/burn items and execute game logic
    bytes32 public constant GAME_CONTRACT_ROLE = keccak256("GAME_CONTRACT_ROLE");

    /// @notice Operator role - can update game parameters
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /**
     * @notice Constructor
     * @dev Grants ADMIN_ROLE to the deployer
     */
    constructor() {
        _grantRole(ADMIN_ROLE, msg.sender);
        // Admin is also an operator by default
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    /**
     * @notice Check if an address has admin role
     * @param account The address to check
     * @return True if the address has admin role
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /**
     * @notice Check if an address has game contract role
     * @param account The address to check
     * @return True if the address has game contract role
     */
    function isGameContract(address account) external view returns (bool) {
        return hasRole(GAME_CONTRACT_ROLE, account);
    }

    /**
     * @notice Check if an address has operator role
     * @param account The address to check
     * @return True if the address has operator role
     */
    function isOperator(address account) external view returns (bool) {
        return hasRole(OPERATOR_ROLE, account);
    }
}
