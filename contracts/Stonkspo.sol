// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

interface ERC20 {
    function transfer(address recipient, uint256 amount) public virtual override returns (bool);
    function burn(address account, uint256 amount) public returns (bool);
}

/**
 * @dev Stonk SPO staking contract
 *
 **/
contract StonkSPO {
    
     bool private _sync;
    
        mapping (address => uint256) public stakedBalances;
        address public stonkTokenAddress;

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
    
    function launchSPO(uint256 amount) external onlyStonk{
        require(amount > 0, "Stake amount must be positive value");
        require(stakedBalances[address] == 0, "Please withdraw your current stake before restaking");
        
        stakedBalances[address] = amount;
    }
    
    function getResultFromChainlink() internal {
        
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
    
    
    
    function enterNegotiation(address spo)  external synchronized {
        uint256 negotiationAmount = getNegotiationAmount(spo);
        
        uint256 result =  getResultFromChainlink();
        
        uint256 taxAmount = negotiationAmount / 10; //10% to be burned
        
        require(ERC20(stonkTokenAddress).burn(address(this), taxAmount), "Burn failed");//burn  10%
        
        uint256 amountWon = negotiationAmount - taxAmount;
        
        bool winner;
        
        
        if(result > 5){ //player wins
            ERC20(stonkTokenAddress).transfer(msg.sender, amountWon);
            winner = true;
        } else { //other spo wins
            ERC20(stonkTokenAddress).transfer(spo, amountWon);
            winner = false;
        }
        
        
        emit merger(msg.sender, spo, winner, amountWon);
    }
    
        
    function withdrawStake() external synchronized {
        ERC20(stonkTokenAddress).transfer(msg.sender, stakedBalances[msg.sender]);
        stakedBalances[msg.sender] = 0;
    }
    
}