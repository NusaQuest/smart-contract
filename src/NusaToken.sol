// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NusaToken
 * @dev ERC20 token with vote delegation (ERC20Votes), permit functionality (EIP-2612), and controlled minting by a governance contract (NusaQuest).
 *
 * The token supports on-chain governance via delegated voting power. Only the designated NusaQuest contract
 * can mint and burn tokens to enforce governance control.
 */
contract NusaToken is ERC20, ERC20Votes, ERC20Permit {
    /// @notice Address of the authorized governance contract (NusaQuest)
    address private s_nusaQuest;

    /**
     * @dev Restricts a function to be callable only once — used to set the governance contract.
     */
    modifier onlyOnce() {
        require(s_nusaQuest == address(0), "Governance already set.");
        _;
    }

    /**
     * @dev Restricts access to functions to the NusaQuest contract only.
     */
    modifier onlyNusaQuest() {
        require(
            msg.sender == s_nusaQuest,
            "You are not authorized to perform this action."
        );
        _;
    }

    /**
     * @notice Initializes the token with name and symbol.
     * Also initializes ERC20Permit with the same name for EIP-2612 support.
     */
    constructor() ERC20("NusaToken", "NUSA") ERC20Permit("NusaToken") {}

    /**
     * @notice Sets the address of the NusaQuest contract. Can only be set once.
     * @param _nusaQuest Address of the deployed NusaQuest contract.
     */
    function setNusaQuest(address _nusaQuest) external onlyOnce {
        s_nusaQuest = _nusaQuest;
    }

    /**
     * @notice Mints tokens to a specified address.
     * @dev Only callable by the NusaQuest contract.
     * @param _to Address to receive the tokens.
     * @param _amount Amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external onlyNusaQuest {
        _mint(_to, _amount);
    }

    /**
     * @notice Burns tokens from a specified address.
     * @dev Only callable by the NusaQuest contract.
     * @param _to Address whose tokens will be burned.
     * @param _amount Amount of tokens to burn.
     */
    function burn(address _to, uint256 _amount) external onlyNusaQuest {
        _burn(_to, _amount);
    }

    /**
     * @notice Returns the token balance of a given address.
     * @param _user Address to check.
     * @return Balance of the user.
     */
    function balance(address _user) external view returns (uint256) {
        return balanceOf(_user);
    }

    /**
     * @dev Handles token transfers and updates vote checkpoints accordingly.
     * Required override for ERC20Votes to track voting power.
     */
    function _update(
        address _from,
        address _to,
        uint256 _amount
    ) internal override(ERC20, ERC20Votes) {
        super._update(_from, _to, _amount);
    }

    /**
     * @dev Returns the current clock value using timestamp (used by ERC6372 for time-based governance).
     */
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    /**
     * @dev Describes the mode of the clock — "timestamp" mode (required by ERC6372).
     */
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    /**
     * @dev Returns the current nonce for the owner (used for permit signatures).
     * Resolves conflict between ERC20Permit and Nonces.
     */
    function nonces(
        address _owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(_owner);
    }
}
