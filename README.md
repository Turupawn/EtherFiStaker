![test workflow](https://github.com/Turupawn/EtherFiLenderDemo/actions/workflows/test.yml/badge.svg)

# EtherFi Lender Demo

Smart contract that lends on EtherFi and collects yield. The code can be used as an example to earn passively on presales, auctions, dao treasuries or any contract that holds idle ERC20 tokens.

## Running the test

The testing script lends DAI and EtherFi on Mainnet. Run it the following way:

```bash
forge test --fork-url https://api.stateless.solutions/ethereum/v1/demo -vv
```