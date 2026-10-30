
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Crowdfunding {

    uint256 public campaignCount;

    struct Campaign {
        uint256 id;
        address payable creator;
        string title;
        string description;
        uint256 goal;
        uint256 amountRaised;
        uint256 deadline;
        bool withdrawn;
        address[] backers;
    }

    mapping(uint256 => Campaign) public campaigns;

    mapping(uint256 => mapping(address => uint256))
        public contributions;

    event CampaignCreated(
        uint256 campaignId,
        address creator,
        string title,
        uint256 goal,
        uint256 deadline
    );

    event DonationReceived(
        uint256 campaignId,
        address backer,
        uint256 amount
    );

    event RefundIssued(
        uint256 campaignId,
        address backer,
        uint256 amount
    );

    event FundsWithdrawn(
        uint256 campaignId,
        address creator,
        uint256 amount
    );

    // Create a new campaign
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _duration
    ) public {

        require(bytes(_title).length > 0, "Enter campaign title");
        require(_goal > 0, "Goal must be greater than zero");
        require(_duration > 0, "Invalid duration");

        campaignCount++;

        Campaign storage campaign = campaigns[campaignCount];

        campaign.id = campaignCount;
        campaign.creator = payable(msg.sender);
        campaign.title = _title;
        campaign.description = _description;
        campaign.goal = _goal;
        campaign.deadline = block.timestamp + _duration;

        emit CampaignCreated(
            campaignCount,
            msg.sender,
            _title,
            _goal,
            campaign.deadline
        );
    }

    // Donate to a campaign
    function donate(uint256 _campaignId) public payable {

        Campaign storage campaign = campaigns[_campaignId];

        require(_campaignId > 0 && _campaignId <= campaignCount,
            "Campaign does not exist");

        require(block.timestamp < campaign.deadline,
            "Campaign deadline passed");

        require(campaign.amountRaised < campaign.goal,
            "Funding goal already reached");

        require(msg.value > 0, "Donation must be greater than zero");

        uint256 remaining = campaign.goal - campaign.amountRaised;
        uint256 accepted = msg.value;

        if (accepted > remaining) {
            accepted = remaining;
        }

        campaign.amountRaised += accepted;
        contributions[_campaignId][msg.sender] += accepted;

        bool alreadyBacker = false;

        for (uint256 i = 0; i < campaign.backers.length; i++) {
            if (campaign.backers[i] == msg.sender) {
                alreadyBacker = true;
                break;
            }
        }

        if (!alreadyBacker) {
            campaign.backers.push(msg.sender);
        }

        // Return any excess donation
        if (msg.value > accepted) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - accepted
            }("");
            require(success, "Excess refund failed");
        }

        emit DonationReceived(
            _campaignId,
            msg.sender,
            accepted
        );
    }

    // Withdraw funds if campaign goal is reached after deadline
    function withdrawFunds(uint256 _campaignId) public {

        Campaign storage campaign = campaigns[_campaignId];

        require(_campaignId > 0 && _campaignId <= campaignCount,
            "Campaign does not exist");

        require(msg.sender == campaign.creator,
            "Only creator can withdraw");

        require(block.timestamp >= campaign.deadline,
            "Campaign is still active");

        require(campaign.amountRaised >= campaign.goal,
            "Funding goal not reached");

        require(!campaign.withdrawn, "Already withdrawn");

        campaign.withdrawn = true;

        uint256 amount = campaign.amountRaised;

        (bool success, ) = campaign.creator.call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(_campaignId, msg.sender, amount);
    }

    // Refund donation if campaign goal is not reached
    function claimRefund(uint256 _campaignId) public {

        Campaign storage campaign = campaigns[_campaignId];

        require(_campaignId > 0 && _campaignId <= campaignCount,
            "Campaign does not exist");

        require(block.timestamp >= campaign.deadline,
            "Campaign is still active");

        require(campaign.amountRaised < campaign.goal,
            "Funding goal was reached");

        uint256 amount = contributions[_campaignId][msg.sender];

        require(amount > 0, "No donation to refund");

        contributions[_campaignId][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Refund failed");

        emit RefundIssued(_campaignId, msg.sender, amount);
    }

    // Get campaign details
    function getCampaign(uint256 _campaignId)
        public
        view
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goal,
            uint256 amountRaised,
            uint256 deadline,
            bool withdrawn
        )
    {
        require(_campaignId > 0 && _campaignId <= campaignCount,
            "Campaign does not exist");

        Campaign storage c = campaigns[_campaignId];

        return (
            c.creator,
            c.title,
            c.description,
            c.goal,
            c.amountRaised,
            c.deadline,
            c.withdrawn
        );
    }

    // Get all backers
    function getBackers(uint256 _campaignId)
        public
        view
        returns (address[] memory)
    {
        require(_campaignId > 0 && _campaignId <= campaignCount,
            "Campaign does not exist");

        return campaigns[_campaignId].backers;
    }

    // Check individual contribution
    function getMyContribution(uint256 _campaignId)
        public
        view
        returns (uint256)
    {
        return contributions[_campaignId][msg.sender];
    }

    // Check campaign progress in percentage
    function getProgress(uint256 _campaignId)
        public
        view
        returns (uint256)
    {
        require(_campaignId > 0 && _campaignId <= campaignCount,
            "Campaign does not exist");

        Campaign storage c = campaigns[_campaignId];

        return (c.amountRaised * 100) / c.goal;
    }
}
