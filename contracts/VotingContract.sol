// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract VotingContract {
    using EnumerableSet for EnumerableSet.UintSet;

    struct Options {
        string name;
        uint voteCount;
    }

    struct Proposal {
        address owner;
        string proposalStatement;
        Options[] options;
        uint totalVotes;
        bool hasEnded;
    }

    //STATE VARIABLES
    address public owner;
    uint public ID; // counter for new Ids -- Id will start with 1 not 0
    mapping(uint => Proposal) proposals;
    // extra data structures which is not needed in this contract I have made it because there is no backend involved currently
    mapping(address => uint) numberOfProposalCreatedByUser;
    mapping(address => EnumerableSet.UintSet) usersPropasals;

    mapping(address => mapping(uint proposalID => bool)) voted; // to verify if the user voted or not

    mapping(address user => bool) registeredToVote; // To check if the user is registered for voting

    uint votingFees = 0.2 ether;
    uint proposalFees = 0.5 ether;
    uint8 constant optionsLengthLimit = 10;

    //EVENTS
    event NewProposalAdded(
        uint indexed _id,
        address indexed owner,
        string statement
    );
    event RegisteredForVote(address indexed user, uint fees);
    event voteCasted(
        uint indexed proposalId,
        uint optionsId,
        address indexed owner
    );
    event withdrawedFunds(uint fundsWithdrawn);
    event votingFeesUpdated(uint newVotingFee);
    event proposalFeeUpdated(uint newProposalFee);
    event OptionsAdded(uint indexed proposalId, string[] options);
    event ProposalEnded(uint proposalId);

    //ERRORS
    error notOwner(address);
    error IdNotCorrect(uint id, address user);
    error notRegistered(address user);
    error proposalEnded(uint id);
    error NotEnoughEthSentForProposal(uint fees, address msgSender);
    error OptionsLengthShouldBeSmaller(uint OptionLength, address msgSender);
    error NotRegisteredForVoting(address user);
    error invalidOptionId(uint id);
    error lessFeeSet(uint fees);
    error notProposalOwner(uint id, address user);
    error notOwnerOrProposalOwner(uint id, address user);
    error withdrawTransactionFailed();
    error votingFeeNotEnough(uint fee);
    error AlreadyRegistered(address user);
    error ownerCannotVote(uint id);
    error alreadyVoted(address user, uint id);
    error NotEnded(uint id);
    error votingStarted(uint proposalId);

    //MODIFIERS
    modifier onlyOwner() {
        if (owner != msg.sender) {
            revert notOwner(msg.sender);
        } else {
            _;
        }
    }
    modifier checkId(uint _id) {
        if (_id > ID) {
            revert IdNotCorrect(_id, msg.sender);
        } else {
            _;
        }
    }
    modifier checkIfOwnerVoting(uint _id) {
        if (proposals[_id].owner == msg.sender) {
            revert ownerCannotVote(_id);
        } else {
            _;
        }
    }
    modifier checkIfRegistered() {
        if (!registeredToVote[msg.sender]) {
            revert notRegistered(msg.sender);
        } else {
            _;
        }
    }

    modifier checkIfDisabled(uint _id) {
        if (proposals[_id].hasEnded) {
            revert proposalEnded(_id);
        } else {
            _;
        }
    }

    modifier checkIfProposalOwner(uint id) {
        if (proposals[id].owner == msg.sender) {
            revert notProposalOwner(id, msg.sender);
        } else {
            _;
        }
    }

    modifier checkIfProposalOwnerOrOwner(uint id) {
        if (msg.sender == proposals[id].owner || msg.sender == owner) {
            _;
        } else {
            revert notOwnerOrProposalOwner(id, msg.sender);
        }
    }

    //Functions

    constructor() {
        owner = msg.sender;
    }

    //Core Functions

    /// @notice Introduces a new proposal with the given statement and options.
    /// @dev The caller must send enough ether for the proposal fees.
    /// @param _proposalStatement The statement or description of the proposal.
    /// @param _options An array of strings representing the available options for the proposal.
    function introduceProposal(
        string calldata _proposalStatement,
        string[] calldata _options
    ) external payable {
        uint msgValue = msg.value; // gas saving by making it local variable
        address msgSender = msg.sender;
        if (msgValue < proposalFees) {
            revert NotEnoughEthSentForProposal(msgValue, msgSender);
        }
        if (_options.length > 10) {
            revert OptionsLengthShouldBeSmaller(_options.length, msgSender);
        }
        //setting global variable to local saving gas

        //incrementing id with every new proposal
        ID += 1;
        uint id = ID;

        Proposal storage newProposal = proposals[id];

        newProposal.owner = msgSender;
        newProposal.proposalStatement = _proposalStatement;

        for (uint i = 0; i < _options.length; i++) {
            newProposal.options.push(Options(_options[i], 0));
        }

        //newProposal.hasEnded = false; //this will be by default false

        //set user proposal mapping for retrieval
        // As there is no backend I am storing most of the data inside of the contract fo easy retrieval
        // currently it will not be that useful as I am adding the functionality accordinf to reuqirement
        // of the assignement.
        numberOfProposalCreatedByUser[msgSender] += 1;
        usersPropasals[msgSender].add(id);

        emit NewProposalAdded(id, msgSender, _proposalStatement);
    }

    /// @notice Adds more options to an existing proposal.
    /// @dev Only the owner of the proposal can add more options.
    /// @param id The ID of the proposal to which options are being added.
    /// @param _options An array of strings representing the new options to be added.
    function addMoreOptions(
        uint id,
        string[] memory _options
    ) external checkId(id) checkIfProposalOwner(id) checkIfDisabled(id) {
        Proposal storage proposal = proposals[id];
        uint totalLength = proposal.options.length + _options.length;
        if (totalLength > optionsLengthLimit) {
            revert OptionsLengthShouldBeSmaller(totalLength, msg.sender);
        }
        if (proposal.totalVotes > 0) {
            revert votingStarted(id);
        }
        for (uint i; i < _options.length; i++) {
            proposal.options.push(Options(_options[i], 0));
        }

        emit OptionsAdded(id, _options);
    }

    /// @notice Allows a user to register for voting by paying the voting fees.
    /// @dev Users must send enough ether to cover the voting fees.
    function registerForVote() external payable {
        address msgSender = msg.sender; // gas saving local variable
        if (msg.value < votingFees) {
            revert votingFeeNotEnough(msg.value);
        }
        if (registeredToVote[msgSender] == true) {
            revert AlreadyRegistered(msgSender);
        }

        registeredToVote[msgSender] = true;
        emit RegisteredForVote(msgSender, msg.value);
    }

    /// @notice Casts a vote for a specific option in a proposal.
    /// @dev The caller must be registered for voting, and the proposal must be active.
    /// @param _id The ID of the proposal for which the vote is being cast.
    /// @param _optionId The ID of the option being voted for within the proposal.
    function castVotes(
        uint _id,
        uint _optionId
    )
        external
        checkId(_id)
        checkIfOwnerVoting(_id)
        checkIfRegistered
        checkIfDisabled(_id)
    {
        Proposal storage proposal = proposals[_id];
        if (_optionId > proposal.options.length) {
            revert invalidOptionId(_optionId);
        }
        address msgSender = msg.sender;
        if (voted[msgSender][_id]) {
            revert alreadyVoted(msgSender, _id);
        }
        proposal.options[_optionId].voteCount++;
        proposal.totalVotes += 1;
        voted[msgSender][_id] = true;
        emit voteCasted(_id, _optionId, msgSender);
    }

    /// @notice Allows the contract owner to withdraw the contract's balance.
    /// @dev The contract balance must be greater than 1 ether for withdrawal to be allowed.
    /// @dev Emits a `withdrawedFunds` event upon successful withdrawal.
    function withdrawFunds() external onlyOwner {
        uint balance = address(this).balance;
        require(balance > 1 ether, "Not enought ether in contract");
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) {
            revert withdrawTransactionFailed();
        }
        emit withdrawedFunds(balance);
    }

    /// @notice Allows the contract owner to update the fee required for voter registration.
    /// @dev The new fee must be at least 1 ether.
    /// @param fees The new fee amount to be set.
    /// @dev Emits a `votingFeesUpdated` event upon successful fee update.
    function updateVotingFees(uint fees) external onlyOwner {
        if (fees < 1 ether) {
            revert lessFeeSet(fees);
        }
        votingFees = fees;

        emit votingFeesUpdated(fees);
    }

    /// @notice Allows the contract owner to update the fee required for proposing new proposals.
    /// @dev The new fee must be at least 2 ether.
    /// @param fees The new fee amount to be set.
    /// @dev Emits a `proposalFeeUpdated` event upon successful fee update.
    function updateProposalFee(uint fees) external onlyOwner {
        if (fees < 2 ether) {
            revert lessFeeSet(fees);
        }
        proposalFees = fees;
        emit proposalFeeUpdated(fees);
    }

    /// @notice Disables a proposal, marking it as ended.
    /// @dev This function can only be called by the owner of the contract or the owner of the proposal.
    /// @dev It also checks whether the proposal ID is valid and if the proposal has already ended.
    /// @param id The ID of the proposal to disable.
    function disableProposal(
        uint id
    ) external checkIfProposalOwnerOrOwner(id) checkId(id) checkIfDisabled(id) {
        proposals[id].hasEnded = true;
        emit ProposalEnded(id);
    }

    /// @notice Retrieves the winning option and its vote count for a proposal that has ended.
    /// @dev The proposal must have ended for the results to be retrieved.
    /// @param proposalId The ID of the proposal for which results are being retrieved.
    /// @return winnerId The ID of the winning option.
    /// @return winnerCount The number of votes received by the winning option.
    function retrieveResults(
        uint proposalId
    )
        external
        view
        checkId(proposalId)
        checkIfProposalOwnerOrOwner(proposalId)
        returns (uint winnerId, uint winnerCount)
    {
        Proposal memory proposal = proposals[proposalId];
        if (!proposal.hasEnded) {
            revert NotEnded(proposalId);
        }
        uint optionsLength = proposal.options.length;
        for (uint i; i < optionsLength; i++) {
            if (proposal.options[i].voteCount > winnerCount) {
                winnerCount = proposal.options[i].voteCount;
                winnerId = i;
            }
        }
    }

    /// @notice Retrieves the proposal details associated with the given ID for the calling user.
    /// @dev This function is meant for retrieving proposal details for the user who called it.
    /// @param id The ID of the proposal to retrieve.
    /// @return proposal The proposal details associated with the given ID.
    function getProposalForUser(
        uint id
    ) external view checkId(id) returns (Proposal memory) {
        return proposals[id];
    }

    /// @notice Retrieves the IDs of the proposals created by the calling user.
    /// @dev Only users with at least one proposal will have their IDs returned.
    /// @return An array containing the IDs of the proposals created by the caller.
    function getUsersProposalId() external view returns (uint[] memory) {
        require(
            usersPropasals[msg.sender].length() > 0,
            "There are no Proposals"
        );

        return usersPropasals[msg.sender].values();
    }

    function getProposalOptions(
        uint id
    ) external view checkId(id) returns (uint) {
        return proposals[id].options.length;
    }

    function getProposalOptionsName(
        uint id,
        uint optionId
    ) external view checkId(id) returns (string memory) {
        return proposals[id].options[optionId].name;
    }
}
