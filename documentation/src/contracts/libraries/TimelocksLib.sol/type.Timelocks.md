# Timelocks
[Git Source](https://github.com/1inch/cross-chain-swap/blob/40ee0298e9d149b252571265df4978f25f912e2a/contracts/libraries/TimelocksLib.sol)

*Timelocks for the source and the destination chains.
For illustrative purposes, it is possible to describe theimlocks by two structures:
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
withdrawal: The duration of the period when only the taker with a secret can withdraw tokens for taker (source chain) or
maker (destination chain).
publicWithdrawal: The duration of the period when anyone with a secret can withdraw tokens for taker (source chain) or
maker (destination chain).
cancel: The duration of the period when escrow can only be cancelled by the taker.*


```solidity
type Timelocks is uint256;
```

