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
     * Network: Ropsten
     * Chainlink VRF Coordinator address: 0x2e184F4120eFc6BF4943E3822FA0e5c3829e2fbD
     * LINK token address:                0x20fE562d797A42Dcb3399062AE9546cd06f63280
     * Key Hash: 0x757844cd6652a5805e9adb8203134e10a26ef59f62b864ed6a8c054733a1dcb0
     */
    constructor() 
        VRFConsumerBase(
            0x2e184F4120eFc6BF4943E3822FA0e5c3829e2fbD, // VRF Coordinator
            0x20fE562d797A42Dcb3399062AE9546cd06f63280  // LINK Token
        ) public
    {
        keyHash = 0x757844cd6652a5805e9adb8203134e10a26ef59f62b864ed6a8c054733a1dcb0;
        fee = 0.1 * 10 ** 18; // 0.1 LINK
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
            winner = true;
        } else { //other spo wins
            ERC20(stonkTokenAddress).transfer(thisNegotiation.other, thisNegotiation.amount);
            winner = false;
        }
        
        emit merger(thisNegotiation.player, thisNegotiation.other, winner, thisNegotiation.amount);
    }
    
    
    function launchSPO(uint256 amount) external onlyStonk{
        require(amount > 0, "Stake amount must be positive value");
        require(stakedBalances[msg.sender] == 0, "Please withdraw your current stake before restaking");
        
        stakedBalances[msg.sender] = amount;
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
        uint256 negotiationAmount = getNegotiationAmount(spo);
        
        bytes32 requestId  =  getRandomNumber(randomSeed);
        
        
        uint256 taxAmount = negotiationAmount / 10; //10% to be burned
        
        require(ERC20(stonkTokenAddress).burn(address(this), taxAmount), "Burn failed");//burn  10%
        
        uint256 amountWon = negotiationAmount - taxAmount;
        
        chainlinkRequests[requestId] = Negotiation(amountWon, msg.sender, spo);
        
    }
    
        
    function withdrawStake() external synchronized {
        ERC20(stonkTokenAddress).transfer(msg.sender, stakedBalances[msg.sender]);
        stakedBalances[msg.sender] = 0;
    }
    
}