const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Lock", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deploy() {
    const [owner, user1, user2, user3, user4] = await ethers.getSigners();
    const VotingContract = await ethers.getContractFactory("VotingContract");
    const votingContract = await VotingContract.deploy();

    return { votingContract, owner, user1, user2, user3, user4 };
  }

  describe("Deployment And Error Handling", function () {
    it("Should set the right owner", async function () {
      const { votingContract, owner } = await loadFixture(deploy);

      // Expecting owner to be the signer who deployed the contract
      expect(await votingContract.owner()).to.equal(owner.address);
    });
  });

  describe("Voting proposal", function () {
    it("should start new Proposal", async function () {
      // Load the contract and get signers
      const { votingContract, owner, user1 } = await loadFixture(deploy);
      // Define proposal details
      const proposal = "Proposal 1";
      const options = ["Option 1", "Option 2", "Option 3"];
      // Introduce a new proposal
      await votingContract.connect(user1).introduceProposal(proposal, options, {
        value: ethers.parseEther("1"),
      });
    });

    it("can register and vote and get winner in a proposal and should revert when calling retrieve result if the proposal not ended", async function () {
      // Load the contract and get signers
      const { votingContract, owner, user1, user2, user3, user4 } =
        await loadFixture(deploy);
      // Define proposal details
      const proposal = "Proposal 1";
      const options = ["Option 1", "Option 2", "Option 3"];
      // Introduce a new proposal
      await votingContract.connect(user1).introduceProposal(proposal, options, {
        value: ethers.parseEther("1"),
      });
      // Register users for voting
      await votingContract
        .connect(user2)
        .registerForVote({ value: ethers.parseEther("0.2") });
      await votingContract
        .connect(user3)
        .registerForVote({ value: ethers.parseEther("0.2") });
      await votingContract
        .connect(user4)
        .registerForVote({ value: ethers.parseEther("0.2") });
      await votingContract
        .connect(user1)
        .registerForVote({ value: ethers.parseEther("0.2") });
      // Cast votes
      let proposalid = await votingContract.ID();
      await votingContract.connect(user2).castVotes(proposalid, 0);
      await votingContract.connect(user3).castVotes(proposalid, 1);
      await votingContract.connect(user4).castVotes(proposalid, 1);
      // if not ended it will revert if called the retrieveResults function
      await expect( votingContract.connect(owner).retrieveResults(proposalid)).to.be.revertedWithCustomError(votingContract,"NotEnded").withArgs(proposalid);
      //disabling the proposal
      await votingContract.connect(user1).disableProposal(proposalid);
      // Retrieve results
      let [winnerId, winnerCount] = await votingContract
        .connect(owner)
        .retrieveResults(proposalid);
      expect(Number(winnerId)).to.eql(1);
    });

    it("should add more options after introducing proposals", async function () {
      // Load the contract and get signers
      const { votingContract, owner, user1, user2 } = await loadFixture(deploy);
      // Define proposal details
      const proposal = "Proposal 1";
      const options = ["Option 1", "Option 2", "Option 3"];
      // Introduce a new proposal
      await votingContract.connect(user1).introduceProposal(proposal, options, {
        value: ethers.parseEther("1"),
      });
      // Get proposal ID and check initial options length
      let proposalid = await votingContract.ID();
      let optionsLength = await votingContract
        .connect(user1)
        .getProposalOptions(proposalid);
      expect(Number(optionsLength)).to.eql(options.length);
      // Add more options
      const moreOptions = ["Option 4", "Option 5", "Option 6"];
      await votingContract
        .connect(user2)
        .addMoreOptions(proposalid, moreOptions);
      const moreOptions2 = ["Option 7", "Option 8", "Option 9", "Option 10"];
      await votingContract
        .connect(user2)
        .addMoreOptions(proposalid, moreOptions2);
      optionsLength = await votingContract
        .connect(user1)
        .getProposalOptions(proposalid);
      expect(Number(optionsLength)).to.eql(
        options.length + moreOptions.length + moreOptions2.length
      );
    });

    it("should not allow to add more options after voting", async function () {
      // Load the contract and get signers
      const { votingContract, owner, user1, user2 } = await loadFixture(deploy);
      // Define proposal details
      const proposal = "Proposal 1";
      const options = ["Option 1", "Option 2", "Option 3"];
      // Introduce a new proposal
      await votingContract.connect(user1).introduceProposal(proposal, options, {
        value: ethers.parseEther("1"),
      });
      // Get proposal ID and check initial options length
      let proposalid = await votingContract.ID();
      let optionsLength = await votingContract
        .connect(user1)
        .getProposalOptions(proposalid);
      expect(Number(optionsLength)).to.eql(options.length);
      // Register users for voting
      await votingContract
        .connect(user2)
        .registerForVote({ value: ethers.parseEther("0.2") });
      await votingContract
        .connect(user1)
        .registerForVote({ value: ethers.parseEther("0.2") });

      // voting started
      await votingContract.connect(user2).castVotes(proposalid, 0);

      expect(votingContract.connect(user2).addMoreOptions(proposalid, options))
        .to.be.reverted;
    });
    
    it("should not allow to add more options after disabled", async function () {
      // Load the contract and get signers
      const { votingContract, owner, user1, user2 } = await loadFixture(deploy);
      // Define proposal details
      const proposal = "Proposal 1";
      const options = ["Option 1", "Option 2", "Option 3"];
      // Introduce a new proposal
      await votingContract.connect(user1).introduceProposal(proposal, options, {
        value: ethers.parseEther("1"),
      });
      // Get proposal ID and check initial options length
      let proposalid = await votingContract.ID();
      let optionsLength = await votingContract
        .connect(user1)
        .getProposalOptions(proposalid);
      expect(Number(optionsLength)).to.eql(options.length);
      await votingContract.connect(user1).disableProposal(proposalid);
      await expect( votingContract.connect(user2).addMoreOptions(proposalid, options)).to.be.revertedWithCustomError(votingContract, "proposalEnded").withArgs(proposalid);
    });

    it("should return all proposals of owner", async function () {
      // Load the contract and get signers
      const { votingContract, owner, user1, user2 } = await loadFixture(deploy);
      // Define proposal details
      const proposal = "Proposal 1";
      const options = ["Option 1", "Option 2", "Option 3"];
      // Introduce a three proposal
      await votingContract.connect(user1).introduceProposal(proposal, options, {
        value: ethers.parseEther("1"),
      });
      await votingContract.connect(user1).introduceProposal(proposal, options, {
        value: ethers.parseEther("1"),
      });
      await votingContract.connect(user2).introduceProposal(proposal, options, {
        value: ethers.parseEther("1"),
      });
      await votingContract.connect(user1).introduceProposal(proposal, options, {
        value: ethers.parseEther("1"),
      });
      await votingContract.connect(user2).introduceProposal(proposal, options, {
        value: ethers.parseEther("1"),
      });
      // check user 1 proposals it should be 1,2,4 and user should have 3,5
      let user1ProposalIds = await votingContract.connect(user1).getUsersProposalId();
      const user1ProposalIdsAsNumbers = user1ProposalIds.map(id => Number(id));
      expect(user1ProposalIdsAsNumbers).to.deep.equal([1,2,4]);
      let user2ProposalIds = await votingContract.connect(user2).getUsersProposalId();
      const user2ProposalIdsAsNumbers = user2ProposalIds.map(id => Number(id));
      expect(user2ProposalIdsAsNumbers).to.deep.equal([3,5]);

    })
  });
});
