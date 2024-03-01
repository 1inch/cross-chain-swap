# Timelocks
[Git Source](https://github.com/1inch/cross-chain-swap/blob/953335457652894d3aa7caf6353d8c55f2e2a675/contracts/libraries/TimelocksLib.sol)

*Timelocks for the source and the destination chains plus the deployment timestamp.
For illustrative purposes, it is possible to describe timelocks by two structures:
struct SrcTimelocks {
uint256 finality;
uint256 withdrawal;
uint256 cancellation;
}
struct DstTimelocks {
uint256 finality;
uint256 withdrawal;
uint256 publicWithdrawal;
}
finality: The duration of the chain finality period.
withdrawal: The duration of the period when only the taker with a secret can withdraw tokens for taker (source chain)
or maker (destination chain).
publicWithdrawal: The duration of the period when anyone with a secret can withdraw tokens for taker (source chain)
or maker (destination chain).
cancellation: The duration of the period when escrow can only be cancelled by the taker.*


```solidity
type Timelocks is uint256;
```

