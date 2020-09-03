// SPDX-License-Identifier: MIT

pragma solidity 0.6.6;

import "https://raw.githubusercontent.com/smartcontractkit/chainlink/master/evm-contracts/src/v0.6/VRFConsumerBase.sol";

interface ERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function burn(address account, uint256 amount) external returns (bool);
}

/**
 * @dev Stonk SPO staking contract
 *
 **/
contract StonkSPO is VRFConsumerBase {
    
    bool private _sync;
    
    mapping (address => uint256) public stakedBalances;
    
    mapping (bytes32 => Negotiation) internal chainlinkRequests;
    
    mapping (address => bool) public activeStakers;
    address[] public stakerAddresses;
    
    address public stonkTokenAddress;
        
    bytes32 internal keyHash;
    uint256 internal fee;
    
    uint256 public randomResult;
    
    

    struct Negotiation{
        uint256 amount;
        address player;
        address other;
    }

    event merger(address spoA, address spoB, bool winner, uint256 amount);
    event spoCreated(address player, uint256 amonut);
    event withdraw(address player, uint256 amount);
    

    //protects against potential reentrancy
    modifier synchronized {
        require(!_sync, "Sync lock");
        _sync = true;
        _;
        _sync = false;
    }
    
    modifier onlyStonk {
        require(msg.sender == stonkTokenAddress);
        _;
    }
    
     /**
     * Constructor inherits VRFConsumerBase
     * 
     * Network: Kovan
     * Chainlink VRF Coordinator address: 0xf490AC64087d59381faF8Bf49Da299C073aAC152
     * LINK token address:                0xa36085F69e2889c224210F603D836748e7dC0088
     * Key Hash: 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4
     */
    constructor() 
        VRFConsumerBase(
            0xf490AC64087d59381faF8Bf49Da299C073aAC152, // VRF Coordinator
            0xa36085F69e2889c224210F603D836748e7dC0088  // LINK Token
        ) public
    {
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10 ** 18; // 0.1 LINK
        stonkTokenAddress = 0xd40f7bfd97CDF46C1ABdC1146dbFc46eae2091b7;
    }
    
    /** 
     * Requests randomness from a user-provided seed
     */
    function getRandomNumber(uint256 userProvidedSeed) public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee, userProvidedSeed);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
        
        Negotiation memory thisNegotiation = chainlinkRequests[requestId];
         bool winner;
        
        
        if(randomness > 5){ //player wins
            ERC20(stonkTokenAddress).transfer(thisNegotiation.player, thisNegotiation.amount);
            stakedBalances[thisNegotiation.other] = 0;
            activeStakers[thisNegotiation.other] = false;
            winner = true;
        } else { //other spo wins
            ERC20(stonkTokenAddress).transfer(thisNegotiation.other, thisNegotiation.amount);
            stakedBalances[thisNegotiation.player] = 0;
            activeStakers[thisNegotiation.player] = false;
            winner = false;
        }
        
        emit merger(thisNegotiation.player, thisNegotiation.other, winner, thisNegotiation.amount);
    }
    
    
    function launchSPO(uint256 amount, address player) external onlyStonk returns(bool){
        require(amount > 1 * (10 * 10), "Stake amount is too low");
        require(stakedBalances[player] == 0, "Please withdraw your current stake before restaking");
        
        stakedBalances[player] = amount;
        stakerAddresses.push(player);
        activeStakers[player] = true;
        
        emit spoCreated(player, amount);
        return true;
    }
    
    
    function getNegotiationAmount(address spo)  internal view returns(uint256){
        uint256 senderBalance = stakedBalances[msg.sender];
        uint256 otherBalance = stakedBalances[spo];
        if(senderBalance > otherBalance){
            return otherBalance;
        }
        else {
            return senderBalance;
        }
    }
    
    function enterNegotiation(address spo, uint256 randomSeed)  external synchronized {
        require(spo != msg.sender, "Can't negotiate with yourself");
        require(stakedBalances[spo] != 0 && stakedBalances[msg.sender] != 0, "Invalid SPO address");
        uint256 negotiationAmount = getNegotiationAmount(spo);
        
        bytes32 requestId  =  getRandomNumber(randomSeed);
        uint256 taxAmount = negotiationAmount / 10; //10% to be burned
        require(ERC20(stonkTokenAddress).burn(address(this), taxAmount), "Burn failed");//burn  10%
        
        uint256 amountWon = negotiationAmount - taxAmount;
        chainlinkRequests[requestId] = Negotiation(amountWon, msg.sender, spo);
    }
    
    function getStakerAddresses() external view returns(address[] memory){
        return stakerAddresses;
    }
    
    function withdrawStake() external synchronized {
        uint256 withdrawAmount = stakedBalances[msg.sender];
        require(withdrawAmount != 0, "No tokens currently staked");
        ERC20(stonkTokenAddress).transfer(msg.sender, withdrawAmount);
        stakedBalances[msg.sender] = 0;
        activeStakers[msg.sender] = false;
        
        emit withdraw(msg.sender, withdrawAmount);
    }
    
}