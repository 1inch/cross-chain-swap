# Timelocks
[Git Source](https://github.com/1inch/cross-chain-swap/blob/a0032266a4f4e0c7ae999b45292f7c9116abe373/contracts/libraries/TimelocksLib.sol)

*Timelocks for the source and the destination chains.
For illustrative purposes, it is possible to describe timelocks by two structures:
struct SrcTimelocks {
uint256 finality;
uint256 withdrawal;
uint256 cancel;
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
cancel: The duration of the period when escrow can only be cancelled by the taker.*


```solidity
type Timelocks is uint256;
```

