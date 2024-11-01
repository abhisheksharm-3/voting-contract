// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VotingPlatform {
    address public owner;
    
    struct Voter {
        bool isRegistered;
        mapping(string => bool) hasVotedInElection;  // electionId -> hasVoted
        string userId;  // Reference to Appwrite user ID
    }
    
    struct Election {
        string electionId;  // UUID from frontend
        address creator;
        string title;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        mapping(string => uint256) candidateVotes;  // candidateId -> votes
        string[] candidateIds;
        uint256 totalVotes;
        string winningCandidateId;  // Added to track winner
        bool resultsTallied;        // Added to track if results are final
    }
    
    // Main state variables
    mapping(address => Voter) public voters;
    mapping(string => Election) private elections;  // electionId -> Election
    string[] public activeElections;
    mapping(address => bool) public admins;
    
    // Events
    event UserRegistered(address indexed userAddress, string userId);
    event ElectionCreated(string indexed electionId, address creator, string title);
    event VoteCast(string indexed electionId, string candidateId);
    event ElectionStatusChanged(string indexed electionId, bool isActive);
    event AdminStatusChanged(address indexed admin, bool status);
    event ElectionResultsTallied(string indexed electionId, string winningCandidateId, uint256 winningVoteCount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }
    
    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner, "Only admin can call this");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        admins[msg.sender] = true;
    }

    // Ownership Management
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // Admin Management
    function setAdmin(address _adminAddress, bool _isAdmin) public onlyOwner {
        admins[_adminAddress] = _isAdmin;
        emit AdminStatusChanged(_adminAddress, _isAdmin);
    }

    // User Management
    function registerUser(string memory _userId) public {
        require(!voters[msg.sender].isRegistered, "User already registered");
        
        Voter storage newVoter = voters[msg.sender];
        newVoter.isRegistered = true;
        newVoter.userId = _userId;
        
        emit UserRegistered(msg.sender, _userId);
    }

    // Election Management
    function createElection(
        string memory _electionId,
        string memory _title,
        uint256 _startTime,
        uint256 _endTime,
        string[] memory _candidateIds
    ) public {
        require(voters[msg.sender].isRegistered, "User not registered");
        require(_startTime > block.timestamp, "Start time must be in future");
        require(_endTime > _startTime, "End time must be after start time");
        
        Election storage newElection = elections[_electionId];
        newElection.electionId = _electionId;
        newElection.creator = msg.sender;
        newElection.title = _title;
        newElection.startTime = _startTime;
        newElection.endTime = _endTime;
        newElection.isActive = true;
        newElection.candidateIds = _candidateIds;
        newElection.resultsTallied = false;
        
        activeElections.push(_electionId);
        
        emit ElectionCreated(_electionId, msg.sender, _title);
    }

    // Voting
    function castVote(string memory _electionId, string memory _candidateId) public {
        require(voters[msg.sender].isRegistered, "User not registered");
        require(!voters[msg.sender].hasVotedInElection[_electionId], "Already voted in this election");
        require(isElectionActive(_electionId), "Election is not active");
        require(isCandidateValid(_electionId, _candidateId), "Invalid candidate");
        
        Election storage election = elections[_electionId];
        require(block.timestamp >= election.startTime, "Election has not started");
        require(block.timestamp <= election.endTime, "Election has ended");
        
        voters[msg.sender].hasVotedInElection[_electionId] = true;
        election.candidateVotes[_candidateId]++;
        election.totalVotes++;
        
        emit VoteCast(_electionId, _candidateId);
    }

    // Results and Tallying
    function tallyElectionResults(string memory _electionId) public onlyAdmin {
        Election storage election = elections[_electionId];
        require(!election.resultsTallied, "Results already tallied");
        require(block.timestamp > election.endTime, "Election not ended yet");
        
        uint256 highestVotes = 0;
        string memory winningCandidate = "";
        
        for (uint i = 0; i < election.candidateIds.length; i++) {
            string memory candidateId = election.candidateIds[i];
            uint256 votes = election.candidateVotes[candidateId];
            if (votes > highestVotes) {
                highestVotes = votes;
                winningCandidate = candidateId;
            }
        }
        
        election.winningCandidateId = winningCandidate;
        election.resultsTallied = true;
        
        emit ElectionResultsTallied(_electionId, winningCandidate, highestVotes);
    }

    // View Functions
    function getElectionDetails(string memory _electionId) public view returns (
        address creator,
        string memory title,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        uint256 totalVotes,
        string[] memory candidateIds,
        string memory winningCandidateId,
        bool resultsTallied
    ) {
        Election storage election = elections[_electionId];
        return (
            election.creator,
            election.title,
            election.startTime,
            election.endTime,
            election.isActive,
            election.totalVotes,
            election.candidateIds,
            election.winningCandidateId,
            election.resultsTallied
        );
    }
    
    function getCandidateVotes(string memory _electionId, string memory _candidateId) 
        public view returns (uint256) 
    {
        return elections[_electionId].candidateVotes[_candidateId];
    }
    
    function isElectionActive(string memory _electionId) public view returns (bool) {
        Election storage election = elections[_electionId];
        return election.isActive && 
               block.timestamp >= election.startTime && 
               block.timestamp <= election.endTime;
    }

    function getWinningCandidate(string memory _electionId) public view returns (
        string memory winningCandidateId,
        uint256 winningVoteCount
    ) {
        Election storage election = elections[_electionId];
        require(election.resultsTallied, "Results not tallied yet");
        
        winningCandidateId = election.winningCandidateId;
        winningVoteCount = election.candidateVotes[winningCandidateId];
    }

    function getActiveElectionsCount() public view returns (uint256) {
        return activeElections.length;
    }

    function hasUserVoted(string memory _electionId, address _voter) public view returns (bool) {
        return voters[_voter].hasVotedInElection[_electionId];
    }
    
    // Helper Functions
    function isCandidateValid(string memory _electionId, string memory _candidateId) 
        internal view returns (bool) 
    {
        string[] memory candidates = elections[_electionId].candidateIds;
        for (uint i = 0; i < candidates.length; i++) {
            if (keccak256(bytes(candidates[i])) == keccak256(bytes(_candidateId))) {
                return true;
            }
        }
        return false;
    }
    // Function to get all active elections
function getAllActiveElections() public view returns (string[] memory) {
    return activeElections;
}

// Function to update an existing election (only by the election creator or an admin)
function updateElection(
    string memory _electionId,
    string memory _newTitle,
    uint256 _newStartTime,
    uint256 _newEndTime,
    string[] memory _newCandidateIds
) public {
    Election storage election = elections[_electionId];
    
    // Ensure only the creator or an admin can update the election
    require(
        msg.sender == election.creator || admins[msg.sender], 
        "Only election creator or admin can update"
    );
    
    // Ensure the election hasn't started yet
    require(
        block.timestamp < election.startTime, 
        "Cannot update an election that has already started"
    );
    
    // Validate new times
    require(_newStartTime > block.timestamp, "Start time must be in future");
    require(_newEndTime > _newStartTime, "End time must be after start time");
    
    // Update election details
    election.title = _newTitle;
    election.startTime = _newStartTime;
    election.endTime = _newEndTime;
    
    // Clear existing candidates and set new candidates
    delete election.candidateIds;
    election.candidateIds = _newCandidateIds;
    
    // Reset vote tracking for the election
    election.totalVotes = 0;
    election.resultsTallied = false;
    election.winningCandidateId = "";
    
    // Clear existing candidate votes
    for (uint i = 0; i < _newCandidateIds.length; i++) {
        election.candidateVotes[_newCandidateIds[i]] = 0;
    }
    
    // Emit an event to notify about the election update
    emit ElectionStatusChanged(_electionId, true);
}
}
