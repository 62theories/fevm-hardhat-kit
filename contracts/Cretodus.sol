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
        uint filAmount;
        address owner;
    }
    offer[] public offers;
    mapping(uint => uint[]) public offerIdToDealIds;
    mapping(uint => bool) public isClaimedReward;
    // mapping(uint => bool) public isExpiredClaimed;
    mapping(uint => bool) public isDealedIdUsed;
    address constant CALL_ACTOR_ID = 0xfe00000000000000000000000000000000000005;
    uint64 constant DEFAULT_FLAG = 0x00000000;
    uint64 constant METHOD_SEND = 0;

    event OfferCreated(uint256 indexed offerId);

    // ทำการสร้่ง offer ใหม่
    // @param cidraw คือ cid ของไฟล์ที่ต้องการเก็บไว้ใน filecoin
    // @param deadline คือ วันที่หมดอายุของ offer
    // @event OfferCreated จะเกิดเมื่อมีการสร้าง offer ใหม่ โดยมี offerId ที่สร้างขึ้นมาใหม่เป็น parameter
    function createOffer(
        bytes calldata cidraw,
        uint deadline
    ) public payable {
        uint256 offerId = offers.length;
        offers.push(offer(cidraw, deadline, msg.value, msg.sender));
        emit OfferCreated(offerId);
    }

    // ทำการส่ง dealId มาเพื่อเป็นการยืนยันว่าเราได้ทำการเก็บไฟล์ไว้ใน filecoin แล้ว
    // โดยจะเช็คว่า cid ของไฟล์ที่เก็บไว้ใน filecoin ตรงกับ cid ที่เราส่งมาหรือไม่
    // และจะเช็คว่า dealId ที่เราส่งมานั้นยังไม่ได้ถูกใช้งานไปแล้ว
    // และจะเช็คว่า offer นั้นยังไม่หมดอายุ
    // หลังจากที่เราทำการเก็บไฟล์ไว้ใน filecoin แล้ว จะเก็บ dealId ของ offerId นี้ไว้ใน offerIdToDealIds
    // @param offerId คือ offerId ของ offer ที่ต้องการเช็ค cid
    // @param dealId คือ dealId ที่ได้จากการเก็บไฟล์ไว้ใน filecoin
    function fulfilOffer(uint offerId, uint64 dealId) public {
        MarketTypes.GetDealDataCommitmentReturn memory commitmentRet = MarketAPI
            .getDealDataCommitment(MarketTypes.GetDealDataCommitmentParams({id: dealId}));
        require(offers[offerId].deadline > block.timestamp, "expired offer");
        require(keccak256(offers[offerId].cidraw) == keccak256(commitmentRet.data), "cid not match");
        require(!isDealedIdUsed[dealId], "dealId used");
        isDealedIdUsed[dealId] = true;
        offerIdToDealIds[offerId].push(dealId);
    }

    // ทำการ claim เหรียญ Fil ของ offer ที่ได้ถูก fulfil ไปแล้ว เพื่อส่ง Fil ไปให้กับ storage provider ทั้งหมดที่เป็นเจ้าของ dealId ของ offer
    // โดยจะให้ Fil ตามจำนวนสัดส่วนของ dealId ใน offer นั้น
    // โดยจะเช็คว่า offer นั้นยังไม่หมดอายุ
    // และจะเช็คว่ายังไม่ได้ claim offer นี้ไปแล้ว
    // @param offerId คือ offerId ของ offer ที่ต้องการ claim
    function getReward(uint offerId) public {
        require(!isClaimedReward[offerId],"claimed");
        require(offers[offerId].deadline <= block.timestamp, "not expired yet");
        isClaimedReward[offerId] = true;
        for(uint i=0;i < offerIdToDealIds[offerId].length ;i++) {
            MarketTypes.GetDealClientReturn memory clientRet = MarketAPI.getDealClient(MarketTypes.GetDealClientParams({id: uint64(offerIdToDealIds[offerId][i])}));
            send(clientRet.client, offers[offerId].filAmount/offerIdToDealIds[offerId].length);
        }
    }

    // ดึงความยาวของ offer เพื่อให้ loop ได้
    function getOffersLength() public view returns (uint) {
        return offers.length;
    }

    // function getExpiredReward(uint offerId) public {
    //     require(offers[offerId].deadline <= block.timestamp, "not expired yet");
    //     require(offers[offerId].claimerCount == 0,"claimer must be zero");
    //     require(!isExpiredClaimed[offerId],"must not claim yet");
    //     isExpiredClaimed[offerId] = true;
    //     payable(address(msg.sender)).transfer(offers[offerId].filAmount);
    // }

    // ส่ง Fil ให้กับ storage provider
    // @param actorID คือ actorID ของ storage provider
    // @param amount คือจำนวน Fil ที่ต้องการส่ง
    function send(uint64 actorID, uint amount) internal {
        bytes memory emptyParams = "";
        delete emptyParams;

        HyperActor.call_actor_id(METHOD_SEND, amount, DEFAULT_FLAG, Misc.NONE_CODEC, emptyParams, actorID);

    }

    function getSpCountOfOffer(uint offerId) public view returns (uint) {
        return offerIdToDealIds[offerId].length;
    }
}
