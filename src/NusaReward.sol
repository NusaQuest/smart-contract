// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC1155URIStorage} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {Errors} from "./lib/Errors.l.sol";

/**
 * @title NusaReward
 * @dev ERC1155 contract used to manage reward NFTs in a governance.
 * - Tokens are minted by the owner (a NusaQuest contract).
 * - Metadata is stored via per-token URI with a base IPFS gateway.
 * - Each NFT can have a specific price (e.g. for redemption).
 */
contract NusaReward is ERC1155URIStorage, ERC1155Holder {
    /// @notice Fixed amount of NFT to be transferred per redemption.
    uint256 private constant NFT_PER_SWAP = 1;

    /// @dev Mapping of token ID to its price (in native currency or token units).
    mapping(uint256 => uint256) private prices;

    /// @dev Address of the NusaQuest contract (used to validate caller).
    address private s_nusaQuest;

    /// @dev Address of the minter allowed to mint and transfer rewards.
    address private s_minter;

    /// @dev Modifier that ensures the caller is either the quest contract or the minter.
    modifier validateCaller() {
        _checkCaller();
        _;
    }

    /**
     * @notice Constructor that sets the owner and base IPFS URI.
     */
    constructor(address _nusaQuest, address _minter) ERC1155("") {
        _setBaseURI("https://gateway.pinata.cloud/ipfs/");
        s_nusaQuest = _nusaQuest;
        s_minter = _minter;
    }

    /**
     * @notice Mints a batch of NFTs with specific IDs, values, prices, and metadata URIs.
     * @dev Only callable by the contract owner.
     * @param _ids Array of NFT token IDs.
     * @param _values Array of quantities to mint per token ID.
     * @param _prices Array of prices per NFT.
     * @param _uris Array of metadata URIs per token ID.
     */
    function mint(
        uint256[] memory _ids,
        uint256[] memory _values,
        uint256[] memory _prices,
        string[] memory _uris
    ) external validateCaller {
        _mintBatch(address(this), _ids, _values, "");

        for (uint256 i = 0; i < _ids.length; i++) {
            prices[_ids[i]] = _prices[i];
            _setURI(_ids[i], _uris[i]);
        }
    }

    /**
     * @notice Transfers 1 unit of an NFT from the contract to a recipient.
     * @dev Useful for controlled distribution of rewards.
     * @param _nftId The token ID to transfer.
     * @param _recipient The address that will receive the NFT.
     */
    function transfer(
        uint256 _nftId,
        address _recipient
    ) external validateCaller {
        _safeTransferFrom(address(this), _recipient, _nftId, NFT_PER_SWAP, "");
    }

    /**
     * @notice Returns the configured price of a given NFT.
     * @param _id Token ID to check.
     */
    function nftPrice(uint256 _id) external view returns (uint256) {
        return prices[_id];
    }

    /// @dev Ensures the caller is either NusaQuest or the designated minter.
    /// @dev Reverts with `UnexpectedCaller` if not authorized.
    function _checkCaller() private view {
        require(
            s_nusaQuest == msg.sender || s_minter == msg.sender,
            Errors.UnexpectedCaller()
        );
    }

    /**
     * @dev Required override for interface support with multiple base contracts.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
