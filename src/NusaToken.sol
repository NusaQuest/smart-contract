// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Errors} from "./lib/Errors.l.sol";
import {Events} from "./lib/Events.l.sol";
import {NusaQuest} from "./NusaQuest.sol";

/**
 * @title NusaToken
 * @dev ERC20 token with vote delegation (ERC20Votes), permit functionality (EIP-2612), and controlled minting by a governance contract (NusaQuest).
 *
 * The token supports on-chain governance via delegated voting power. Only the designated NusaQuest contract
 * can mint and burn tokens to enforce governance control.
 */
contract NusaToken is ERC20, ERC20Votes, ERC20Permit, ReentrancyGuard {
    /// @notice Payable address of the authorized governance contract (NusaQuest)
    address payable private s_nusaQuest;

    /// @notice Initial reward given to a new user upon delegation
    uint256 private constant NEW_USER_REWARD = 10;

    /// @dev Tracks users who have already delegated
    mapping(address => bool) private s_alreadyDelegate;

    /**
     * @dev Restricts a function to be callable only once — used to set the governance contract.
     */
    modifier onlyOnce() {
        _checkOnlyOnce();
        _;
    }

    /**
     * @dev Restricts a user from calling delegate() more than once.
     * Used to ensure that delegation and reward minting only happen on the first delegation.
     */
    modifier onlyNewDelegator() {
        _checkOnlyNewDelegator();
        _;
    }

    /**
     * @dev Restricts access to functions to the NusaQuest contract only.
     */
    modifier onlyNusaQuest() {
        _checkOnlyNusaQuest();
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
        s_nusaQuest = payable(_nusaQuest);
    }

    /**
     * @notice Mints tokens to a specified address.
     * @param _to Address to receive the tokens.
     * @param _amount Amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) public {
        _mint(_to, (_amount * (10 ** decimals())));
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
     * @dev Internal hook to update balances and delegate checkpoints.
     * Overrides required for ERC20Votes compatibility.
     * @param _from Sender address
     * @param _to Recipient address
     * @param _amount Token amount transferred
     */
    function _update(
        address _from,
        address _to,
        uint256 _amount
    ) internal override(ERC20, ERC20Votes) {
        super._update(_from, _to, _amount);
    }

    /**
     * @notice Delegates voting power to the sender's own address.
     * @dev Reverts if the user has already delegated (via `onlyNewDelegator`).
     * Also registers user identity and mints initial reward.
     * @param _hash Hash used to register user identity.
     */
    function delegate(
        string memory _hash
    ) external onlyNewDelegator nonReentrant {
        super.delegate(msg.sender);
        s_alreadyDelegate[msg.sender] = true;
        NusaQuest(s_nusaQuest).registerIdentity(msg.sender, _hash);
        mint(msg.sender, NEW_USER_REWARD);

        emit Events.Delegated(msg.sender);
    }

    /// @dev Checks that the NusaQuest address has not been set yet.
    /// @dev Reverts with `GovernanceAlreadySet` if the address has already been initialized.
    /// @notice Used to ensure the NusaQuest contract address can only be set once.
    function _checkOnlyOnce() private view {
        require(
            s_nusaQuest == address(0),
            Errors.GovernanceAlreadySet(s_nusaQuest)
        );
    }

    /// @dev Checks that the caller has not already delegated to someone else.
    /// @dev Reverts with `AlreadyDelegated` if the caller has already assigned a delegate.
    /// @notice Used to prevent double delegation by the same user.
    function _checkOnlyNewDelegator() private view {
        require(
            !s_alreadyDelegate[msg.sender],
            Errors.AlreadyDelegated(msg.sender)
        );
    }

    /// @dev Ensures that only the NusaQuest contract can call the function.
    /// @dev Reverts with `UnexpectedCaller` if called by an unauthorized address.
    /// @notice Used to restrict access to internal functions to NusaQuest only.
    function _checkOnlyNusaQuest() private view {
        require(msg.sender == s_nusaQuest, Errors.UnexpectedCaller());
    }

    /**
     * @notice Returns the current nonce for a user (used in permit signatures).
     * @dev Required override due to conflict between ERC20Permit and Nonces.
     * @param _owner Address of the token holder
     * @return Current nonce value
     */
    function nonces(
        address _owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(_owner);
    }
}
