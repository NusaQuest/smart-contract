// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract NusaToken is ERC20, ERC20Votes, ERC20Permit {
    //
    address private s_nusaQuest;

    modifier onlyOnce() {
        require(s_nusaQuest == address(0), "Governance already set.");
        _;
    }

    modifier onlyNusaQuest() {
        require(
            msg.sender == s_nusaQuest,
            "You are not authorized to perform this action."
        );
        _;
    }

    constructor() ERC20("NusaToken", "NUSA") ERC20Permit("NusaToken") {}

    function setNusaQuest(address _nusaQuest) external onlyOnce {
        s_nusaQuest = _nusaQuest;
    }

    function mint(address _to, uint256 _amount) external onlyNusaQuest {
        _mint(_to, _amount);
    }

    function balance(address _user) external view returns (uint256) {
        return balanceOf(_user);
    }

    function burn(address _to, uint256 _amount) external onlyNusaQuest {
        _burn(_to, _amount);
    }

    function _update(
        address _from,
        address _to,
        uint256 _amount
    ) internal override(ERC20, ERC20Votes) {
        super._update(_from, _to, _amount);
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function nonces(
        address _owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(_owner);
    }
    //
}
