// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Voting {

    address public owner;
    
    enum ApprovalStatus { Pending, Approved, Rejected }
    enum VotingStatus { Pending, Completed }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedProposalId;
        string documentIPFSHash;
        string profileImageIPFSHash;
        ApprovalStatus approvalStatus;
    }

    struct Proposal {
        string name;
        uint256 voteCount;
        string documentIPFSHash;
        string profileImageIPFSHash;
        address submitter;
        ApprovalStatus approvalStatus;
        VotingStatus votingStatus;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    WorkflowStatus public workflowStatus;
    uint256 private _proposalCount;
    uint256 private _voterCount;
    mapping(address => Voter) public voters;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public admins;

    event VoterRegistered(address voterAddress);
    event ProposalRegistered(uint256 proposalId);
    event Voted(address voter, uint256 proposalId);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event VoterApprovalStatusChanged(address voter, ApprovalStatus status);
    event ProposalApprovalStatusChanged(uint256 proposalId, ApprovalStatus status);
    event AdminStatusChanged(address admin, bool isAdmin);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner, "Only admin or owner can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
        workflowStatus = WorkflowStatus.RegisteringVoters;
        admins[msg.sender] = true;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function registerVoter(string memory _documentIPFSHash, string memory _profileImageIPFSHash) public {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Voter registration is not open");
        require(!voters[msg.sender].isRegistered, "Voter already registered");

        voters[msg.sender] = Voter({
            isRegistered: true,
            hasVoted: false,
            votedProposalId: 0,
            documentIPFSHash: _documentIPFSHash,
            profileImageIPFSHash: _profileImageIPFSHash,
            approvalStatus: ApprovalStatus.Pending
        });

        _voterCount++;
        emit VoterRegistered(msg.sender);
    }

    function approveRejectVoter(address _voterAddress, ApprovalStatus _status) public onlyAdmin {
        require(voters[_voterAddress].isRegistered, "Voter not registered");
        voters[_voterAddress].approvalStatus = _status;
        emit VoterApprovalStatusChanged(_voterAddress, _status);
    }

    function updateVoter(string memory _documentIPFSHash, string memory _profileImageIPFSHash) public {
        require(voters[msg.sender].isRegistered, "Voter not registered");
        voters[msg.sender].documentIPFSHash = _documentIPFSHash;
        voters[msg.sender].profileImageIPFSHash = _profileImageIPFSHash;
        voters[msg.sender].approvalStatus = ApprovalStatus.Pending;
        emit VoterApprovalStatusChanged(msg.sender, ApprovalStatus.Pending);
    }

    function registerProposal(string memory _name, string memory _documentIPFSHash, string memory _profileImageIPFSHash) public onlyAdmin {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposal registration is not open");

        _proposalCount++;
        uint256 newProposalId = _proposalCount;
        proposals[newProposalId] = Proposal({
            name: _name,
            voteCount: 0,
            documentIPFSHash: _documentIPFSHash,
            profileImageIPFSHash: _profileImageIPFSHash,
            submitter: msg.sender,
            approvalStatus: ApprovalStatus.Pending,
            votingStatus: VotingStatus.Pending
        });

        emit ProposalRegistered(newProposalId);
    }

    function approveRejectProposal(uint256 _proposalId, ApprovalStatus _status) public onlyAdmin {
        require(_proposalId > 0 && _proposalId <= _proposalCount, "Invalid proposal");
        proposals[_proposalId].approvalStatus = _status;
        emit ProposalApprovalStatusChanged(_proposalId, _status);
    }

    function updateProposal(uint256 _proposalId, string memory _name, string memory _documentIPFSHash, string memory _profileImageIPFSHash) public onlyAdmin {
        require(_proposalId > 0 && _proposalId <= _proposalCount, "Invalid proposal");
        Proposal storage proposal = proposals[_proposalId];
        proposal.name = _name;
        proposal.documentIPFSHash = _documentIPFSHash;
        proposal.profileImageIPFSHash = _profileImageIPFSHash;
        proposal.approvalStatus = ApprovalStatus.Pending;
        emit ProposalApprovalStatusChanged(_proposalId, ApprovalStatus.Pending);
    }

    function vote(uint256 _proposalId) public {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session hasn't started");
        require(voters[msg.sender].approvalStatus == ApprovalStatus.Approved, "Voter not approved");
        require(!voters[msg.sender].hasVoted, "You have already voted");
        require(_proposalId > 0 && _proposalId <= _proposalCount, "Invalid proposal");
        require(proposals[_proposalId].approvalStatus == ApprovalStatus.Approved, "Proposal not approved");

        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;
        proposals[_proposalId].voteCount++;

        emit Voted(msg.sender, _proposalId);
    }

    function getApprovedVoters() public view returns (address[] memory) {
        address[] memory approvedVoters = new address[](_voterCount);
        uint256 count = 0;
        for (uint256 i = 1; i <= _voterCount; i++) {
            address voterAddress = address(uint160(i));
            if (voters[voterAddress].approvalStatus == ApprovalStatus.Approved) {
                approvedVoters[count] = voterAddress;
                count++;
            }
        }
        return approvedVoters;
    }

    function getApprovedProposals(VotingStatus _status) public view returns (uint256[] memory) {
        uint256[] memory approvedProposals = new uint256[](_proposalCount);
        uint256 count = 0;
        for (uint256 i = 1; i <= _proposalCount; i++) {
            if (proposals[i].approvalStatus == ApprovalStatus.Approved && proposals[i].votingStatus == _status) {
                approvedProposals[count] = i;
                count++;
            }
        }
        return approvedProposals;
    }

    function setAdmin(address _adminAddress, bool _isAdmin) public onlyOwner {
        admins[_adminAddress] = _isAdmin;
        emit AdminStatusChanged(_adminAddress, _isAdmin);
    }

    function startProposalRegistration() public onlyAdmin {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Can't start proposal registration now");
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function endProposalRegistration() public onlyAdmin {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposal registration is not in progress");
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    function startVotingSession() public onlyAdmin {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Can't start voting session now");
        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    function endVotingSession() public onlyAdmin {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session hasn't started");
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    function tallyVotes() public onlyAdmin {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "Can't tally votes before voting session is ended");
        workflowStatus = WorkflowStatus.VotesTallied;
        for (uint256 i = 1; i <= _proposalCount; i++) {
            if (proposals[i].approvalStatus == ApprovalStatus.Approved) {
                proposals[i].votingStatus = VotingStatus.Completed;
            }
        }
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }

    function getWinningProposal() public view returns (uint256 winningProposalId) {
        require(workflowStatus == WorkflowStatus.VotesTallied, "Votes have not been tallied yet");
        uint256 winningVoteCount = 0;
        for (uint256 p = 1; p <= _proposalCount; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposalId = p;
            }
        }
    }

    function getProposal(uint256 _proposalId) public view returns (
        string memory name,
        uint256 voteCount,
        string memory documentIPFSHash,
        string memory profileImageIPFSHash,
        address submitter,
        ApprovalStatus approvalStatus,
        VotingStatus votingStatus
    ) {
        require(_proposalId > 0 && _proposalId <= _proposalCount, "Invalid proposal");
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.name,
            proposal.voteCount,
            proposal.documentIPFSHash,
            proposal.profileImageIPFSHash,
            proposal.submitter,
            proposal.approvalStatus,
            proposal.votingStatus
        );
    }

    function getVoter(address _voterAddress) public view returns (
        bool isRegistered,
        bool hasVoted,
        uint256 votedProposalId,
        string memory documentIPFSHash,
        string memory profileImageIPFSHash,
        ApprovalStatus approvalStatus
    ) {
        Voter storage voter = voters[_voterAddress];
        return (
            voter.isRegistered,
            voter.hasVoted,
            voter.votedProposalId,
            voter.documentIPFSHash,
            voter.profileImageIPFSHash,
            voter.approvalStatus
        );
    }
}