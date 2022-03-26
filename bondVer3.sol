//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract bondVer3 is Ownable {

    event newVault(uint Id, address token, address holder, uint256 totalLockedAmount,  uint256 createdTime, uint256 saleDuration, uint256 bondingDuration);

    struct vault {
        address token;
        address holder;
        uint256 totalLockedAmount;
        uint256 balance;
        uint256 createdTime;
        uint256 saleDuration;
        uint256 bondingDuration;
    }
    
    vault[] public vaults;

    mapping(uint256 => mapping(address => uint256)) public vaultId_User_bBalance;

    function createVault(address _token, uint256 _amount, uint256 _saleDuration, uint256 _bondingDuration) public {
        require(_amount > 0, "Amount must be more than 0");
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        vaults.push(vault(_token, msg.sender, _amount, _amount, block.timestamp, _saleDuration, _bondingDuration));
        uint id = vaults.length - 1;
        emit newVault(id, _token, msg.sender ,_amount, block.timestamp, _saleDuration, _bondingDuration);
    }

    function buy_bToken() public {

    }

    function set_bTokenPrice()

}