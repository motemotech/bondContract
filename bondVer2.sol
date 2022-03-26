//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract bondVer2 is Ownable {

    event newVault(uint Id, address token, address holder, uint256 lockedAmount,  uint256 saleDuration, uint256 bondingDuration);

    struct vault {
        address token;
        address holder;
        uint256 lockedAmount;
        uint256 saleDuration;
        uint256 bondingDuration;
    }
    struct bVault {
        address bToken;
        uint256 remainAmount;
        uint256 createdTime;
    }
    
    vault[] public vaults;
    bVault[] public bVaults;

    mapping(uint256 => uint256) public vaultId_bVaultId;
    mapping(address => uint256) public totalTokenLocked;
    mapping(address => uint256) public total_bTokenLocked;

    function createVault(address _token, uint256 _lockedAmount, uint256 _saleDuration, uint256 _bondingDuration) public {
        require(_lockedAmount > 0, "Amount must be more than 0");
        IERC20(_token).transferFrom(msg.sender, address(this), _lockedAmount);
        vaults.push(vault(_token, msg.sender, _lockedAmount, _saleDuration, _bondingDuration));
        uint id = vaults.length - 1;
        emit newVault(id, _token, msg.sender ,_lockedAmount, _saleDuration, _bondingDuration);
    }

    function set_bToken(uint _vaultId, uint _bVaultId, address _bToken) public onlyOwner {
        require(IERC20(_bToken).balanceOf(address(this)) >= vaults[_vaultId].lockedAmount, "Not enough bToken");
        bVaults.push(bVault(_bToken, vaults[_vaultId].lockedAmount, block.timestamp));
        vaultId_bVaultId[_vaultId] = _bVaultId;
    } 

    function set_bTokenPrice(address _bToken, uint256 _price) public {

    }

}