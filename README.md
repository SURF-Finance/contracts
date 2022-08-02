# SURF.Finance Contracts

The SURF 2.0 update brings all functionality in the ecosystem back to Ethereum mainnet and introduces an innovative NFT-based governance system. More details can be found in this article https://surf-finance.medium.com/surf-finance-2-0-d21d2302574e

## Ethereum Contracts

### Active Contracts:
**SURF**: 0xEa319e87Cf06203DAe107Dd8E5672175e3Ee976c
- Contract for the SURF token (ERC-20) which is also used as a burn address. The token has an adjustable transfer fee which is currently set to 0.2%. The transfer fee is rewarded to Whirlpool stakers.

**Whirlpool**: 0x999b1e6EDCb412b59ECF0C5e14c20948Ce81F40b
- Contract that rewards SURF/ETH Uniswap LP token stakers with passive SURF dividends from various sources

**WhirlpoolDistributor**: 0x41e4a79eC6C7674d74aF19852736f6DC0bC74bA2
- Used to distribute a consistent amount of SURF per day to the Whirlpool

**SURF_BOARD**: 0xf90AeeF57Ae8Bc85FE8d40a3f4a45042F4258c67
- Contract for the SURF BOARD ERC-721 NFTs

**BoardDividends**: 0xc456c79213D0d39Fbb2bec1d8Ec356c6d3970A2f
- Used to distribute SURF rewards to SURF BOARD holders (will be replaced by the Beach staking contract)

**SurfShop**: 0x8dfb67c3e7710ACbb77AdA9Ab2876C56926E781F
- ERC-1155 NFT contract that houses the TOWEL (ID=1) and upgraded SURF BOARD (ID=2) NFTs

**Beach**: {Not deployed yet}
- Staking contract that allows users to stake their TOWEL and SURF BOARD NFTs to participate in SURF's governance system and earn SURF dividends

**TowelMinter**: {Not deployed yet}
- Allows users to exchange SURF for TOWEL NFTs and distributes the received SURF between the Whirlpool contract, the Beach contract, and the burn address (SURF token contract)

### Important 3rd-party Contracts:
**SURF Treasury (Gnosis Safe)**: 0xe7F5aA18eFA7317705ff3dD8f459Ad0792E36Aa3
- The majority of the assets currently held in the SURF deployer wallet will end up here to be controlled through SURF's governance system

**ETH/SURF LP Token (Uniswap v2 pair)**: 0x32d588fd4d0993378995306563A04aF5Fa162deC
- This is SURF's primary liquidity pool and the best pair to buy or sell the token through

### Legacy Contracts:
**Tito**: 0x65E5BC985b8399B338C3C55ff1e3c048586d50ca
- A complete rewrite of Sushi's MasterChef contract that was the first to utilize fixed APY pools. Used to generate our initial SURF/ETH liquidity on Uniswap and fairly distribute the entire supply of 10 million SURF

**AutoDeposit**: 0x7847426B80b2565D14720b9ed0243840250C15aa
- Deployed to allow people to use only ETH to enter a Tito pool by automatically creating and staking LP tokens for the desired pool

**TheEvent**: 0x835f2bbc1BE21D8E11611DA4a456208De20EDE3A
- Used for a one-time buyback of over $2 million worth of SURF which got distributed to Whirlpool stakers

**SURFstacker**: 0xCD0b9Ca1ae505B489A8C8523CAaf3e6338A65a83
- Unique staking contract that distributed SURF throughout the ecosystem

**SURF3d**: 0xeb620A32Ea11FcAa1B3D70E4CFf6500B85049C97
- Hourglass contract deployed shortly after SURF's launch with ~500k SURF permanently locked in it

**WhirlpoolManager**: 0x6E6D30D1Fd3c49278F93d4D29681f628d88b050b
- Used to advance the SURFstacker line and reward Whirlpool stakers and SURF Board holders with additional SURF. Owns nearly all of the remaining S3D which can never be sold.


## Polygon Contracts
All deployed Polygon contracts are now deprecated and serve no function in the SURF 2.0 ecosystem

**SURF Token**: 0x1E42EDbe5376e717C1B22904C59e406426E8173F
- Bridged SURF token from Ethereum (it is recommended to bridge all of your SURF back to Ethereum at your convenience)

**polyWAVE**: 0x8896B0E97D0BA384029FA0bDd8e35df6AC20803D
- Unique yield-farm that distributed the WAVE token

**WAVE**: 0x4DE7FEA447b837d7E77848a4B6C0662a64A84E14
- Token distributed through polyWAVE (holders will be airdropped SURF and TOWELs on mainnet)

**Towel**: 0x1E946cA17b893Ab0f22cF1951137624eE9E689EF
- Contract for the unique SURF-yielding Polygon TOWEL token (ERC-20) that was initially distributed through a free claim for SURF ecosystem participants (holders will be airdropped new TOWELs on mainnet)

**TheBeach**: 0x817C521f9616204c24f05B2102E82f606Cd9A806
- Innovative staking and token distribution contract used for the Polygon TOWEL token

## Launch Audits
**AegisDAO**
- https://github.com/AegisDAO/audits/blob/main/SURF.md

**Sherlock Security**
- https://github.com/SURF-Finance/contracts/raw/master/Sherlock_Security_-_Surf_Finance_Audit_Report.pdf

**DeFiYield.info**
- https://defiyield.info/assets/pdf/Surf.finance.pdf