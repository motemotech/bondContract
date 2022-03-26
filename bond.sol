// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract bond is Ownable {

    struct bondInfo {
        address token;
        uint stakingStartTime;
        uint stakingDuration;
        uint saleDuration;
        uint bondingDuration;
    }

    uint mintbTokenDuration = 1 minutes;

    bondInfo[] public bondCollections;

    mapping(uint => address) public bond_bToken;
    mapping(uint => uint) public bond_eth_price;
    mapping(uint => uint) public bond_totalToken;
    mapping(uint => uint) public bond_totalTokenRemain;
    mapping(uint => uint) public bond_eth;
    mapping(address => mapping(address => uint)) public token_staker_amount;

    // Call when you want to open bond
    function openBond(address _token, uint _stakingDuration, uint _saleDuration, uint _bondingDuration) public {
        bondCollections.push(bondInfo(_token, block.timestamp, _stakingDuration, _saleDuration, _bondingDuration));
    }

    // Call when you want to stake your token
    function staking(uint _id, uint256 _amount, address _token) public {
        require(block.timestamp >= bondCollections[_id].stakingStartTime 
                && 
                block.timestamp <= bondCollections[_id].stakingStartTime + bondCollections[_id].stakingDuration, 
                "Out of staking time!");
        require(_amount > 0, "Amount must be more than 0");
        require(bondCollections[_id].token == _token, "This is not right token");

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        token_staker_amount[_token][msg.sender] = token_staker_amount[_token][msg.sender] + _amount;
        bond_totalToken[_id] = bond_totalToken[_id] + _amount;
        bond_totalTokenRemain[_id] = bond_totalTokenRemain[_id] + _amount;
    }

    // Call when you set minted bToken
    function setbToken(uint _id, address _bToken) public onlyOwner {
        bond_bToken[_id] = _bToken;
    }

    // Call when you buy bToken on our market
    function sale(uint _id) public payable {
        require(
            block.timestamp > bondCollections[_id].stakingStartTime + bondCollections[_id].stakingDuration 
            &&
            block.timestamp <= bondCollections[_id].stakingStartTime + bondCollections[_id].stakingDuration + bondCollections[_id].saleDuration,
            "Out of selling time"
            );
        require(bond_totalTokenRemain[_id] >= 0, "It is already sold out");
        require(msg.value > bond_eth_price[_id], "This is not enough amount");

        uint256 _amount = msg.value / bond_eth_price[_id];
        IERC20(bond_bToken[_id]).transferFrom(address(this), msg.sender, _amount);
        bond_totalTokenRemain[_id] = bond_totalTokenRemain[_id] - _amount;
        bond_eth[_id] = bond_eth[_id] + msg.value;

    }

    function setEthPrice(uint _id, uint _price) public onlyOwner {
        bond_eth_price[_id] = 1 ether * _price;
    }

    // For stakers
    // Call when they want to claim their eth reward
    function claimEth()

    // Call when you exchange bToken to Token
    function claim(uint _id) public {
        require(
            block.timestamp > bondCollections[_id].stakingStartTime + bondCollections[_id].stakingDuration + bondCollections[_id].saleDuration,
            "This token is still locked"
        );


    }

}