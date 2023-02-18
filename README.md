# Contracts

The Surf.Finance 2.0 update brings all functionality in the ecosystem back to Ethereum mainnet and introduces an innovative NFT-based governance system. More details can be found in this article [https://surf-finance.medium.com/surf-finance-2-0-d21d2302574e](https://surf-finance.medium.com/surf-finance-2-0-d21d2302574e)

## Ethereum Contracts

### Active Contracts:

**SURF**: 0xEa319e87Cf06203DAe107Dd8E5672175e3Ee976c

- Contract for the SURF token (ERC-20) which is also used as a burn address for the token. The token has an adjustable transfer fee which is currently set to 1%. The entire transfer fee is currently sent to the Whirlpool contract, but will be sent to the Swell contract once the Surf.Finance 2.0 update is live.

**Whirlpool**: 0x999b1e6EDCb412b59ECF0C5e14c20948Ce81F40b

- Contract that rewards SURF/ETH Uniswap LP token stakers with passive SURF dividends from various sources. This will be replaced by the WhirlpoolV2 before the Surf.Finance 2.0 update is live and all Whirlpool stakers will need to migrate their staked LP tokens to continue earning SURF rewards.

**SURF_BOARD**: 0xf90AeeF57Ae8Bc85FE8d40a3f4a45042F4258c67

- Contract for the SURF BOARD ERC-721 NFTs

**BoardDividends**: 0xc456c79213D0d39Fbb2bec1d8Ec356c6d3970A2f

- Used to distribute SURF rewards to SURF BOARD holders (will be replaced by the Beach staking contract)

**SurfShop**: 0x8dfb67c3e7710ACbb77AdA9Ab2876C56926E781F

- ERC-1155 NFT contract that houses the Towel (ID=1) and upgraded Surfboard (ID=2) NFTs

### Surf.Finance 2.0 Contracts:

**Beach**: {Not deployed yet}

- The Beach staking contract allows users to stake their Surfboard and Towel NFTs to participate in the governance system and earn passive SURF dividends

**ContributorRewards**: {Not deployed yet}

- The ContributorRewards contract is an overhauled PaymentSplitter contract that allows Surf.Finance's governance system to reward SURF to the top contributors

**Swell**: {Not deployed yet}

- The Swell contract is a governance controlled SURF faucet that receives and distributes the revenue in the Surf.Finance ecosystem. SURF received from the transfer fee (and other sources like the TowelMinter) is distributed between the Whirlpool contract, the Beach contract, the ContributorRewards contract, and the burn address (SURF token contract)

**TowelMinter**: {Not deployed yet}

- The TowelMinter contract allows users to exchange SURF for Towel NFTs and sends the SURF to the Swell to be distributed throughout the ecosystem

**WhirlpoolV2**: {Not deployed yet}

- The WhirlpoolV2 contract provides a safe and simple migration path to future versions of the Whirlpool and allows any account to call `addSurfReward` (a requirement for the Swell to work)

### Important 3rd-party Contracts:

**Surf Treasury (Safe)**: 0xe7F5aA18eFA7317705ff3dD8f459Ad0792E36Aa3

- The majority of the assets currently held in the SURF deployer wallet will end up here to be controlled through Surf.Finance's governance system

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

**WhirlpoolDistributor**: 0x41e4a79eC6C7674d74aF19852736f6DC0bC74bA2

- Used to distribute a consistent amount of SURF per day to the Whirlpool

**WhirlpoolManager**: 0x6E6D30D1Fd3c49278F93d4D29681f628d88b050b

- Used to advance the SURFstacker line and reward Whirlpool stakers and SURF BOARD holders with additional SURF. Owns nearly all of the remaining S3D which can never be sold.

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

- [https://github.com/AegisDAO/audits/blob/main/SURF.md](https://github.com/AegisDAO/audits/blob/main/SURF.md)

**Sherlock Security**

- [https://github.com/SURF-Finance/contracts/raw/master/Sherlock_Security_-_Surf_Finance_Audit_Report.pdf](https://github.com/SURF-Finance/contracts/raw/master/Sherlock_Security_-_Surf_Finance_Audit_Report.pdf)

**DeFiYield.info**

- [https://defiyield.info/assets/pdf/Surf.finance.pdf](https://defiyield.info/assets/pdf/Surf.finance.pdf)
