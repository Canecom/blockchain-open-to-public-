// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PaymentDistributor is Ownable{
    // balance related stuff
    struct Balance {
        address owner;
        bool isActive;
        uint balance;
    }  
    
    mapping(uint => Balance) balances;
    mapping(address => uint) stakeHolderIndexes;

    uint stakeHolderIndex = 1;
    uint public stakeHolderCount;
    uint public balance;        
    
    //voting related stuff
    struct Topic {
        address subject;
        bool admission;
        bool defaultOutcome;        
    }  

    struct Votes {
        uint forCount;
        uint againstCount;
    }

    bool public ongoingVote;
    Topic currentTopic;
    Votes votes;
    mapping(uint => mapping(address => bool)) voters;
    uint voteIndex;     

    fallback() external payable { 
        balance += msg.value;

        if (stakeHolderCount == 0)
            return;
        
        uint share = msg.value / stakeHolderCount;

        if (share == 0)
            return;

        for(uint i = 0; i < stakeHolderIndex; i++){
            if (balances[i].isActive) {
                balances[i].balance += share;                
            }
        }
    }

    function getBalance(address recepient) public view returns(uint){
        return balances[stakeHolderIndexes[recepient]].balance;
    }

    function withdraw(address payable recepient, uint amount) public {
        require(msg.sender == recepient, "Not allowed");
        require(balances[stakeHolderIndexes[recepient]].balance >= amount, "Not enough funds");

        balances[stakeHolderIndexes[recepient]].balance -= amount;
        balance -= amount;

        recepient.transfer(amount);
    }

    function startVote(address subject, bool admission, bool defaultOutcome) public onlyOwner{
        require(!ongoingVote, "Close the current vote first");
        
        if (admission)
        {
            require(stakeHolderIndexes[subject] == 0, "Subject is already a stakeholder");
        }
        else{
            require(stakeHolderIndexes[subject] != 0, "Subject is not a stakeholder");
        }      
         
        currentTopic = Topic(subject, admission, defaultOutcome);
        ongoingVote = true;
        votes = Votes(0, 0);
        voteIndex++;
    }

    function voteFor() public {
        require(stakeHolderIndexes[msg.sender] > 0, "You are not allowed to vote");
        require(ongoingVote, "There is no ongoing vote");
        require(!voters[voteIndex][msg.sender], "Cannot vote twice");        
        
        voters[voteIndex][msg.sender] = true;
        votes.forCount++;
    }

    function voteAgainst() public {
        require(stakeHolderIndexes[msg.sender] > 0, "You are not allowed to vote");
        require(ongoingVote, "There is no ongoing vote");
        require(!voters[voteIndex][msg.sender], "Cannot vote twice");

        voters[voteIndex][msg.sender] = true;
        votes.againstCount++;
    }

    function closeVote() public onlyOwner {
        require(ongoingVote, "There is no ongoing vote");

        if (votes.forCount > votes.againstCount || ((votes.forCount + votes.againstCount) == 0 && currentTopic.defaultOutcome)) {
            if (currentTopic.admission) {
                register(currentTopic.subject);
            }
            else{
                unRegister(currentTopic.subject);
            }
        }

        ongoingVote = false;
    }

    function getCurrentTopic() public view returns(Topic memory) {
        require(stakeHolderIndexes[msg.sender] > 0, "You are not allowed");
        require(ongoingVote, "There is no ongoing vote");

        return currentTopic;
    }

    function registerByOwner(address stakeHolder) public onlyOwner {
      require(stakeHolderCount < 2, "Use voting instead");

      register(stakeHolder);
    }

    function unRegisterByOwner(address stakeHolder) public onlyOwner {
        require(stakeHolderCount <= 2, "Use voting instead");

        unRegister(stakeHolder);
    }

    function register(address stakeHolder) private {
      require(stakeHolderIndexes[stakeHolder] == 0 || !balances[stakeHolderIndexes[stakeHolder]].isActive, "Already registered");
      
      balances[stakeHolderIndex] = Balance(stakeHolder, true, 0);
      stakeHolderIndexes[stakeHolder] = stakeHolderIndex++;
      stakeHolderCount++;
    }

    function unRegister(address stakeHolder) private {
        require(stakeHolderIndexes[stakeHolder] != 0 && balances[stakeHolderIndexes[stakeHolder]].isActive, "Already unregistered");

        balances[stakeHolderIndexes[stakeHolder]].isActive = false;
        stakeHolderCount--;
    }  
}
