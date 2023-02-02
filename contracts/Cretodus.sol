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
        address owner;
    }
    offer[] public offers;
    mapping(uint => uint[]) public offerIdToDealIds;
    // mapping(uint => mapping(address => bool)) public isClaimerOfOfferId;
    mapping(uint => bool) public isClaimedReward;
    mapping(uint => bool) public isExpiredClaimed;
    address constant CALL_ACTOR_ID = 0xfe00000000000000000000000000000000000005;
    uint64 constant DEFAULT_FLAG = 0x00000000;
    uint64 constant METHOD_SEND = 0;

    event OfferCreated(uint256 indexed offerId);

    function createOffer(
        bytes calldata cidraw,
        uint deadline,
        uint size,
        uint duration
    ) public payable {
        uint256 offerId = offers.length;
        offers.push(offer(cidraw, deadline, size, duration, msg.value, 0, msg.sender));
        emit OfferCreated(offerId);
    }

    function fulfilOffer(uint offerId, uint64 dealId) public {
        MarketTypes.GetDealDataCommitmentReturn memory commitmentRet = MarketAPI
            .getDealDataCommitment(MarketTypes.GetDealDataCommitmentParams({id: dealId}));
        // MarketTypes.GetDealProviderReturn memory providerRet = MarketAPI.getDealProvider(
        //     MarketTypes.GetDealProviderParams({id: dealId})
        // );
        require(offers[offerId].deadline > block.timestamp, "expired offer");
        require(keccak256(offers[offerId].cidraw) == keccak256(commitmentRet.data), "cid not match");
        // require(offers[offerId].size == commitmentRet.size, "size not match");
        // offers[offerId].claimerCount += 1;
        // isClaimerOfOfferId[offerId][msg.sender] = true;
        offerIdToDealIds[offerId].push(dealId);
    }

    function getReward(uint offerId) public {
        require(!isClaimedReward[offerId],"claimed");
        require(offers[offerId].deadline <= block.timestamp, "not expired yet");
        isClaimedReward[offerId] = true;
        for(uint i=0;i < offerIdToDealIds[offerId].length ;i++) {
            MarketTypes.GetDealClientReturn memory clientRet = MarketAPI.getDealClient(MarketTypes.GetDealClientParams({id: uint64(offerIdToDealIds[offerId][i])}));
            send(clientRet.client, offers[offerId].filAmount/offerIdToDealIds[offerId].length);
        }
        // isClaimerOfOfferId[offerId][msg.sender] = false;
        // payable(address(msg.sender)).transfer(offers[offerId].filAmount/offers[offerId].claimerCount);
    }

    function getOffersLength() public view returns (uint) {
        return offers.length;
    }

    function getExpiredReward(uint offerId) public {
        require(offers[offerId].deadline <= block.timestamp, "not expired yet");
        require(offers[offerId].claimerCount == 0,"claimer must be zero");
        require(!isExpiredClaimed[offerId],"must not claim yet");
        isExpiredClaimed[offerId] = true;
        payable(address(msg.sender)).transfer(offers[offerId].filAmount);
    }

    function send(uint64 actorID, uint amount) internal {
        bytes memory emptyParams = "";
        delete emptyParams;

        HyperActor.call_actor_id(METHOD_SEND, amount, DEFAULT_FLAG, Misc.NONE_CODEC, emptyParams, actorID);

    }
}
