// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MarketAPI} from "./lib/filecoin-solidity/contracts/v0.8/MarketAPI.sol";
import {CommonTypes} from "./lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {MarketTypes} from "./lib/filecoin-solidity/contracts/v0.8/types/MarketTypes.sol";
import {Actor, HyperActor} from "./lib/filecoin-solidity/contracts/v0.8/utils/Actor.sol";
import {Misc} from "./lib/filecoin-solidity/contracts/v0.8/utils/Misc.sol";

contract Cretodus {
    struct offer {
        bytes cidraw;
        uint deadline;
        uint size;
        uint duration;
        uint filAmount;
        uint claimerCount;
    }
    offer[] public offers;
    mapping(uint => mapping(address => bool)) public IsClaimerOfOfferId;

    event OfferCreated(uint256 indexed offerId);

    function createOffer(
        bytes calldata cidraw,
        uint deadline,
        uint size,
        uint duration
    ) public payable {
        uint256 offerId = offers.length;
        offers.push(offer(cidraw, deadline, size, duration, msg.value, 0));
        emit OfferCreated(offerId);
    }

    function fulfilOffer(uint offerId, uint64 dealId) public {
        MarketTypes.GetDealDataCommitmentReturn memory commitmentRet = MarketAPI
            .getDealDataCommitment(MarketTypes.GetDealDataCommitmentParams({id: dealId}));
        MarketTypes.GetDealProviderReturn memory providerRet = MarketAPI.getDealProvider(
            MarketTypes.GetDealProviderParams({id: dealId})
        );
        require(offers[offerId].deadline <= block.timestamp, "expired offer");
        require(keccak256(offers[offerId].cidraw) == keccak256(commitmentRet.data), "cid not match");
        require(offers[offerId].size == commitmentRet.size, "size not match");
        offers[offerId].claimerCount += 1;
        IsClaimerOfOfferId[offerId][msg.sender] = true;
    }

    function getReward(uint offerId) public {
        require(offers[offerId].deadline > block.timestamp, "not expired yet");
        require(IsClaimerOfOfferId[offerId][msg.sender], "can not claim");
        IsClaimerOfOfferId[offerId][msg.sender] = false;
        payable(address(msg.sender)).transfer(offers[offerId].filAmount/offers[offerId].claimerCount);
    }

    function getOffersLength() public view returns (uint) {
        return offers.length;
    }
}
