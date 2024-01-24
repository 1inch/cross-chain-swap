# Timelocks
[Git Source](https://github.com/1inch/cross-chain-swap/blob/4a7a924cfc3cdc40ce87e400e418d193236c06fb/contracts/libraries/TimelocksLib.sol)

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

