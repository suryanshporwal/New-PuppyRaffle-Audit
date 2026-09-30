Denial of service attack

### [S-#] Looping through players array to check for duplicates in `PuppyRaffle::enterRaffle` is a potential denial of service(DoS) attack, incrementing gas costs for future entrants.

Impact: Medium
Likelyhood: Medium

**Description** The `PuppyRaffle:enterRaffle` function loops through the `PuppyRaffle::players` array to check for duplicates. However, the longer the `PuppyRaffle::players` array gets, the more checks a new players will have to make. This means the gas costs for player who enter right wen the raffle stats will be dramatically lower than those who enter later. Every additional address in the `players` array, is an additional check the loop will have to make.

```javascript
// @audit
    for (uint256 i = 0; i < players.length - 1; i++) {
@>       for (uint256 j = i + 1; j < players.length; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }
```


**Impact** The gas costs for raffle entrants will greatly increase as more players enter the raffle, discouraging later users from entering the raffle and causing a rush at the start of raffle to be one of the first entrants in the queue. 

An attacker might make the `PuppyRaffle::entrants` array so big, that no one else enters, guaranteeing themselves the win.

**Proof Of Concept**

If we have 2 sets of 100 players enter, the gas costs will be as such:
- 1st 100 players: ~625048 gas
- 2nd 100 players: ~18068193gas

This is more than 3x expensive for the second 100 players.

<details>
<summary>PoC</summary>
Place the following test into `PuppyRaffleTest.t.sol`

```javascript
// Confirms DoS bug in EnterRaffle() function
    function testDoSAttackOnEnterRaffle() public{
        uint256 numberOfPlayers=2000;
        address[] memory players= new address[](numberOfPlayers);
        for(uint160 i=0;i<numberOfPlayers;i++){
            players[i]=address(i);
        }
        vm.deal(address(10),1e30);
        console.log(address(address(10)).balance);
        vm.prank(address(10));
        vm.expectRevert();
        puppyRaffle.enterRaffle{value:numberOfPlayers*entranceFee}(players);
    }
```

</details>

**Recommended Mitigation** There are a few recommendations.

1. Consider allowing duplicates. Users can make new wallet addresses anyways, so a duplicate check doesn't prevent the same person from entering multiple times, only the same wallet address.
2. Consider using a mapping to check for duplicates. This would allow a constant time lookup to whether a user has already entered.