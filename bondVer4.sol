//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract  playpalBond {

    struct vault {
        address token;
        uint bTokenPrice;
        uint createdTime;
        uint stakingDuration;
        uint saleDuration;
        uint bondingDuration;
    }

    struct bTokenHolder {
        uint valutId;
        uint getTime;
        uint amount;
    }

    uint vaultId;
    uint holderId;

    mapping(uint => vault) public vaults;
    mapping(uint => uint) public totalAmount;
    mapping(uint => uint) public remainAmount;
    mapping(uint => uint) public totalEthAmount;
    mapping(uint => mapping(address => uint)) public vaultStakerAmount;
    mapping(address => mapping(uint => bTokenHolder)) public bTokenHolders;

    constructor() {
        vaultId = 0;
        holderId = 0;
    }

    function createVault(address _token, uint _bTokenPrice, uint _stakingDuration, uint _saleDuration, uint _bondingDuration) public {
        vaults[vaultId] = vault(_token, _bTokenPrice, block.timestamp, _stakingDuration, _saleDuration, _bondingDuration);
        remainAmount[vaultId] = 0;
        vaultId += 1;
    }

    function staking(uint _id, address _token, uint _amount) public {
        require(block.timestamp <= vaults[_id].createdTime + vaults[_id].stakingDuration, "Out of time");
        require(_token == vaults[_id].token, "This is not right token address");
        require(_amount > 0, "Please stake more than 0 token");

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        totalAmount[_id] += _amount;
        remainAmount[_id] += _amount;
        vaultStakerAmount[_id][msg.sender] += _amount;
    }

    function buy_bToken(uint _id) public payable {
        require(
            block.timestamp > vaults[_id].createdTime + vaults[_id].stakingDuration
            && 
            block.timestamp <= vaults[_id].createdTime + vaults[_id].stakingDuration + vaults[_id].saleDuration,
            "Out of time"
        );
        require(msg.value > 0, "Please send more than 0 ether");
        
        uint amount = msg.value / vaults[_id].bTokenPrice;
        totalEthAmount[_id] += msg.value;
        remainAmount[_id] -= amount;
        bTokenHolders[msg.sender][holderId] = bTokenHolder(_id, block.timestamp, amount);
        holderId += 1;
    }

    function claimEth(uint _id) public {
        require(block.timestamp > vaults[_id].createdTime + vaults[_id].stakingDuration);

        uint allowance = vaultStakerAmount[_id][msg.sender] / totalAmount[_id] * totalEthAmount[_id];
        totalAmount[_id] -= vaultStakerAmount[_id][msg.sender];
        vaultStakerAmount[_id][msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: allowance}("");
    }

    function claim(uint _id, uint _bTokenId) public {
        require(block.timestamp > bTokenHolders[msg.sender][_bTokenId].getTime, "Your token is still locked");

        uint amount = bTokenHolders[msg.sender][_bTokenId].amount;
        bTokenHolders[msg.sender][_bTokenId].amount = 0;
        IERC20(vaults[_id].token).transferFrom(address(this), msg.sender, amount);
    }

}