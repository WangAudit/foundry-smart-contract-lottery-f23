// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title A sample Raffle Contract
 * @author unfazedDev
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {

    /** Errors */

    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /** Type Declarations  */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev duration of the lottery in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;// we added payable so the contract knows we will pay those players
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner (address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee, 
        uint256 interval, 
        address vrfCoordinator, 
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    /** Functions */

    function enterRaffle() external payable { //we made it external because we won't call it inside that contract and external will cost less gas
        //require(msg.value >= i_entranceFee, "Not enough ETH sent."); this one costs more gas, custom errors cost less
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }

        else if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }


    //When is the winner supposed to be picked?
    /**
     * @dev this is the function that the Chainlink Automation nodes call
     * to see if it's time perform an upkeep.
     * The following should be true for this to return true:
     * 1. Time interval has passed between raffle runs
     * 2. The ruffle is in the OPEN state
     * 3. The contract has ETH (aka players)
     * 4. (Implicit) The subscription is funded with LINK
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (
        bool upkeepNeeded, bytes memory /*performData*/
    ) {
        // check to see if enough time has passed
        // if((block.timestamp - s_lastTimeStamp) < i_interval) {
        //     revert();
        // }
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return(upkeepNeeded, "0x0"); //0x0 = zero bytes object 
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded,) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;
        uint requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, //gas lane = keyHash
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);
    }
    //CEI: checks, effects, interactions
    function fulfillRandomWords(
        uint256 /*requestsId*/,
        uint256[] memory randomWords
    ) internal override {
        //Checks if -> error
        //Effect (our own contract)
        uint256 indexofWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexofWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        //Interactions (with other contracts) 
        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit PickedWinner(winner);
    }

    /** Getter Functions */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns(RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns(address) {
        return s_players[indexOfPlayer];
    }

    function getLengthOfPlayers() external view returns(uint256) {
        return s_players.length;
    }

    function getWinner() external view returns(address) {
        return s_recentWinner;
    }

    function getLastTimeStamp() external view returns(uint256) {
        return s_lastTimeStamp;
    }
}