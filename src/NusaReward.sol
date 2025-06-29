// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC1155URIStorage} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NusaReward
 * @dev ERC1155 contract used to manage reward NFTs in a governance.
 * - Tokens are minted by the owner (e.g. a NusaQuest contract).
 * - Metadata is stored via per-token URI with a base IPFS gateway.
 * - Each NFT can have a specific price (e.g. for redemption).
 */
contract NusaReward is ERC1155URIStorage, ERC1155Holder, Ownable {
    /// @notice Fixed amount of NFT to be transferred per redemption.
    uint256 private constant NFT_PER_SWAP = 1;

    /// @dev Mapping of token ID to its price (in native currency or token units).
    mapping(uint256 => uint256) private prices;

    /**
     * @dev Ensures all batch input arrays (IDs, values, prices, URIs) are the same length.
     */
    modifier validBatchInputLengths(
        uint256 _idsLength,
        uint256 _valuesLength,
        uint256 _pricesLength,
        uint256 _urisLength
    ) {
        require(
            _idsLength == _valuesLength && _valuesLength == _pricesLength && _pricesLength == _urisLength,
            "Mismatch between IDs, values, prices, and URIs. Please ensure all inputs have the same length."
        );
        _;
    }

    /**
     * @notice Constructor that sets the owner and base IPFS URI.
     * @param _owner The address that will own the contract (typically the governance or DAO).
     */
    constructor(address _owner) Ownable(_owner) ERC1155("") {
        _setBaseURI("https://gateway.pinata.cloud/ipfs/");
    }

    /**
     * @notice Mints a batch of NFTs with specific IDs, values, prices, and metadata URIs.
     * @dev Only callable by the contract owner.
     * @param _ids Array of NFT token IDs.
     * @param _values Array of quantities to mint per token ID.
     * @param _prices Array of prices per NFT.
     * @param _uris Array of metadata URIs per token ID.
     */
    function mint(uint256[] memory _ids, uint256[] memory _values, uint256[] memory _prices, string[] memory _uris)
        external
        onlyOwner
        validBatchInputLengths(_ids.length, _values.length, _prices.length, _uris.length)
    {
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
    function transfer(uint256 _nftId, address _recipient) external onlyOwner {
        _safeTransferFrom(address(this), _recipient, _nftId, NFT_PER_SWAP, "");
    }

    /**
     * @notice Returns the URI of a given token ID.
     * @param _id Token ID to query.
     */
    function tokenURI(uint256 _id) external view returns (string memory) {
        return uri(_id);
    }

    /**
     * @notice Returns how many NFTs of a specific ID a user owns.
     * @param _user The address to query.
     * @param _id The NFT token ID to check.
     */
    function balance(address _user, uint256 _id) external view returns (uint256) {
        return balanceOf(_user, _id);
    }

    /**
     * @notice Returns the configured price of a given NFT.
     * @param _id Token ID to check.
     */
    function nftPrice(uint256 _id) external view returns (uint256) {
        return prices[_id];
    }

    /**
     * @dev Required override for interface support with multiple base contracts.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC1155Holder)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
