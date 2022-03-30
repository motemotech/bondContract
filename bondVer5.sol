//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract playpalBond is Ownable {

    struct vault {
        address token;
        uint startPrice; // <= able to change for future
        uint minimumPrice;
        uint totalAmount;
        uint remainAmount;
        uint totalEthAmount;
        uint createdTime;
        uint stakingDuration;
        uint saleDuration;
        uint bondingDuration;
    }

    struct bond {
        uint vaultId;
        address holder;
        uint createdTime;
        uint amount;
    }

    struct stakingInfo{
        uint amount;
        bool isRemainToken;
        bool isEth;
    }

    uint vaultId;
    uint bondId;

    mapping(uint => vault) public vaults;
    mapping(uint => bond) public bonds;
    mapping(uint => mapping(address => stakingInfo)) public vaultStakerAmount;

    constructor() {
        vaultId = 0;
        bondId = 0;
    }

    // Call when you want to create vault
    function createVault(address _token, uint _bondPrice, uint _minimumPrice, uint _stakingDuration, uint _saleDuration, uint _bondingDuration) public {
        vaults[vaultId] = vault(_token, _bondPrice, _minimumPrice, 0, 0, 0, block.timestamp, _stakingDuration, _saleDuration, _bondingDuration);
        vaultId += 1;
    }

    // Call when you want to stake your token
    function staking(uint _vaultId, address _token, uint _amount) public {
        require(block.timestamp <= vaults[_vaultId].createdTime + vaults[_vaultId].stakingDuration, "Out of time");
        require(_token == vaults[_vaultId].token, "This is not right token address");
        require(_amount > 0, "Please stake more than 0 token");

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        vaults[_vaultId].totalAmount += _amount;
        vaults[_vaultId].remainAmount += _amount;
        if (isStaker(_vaultId)) {
            vaultStakerAmount[_vaultId][msg.sender].amount += _amount;
        }else {
            vaultStakerAmount[_vaultId][msg.sender] = stakingInfo(_amount, true, true);
        }
    }

    // Check if they are staker
    function isStaker(uint _vaultId) internal view returns(bool) {
        if(vaultStakerAmount[_vaultId][msg.sender].amount > 0) {
            return true;
        } else {
            return false;
        }
    }

    // Call when you want to buy bond 
    function buyBond(uint _vaultId) public payable {
        require(
            block.timestamp > vaults[_vaultId].createdTime + vaults[_vaultId].stakingDuration
            && 
            block.timestamp <= vaults[_vaultId].createdTime + vaults[_vaultId].stakingDuration + vaults[_vaultId].saleDuration,
            "Out of time"
        );
        require(msg.value > 0, "Please send more than 0 ether");
        
        uint amount = msg.value / clearingPrice(_vaultId);
        vaults[_vaultId].totalEthAmount += msg.value;
        vaults[_vaultId].remainAmount -= amount;
        bonds[bondId] = bond(_vaultId, msg.sender, block.timestamp, amount);
        bondId += 1;
    }

    // Call when you want to withdraw your staked token
    function withdrawToken(uint _vaultId) public {
        require(block.timestamp > vaults[_vaultId].createdTime + vaults[_vaultId].stakingDuration + vaults[_vaultId].saleDuration, "Sale is not finished yet");
        require(vaultStakerAmount[_vaultId][msg.sender].amount > 0, "You are not staker");
        require(vaultStakerAmount[_vaultId][msg.sender].isRemainToken, "You have already claimed");

        uint amount = vaults[_vaultId].remainAmount * vaultStakerAmount[_vaultId][msg.sender].amount / vaults[_vaultId].totalEthAmount;
        vaults[_vaultId].remainAmount -= amount;
        vaultStakerAmount[_vaultId][msg.sender].isRemainToken = false;
        IERC20(vaults[_vaultId].token).transfer(msg.sender, amount); 
    }

    // Call when you want to claim your token
    function claim(uint _bondId) public {
        require(block.timestamp > bonds[_bondId].createdTime + vaults[bonds[_bondId].vaultId].bondingDuration, "Your token is still locked");
        require(bonds[_bondId].holder == msg.sender, "You are not holder");

        uint amount = bonds[_bondId].amount;
        bonds[_bondId].amount = 0;
        IERC20(vaults[bonds[_bondId].vaultId].token).transfer(msg.sender, amount);
    }

    // Call when you want to claim your eth profit
    function claimEth(uint _vaultId) public {
        require(block.timestamp > vaults[_vaultId].createdTime + vaults[_vaultId].stakingDuration + vaults[_vaultId].saleDuration, "Sale is not finished yet");
        require(vaultStakerAmount[_vaultId][msg.sender].amount > 0, "You are not staker");
        require(vaultStakerAmount[_vaultId][msg.sender].isEth, "You have already claimed");

        uint amount = vaults[_vaultId].totalEthAmount * vaultStakerAmount[_vaultId][msg.sender].amount / vaults[_vaultId].totalEthAmount;
        vaultStakerAmount[_vaultId][msg.sender].isEth = false;
        payable(msg.sender).transfer(amount);
    }




    // decide the price of bToken

    function _currentPrice(uint _vaultId) private view returns (uint) {
        uint priceRange = vaults[_vaultId].startPrice - vaults[_vaultId].minimumPrice;
        uint elapsedSalesTime = block.timestamp - (vaults[_vaultId].createdTime + vaults[_vaultId].stakingDuration);
        uint remainingSalesTime = vaults[_vaultId].saleDuration - elapsedSalesTime;
        uint priceDiff = elapsedSalesTime*priceRange/remainingSalesTime;
               
        return vaults[_vaultId].startPrice - priceDiff; 
    }

    function tokenPrice(uint _vaultId) public view returns (uint) {
        return vaults[_vaultId].totalEthAmount/(vaults[_vaultId].totalAmount-vaults[_vaultId].remainAmount);
    }


    // return the price culcurated by _currentPrice function 
    function priceFunction(uint _vaultId) public view returns (uint) {
        if (block.timestamp <= vaults[_vaultId].createdTime + vaults[_vaultId].stakingDuration) {
            return vaults[_vaultId].startPrice;
        }
        if (block.timestamp >= vaults[_vaultId].createdTime + vaults[_vaultId].stakingDuration + vaults[_vaultId].saleDuration) {
            return vaults[_vaultId].minimumPrice;
        }

        return _currentPrice(_vaultId);
    }

    // return the Dutch auction clearing price
    function clearingPrice(uint _vaultId) public view returns (uint) {

        uint priceA = tokenPrice(_vaultId);
        uint priceB = priceFunction(_vaultId);
        return priceA > priceB  ? priceA : priceB ;
    }

}