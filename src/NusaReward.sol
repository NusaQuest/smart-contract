// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC1155URIStorage} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract NusaReward is ERC1155URIStorage, ERC1155Holder, Ownable {
    //
    uint256 private constant NFT_PER_SWAP = 1;
    mapping(uint256 => uint256) private prices;

    event Minted(uint256[] ids, uint256[] values);
    event Transfered(address user, uint256 nftId);

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

    constructor(address _owner) Ownable(_owner) ERC1155("") {
        _setBaseURI("https://gateway.pinata.cloud/ipfs/");
    }

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

        emit Minted(_ids, _values);
    }

    function transfer(uint256 _nftId, address _recipient) external onlyOwner {
        _safeTransferFrom(address(this), _recipient, _nftId, NFT_PER_SWAP, "");

        emit Transfered(_recipient, _nftId);
    }

    function tokenURI(uint256 _id) external view returns (string memory) {
        return uri(_id);
    }

    function balance(address _user, uint256 _id) external view returns (uint256) {
        return balanceOf(_user, _id);
    }

    function nftPrice(uint256 _id) external view returns (uint256) {
        return prices[_id];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC1155Holder)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    //
}
