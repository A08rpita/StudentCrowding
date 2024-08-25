// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StudentCrowdfunding {

    enum Category { Education, Technology, Health, Arts, Other }

    struct Campaign {
        address payable owner;
        string title;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 amountRaised;
        bool isCompleted;
        bool isPrivate;
        address[] allowedViewers;
        Category category;
        uint256 refundDeadline;
        string updates;
        uint256 minContribution;
        mapping(address => uint256) contributions;
        mapping(address => string) donationMessages;
        Review[] reviews;
    }

    struct Review {
        address reviewer;
        uint8 rating; // 1 to 5 scale
        string comment;
    }

    uint256 public campaignCount;
    mapping(uint256 => Campaign) public campaigns;

    event CampaignCreated(uint256 campaignId, address owner, uint256 goal, uint256 deadline);
    event ContributionReceived(uint256 campaignId, address contributor, uint256 amount, string message);
    event FundsWithdrawn(uint256 campaignId, uint256 amount);
    event RefundIssued(uint256 campaignId, address contributor, uint256 amount);
    event CampaignExpired(uint256 campaignId);
    event UpdateAdded(uint256 campaignId, string update);
    event PrivacyUpdated(uint256 campaignId, bool isPrivate, address[] allowedViewers);
    event DeadlineExtended(uint256 campaignId, uint256 newDeadline);
    event MinContributionSet(uint256 campaignId, uint256 minContribution);
    event RefundDeadlineSet(uint256 campaignId, uint256 refundDeadline);
    event ReviewAdded(uint256 campaignId, address reviewer, uint8 rating, string comment);

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _deadline,
        Category _category,
        uint256 _minContribution,
        uint256 _refundDeadline
    ) public {
        require(_goal > 0, "Goal must be greater than zero.");
        require(_deadline > block.timestamp, "Deadline must be in the future.");

        campaignCount++;
        Campaign storage newCampaign = campaigns[campaignCount];
        newCampaign.owner = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goal = _goal;
        newCampaign.deadline = _deadline;
        newCampaign.amountRaised = 0;
        newCampaign.isCompleted = false;
        newCampaign.category = _category;
        newCampaign.minContribution = _minContribution;
        newCampaign.refundDeadline = _refundDeadline;

        emit CampaignCreated(campaignCount, msg.sender, _goal, _deadline);
    }

    function contribute(uint256 _campaignId, string memory _message) public payable {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "Campaign has ended.");
        require(msg.value >= campaign.minContribution, "Contribution must be at least the minimum amount.");
        require(!campaign.isPrivate || isAllowedViewer(_campaignId, msg.sender), "Campaign is private.");

        campaign.amountRaised += msg.value;
        campaign.contributions[msg.sender] += msg.value;
        campaign.donationMessages[msg.sender] = _message;

        emit ContributionReceived(_campaignId, msg.sender, msg.value, _message);
    }

    function withdrawFunds(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.owner, "Only campaign owner can withdraw funds.");
        require(block.timestamp >= campaign.deadline, "Campaign is still ongoing.");
        require(campaign.amountRaised >= campaign.goal, "Campaign goal not reached.");
        require(!campaign.isCompleted, "Funds already withdrawn.");

        campaign.isCompleted = true;
        uint256 amount = campaign.amountRaised;
        campaign.amountRaised = 0;
        campaign.owner.transfer(amount);

        emit FundsWithdrawn(_campaignId, amount);
    }

    function refund(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign is still ongoing.");
        require(campaign.amountRaised < campaign.goal, "Campaign goal was reached.");
        require(campaign.contributions[msg.sender] > 0, "No contributions to refund.");
        require(block.timestamp <= campaign.refundDeadline, "Refund period has ended.");

        uint256 contribution = campaign.contributions[msg.sender];
        campaign.contributions[msg.sender] = 0;
        payable(msg.sender).transfer(contribution);

        emit RefundIssued(_campaignId, msg.sender, contribution);
    }

    function addUpdate(uint256 _campaignId, string memory _update) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.owner, "Only campaign owner can add updates.");
        campaign.updates = _update;

        emit UpdateAdded(_campaignId, _update);
    }

    function setPrivacy(uint256 _campaignId, bool _isPrivate, address[] memory _allowedViewers) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.owner, "Only campaign owner can set privacy.");
        campaign.isPrivate = _isPrivate;
        campaign.allowedViewers = _allowedViewers;

        emit PrivacyUpdated(_campaignId, _isPrivate, _allowedViewers);
    }

    function extendDeadline(uint256 _campaignId, uint256 _newDeadline) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.owner, "Only campaign owner can extend deadline.");
        require(_newDeadline > campaign.deadline, "New deadline must be after current deadline.");
        campaign.deadline = _newDeadline;

        emit DeadlineExtended(_campaignId, _newDeadline);
    }

    function setMinContribution(uint256 _campaignId, uint256 _amount) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.owner, "Only campaign owner can set minimum contribution.");
        campaign.minContribution = _amount;

        emit MinContributionSet(_campaignId, _amount);
    }

    function setRefundDeadline(uint256 _campaignId, uint256 _deadline) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.owner, "Only campaign owner can set refund deadline.");
        campaign.refundDeadline = _deadline;

        emit RefundDeadlineSet(_campaignId, _deadline);
    }

    function addReview(uint256 _campaignId, uint8 _rating, string memory _comment) public {
        require(_rating >= 1 && _rating <= 5, "Rating must be between 1 and 5.");

        Campaign storage campaign = campaigns[_campaignId];
        campaign.reviews.push(Review({
            reviewer: msg.sender,
            rating: _rating,
            comment: _comment
        }));

        emit ReviewAdded(_campaignId, msg.sender, _rating, _comment);
    }

    function handleExpiredCampaigns() public {
        for (uint256 i = 1; i <= campaignCount; i++) {
            Campaign storage campaign = campaigns[i];
            if (block.timestamp >= campaign.deadline && !campaign.isCompleted) {
                if (campaign.amountRaised < campaign.goal) {
                    campaign.isCompleted = true;
                    emit CampaignExpired(i);
                }
            }
        }
    }

    function isAllowedViewer(uint256 _campaignId, address _viewer) internal view returns (bool) {
        Campaign storage campaign = campaigns[_campaignId];
        if (!campaign.isPrivate) {
            return true;
        }
        for (uint256 i = 0; i < campaign.allowedViewers.length; i++) {
            if (campaign.allowedViewers[i] == _viewer) {
                return true;
            }
        }
        return false;
    }
}
