//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract playpalBond is Ownable {
    
    using SafeMath for uint;

    struct vault {
        address token;
        uint ceilingPrice;
        uint bottomPrice;
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
        uint createdTime;
        uint amount;
    }

    struct stakingInfo{
        uint amount;
        bool isRemainToken;
        bool isEth;
    }

    uint vaultId;

    mapping(uint => vault) public vaults;
    mapping(address => mapping(uint => bond)) public bonds;
    mapping(uint => mapping(address => stakingInfo)) public vaultStakerAmount;

    event _createVault(uint vaultId, address token, uint ceilingPrice, uint bottomPrice, uint createdTime, uint stakingDuration, uint saleDuration, uint bondingDuration);
    event _staking(uint vaultId, address token, uint amount);
    event _buyBond(uint vaultId, uint bondPrice, uint paidAmount, uint tokenAmount);
    event _withdrawToken(uint vaultId, address token, uint amount);
    event _claimEth(uint vaultId, uint ethAmount);
    event _claim(uint vaultId, address token, uint amount);

    constructor() {
        vaultId = 0;
    }

    // Call when you want to create vault
    function createVault(address _token, uint _ceilingPrice, uint _bottomPrice, uint _stakingDuration, uint _saleDuration, uint _bondingDuration) external {
        vaults[vaultId] = vault(_token, _ceilingPrice, _bottomPrice, 0, 0, 0, block.timestamp, _stakingDuration, _saleDuration, _bondingDuration);
        emit _createVault(vaultId, _token, _ceilingPrice, _bottomPrice, block.timestamp, _stakingDuration, _saleDuration, _bondingDuration);
        vaultId.add(1);
    }

    // Call when you want to stake your token
    function staking(uint _vaultId, address _token, uint _amount) external {
        require(block.timestamp <= vaults[_vaultId].createdTime + vaults[_vaultId].stakingDuration, "Out of time");
        require(_token == vaults[_vaultId].token, "This is not right token address");
        require(_amount > 0, "Please stake more than 0 token");

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        vaults[_vaultId].totalAmount.add(_amount);
        vaults[_vaultId].remainAmount.add(_amount);
        if (isStaker(_vaultId)) {
            vaultStakerAmount[_vaultId][msg.sender].amount.add(_amount);
        }else {
            vaultStakerAmount[_vaultId][msg.sender] = stakingInfo(_amount, true, true);
        }
        emit _staking(_vaultId, _token, _amount);
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
    function buyBond(uint _vaultId) external payable {
        require(
            block.timestamp > vaults[_vaultId].createdTime + vaults[_vaultId].stakingDuration
            && 
            block.timestamp <= vaults[_vaultId].createdTime + vaults[_vaultId].stakingDuration + vaults[_vaultId].saleDuration,
            "Out of time"
        );
        require(msg.value > 0, "Please send more than 0 ether");
        uint price = priceFunction(_vaultId);
        require(msg.value < vaults[_vaultId].remainAmount.mul(price), "Too much amount");
        
        uint amount = msg.value.div(price);
        vaults[_vaultId].totalEthAmount.add(msg.value);
        vaults[_vaultId].remainAmount.sub(amount);
        bonds[msg.sender][_vaultId] = bond(_vaultId, block.timestamp, amount);
        emit _buyBond(_vaultId, price, msg.value, amount);
    }

    // Call when you want to withdraw your staked token
    function withdrawToken(uint _vaultId) external {
        require(block.timestamp > vaults[_vaultId].createdTime.add(vaults[_vaultId].stakingDuration).add(vaults[_vaultId].saleDuration), "Sale is not finished yet");
        require(vaultStakerAmount[_vaultId][msg.sender].amount > 0, "You are not staker");
        require(vaultStakerAmount[_vaultId][msg.sender].isRemainToken, "You have already claimed");

        uint amount = vaults[_vaultId].remainAmount.mul(vaultStakerAmount[_vaultId][msg.sender].amount).div(vaults[_vaultId].totalEthAmount);
        vaults[_vaultId].remainAmount.sub(amount);
        vaultStakerAmount[_vaultId][msg.sender].isRemainToken = false;
        IERC20(vaults[_vaultId].token).transfer(msg.sender, amount); 
        emit _withdrawToken(_vaultId, vaults[_vaultId].token, amount);
    }

    // Call when you want to claim your token
    function claim(uint _vaultId) external {
        require(block.timestamp > bonds[msg.sender][_vaultId].createdTime.add(vaults[bonds[msg.sender][_vaultId].vaultId].bondingDuration), "Your token is still locked");
        require(isBonded(_vaultId), "You are not holder");

        uint amount = bonds[msg.sender][_vaultId].amount;
        bonds[msg.sender][_vaultId].amount = 0;
        IERC20(vaults[bonds[msg.sender][_vaultId].vaultId].token).transfer(msg.sender, amount);
        emit _claim(_vaultId, vaults[_vaultId].token, amount);
    }

    function isBonded(uint _vaultId) internal view returns(bool){
        if(bonds[msg.sender][_vaultId].amount > 0){
            return true;
        }else {
            return false;
        }
    }

    // Call when you want to claim your eth profit
    function claimEth(uint _vaultId) external {
        require(block.timestamp > vaults[_vaultId].createdTime.add(vaults[_vaultId].stakingDuration).add(vaults[_vaultId].saleDuration), "Sale is not finished yet");
        require(vaultStakerAmount[_vaultId][msg.sender].amount > 0, "You are not staker");
        require(vaultStakerAmount[_vaultId][msg.sender].isEth, "You have already claimed");

        uint amount = vaults[_vaultId].totalEthAmount.mul(vaultStakerAmount[_vaultId][msg.sender].amount).div(vaults[_vaultId].totalEthAmount);
        vaultStakerAmount[_vaultId][msg.sender].isEth = false;
        payable(msg.sender).transfer(amount);
        emit _claimEth(_vaultId, amount);
    }

    // Calculate current price
    function _currentPrice(uint _ceilingPrice, uint _bottomPrice, uint _startTime, uint _saleDuration) internal view returns (uint) {
        require(_ceilingPrice > _bottomPrice, "ceiling price must be bigger than bottom price");

        uint priceRange = _ceilingPrice.sub(_bottomPrice);
        uint elapsedSalesTime = block.timestamp.sub(_startTime);
        uint priceDiff = elapsedSalesTime.mul(priceRange).div(_saleDuration);
               
        return _ceilingPrice.sub(priceDiff);
    }

    // Return bond price in dutch auction
    function priceFunction(uint _vaultId) public view returns (uint) {
        if (block.timestamp <= vaults[_vaultId].createdTime.add(vaults[_vaultId].stakingDuration)) {
            return vaults[_vaultId].ceilingPrice;
        }
        if (block.timestamp >= vaults[_vaultId].createdTime.add(vaults[_vaultId].stakingDuration).add(vaults[_vaultId].saleDuration)) {
            return vaults[_vaultId].bottomPrice;
        }

        return _currentPrice(
            vaults[_vaultId].ceilingPrice, 
            vaults[_vaultId].bottomPrice, 
            vaults[_vaultId].createdTime.add(vaults[_vaultId].stakingDuration),
            vaults[_vaultId].createdTime.add(vaults[_vaultId].stakingDuration+ vaults[_vaultId].saleDuration)
        );
    }

}