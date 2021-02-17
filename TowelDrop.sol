// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface Callable {
	function tokenCallback(address _from, uint256 _tokens, bytes calldata _data) external returns (bool);
}

interface Token {
	function balanceOf(address) external view returns (uint256);
	function allowance(address, address) external view returns (uint256);
	function transfer(address, uint256) external returns (bool);
	function transferFrom(address, address, uint256) external returns (bool);
	function approve(address, uint256) external returns (bool);
}

abstract contract SURF is Token {
	function surfPoolAddress() virtual external view returns (address);
	function whirlpoolAddress() virtual external view returns (address);
}

interface Router {
	function WETH() external view returns (address);
	function factory() external pure returns (address);
	function removeLiquidityETHSupportingFeeOnTransferTokens(address, uint256, uint256, uint256, address, uint256) external returns (uint256);
	function addLiquidity(address, address, uint256, uint256, uint256, uint256, address, uint256) external returns (uint256, uint256, uint256);
	function addLiquidityETH(address, uint256, uint256, uint256, address, uint256) external payable returns (uint256, uint256, uint256);
	function swapExactETHForTokens(uint256, address[] calldata, address, uint256) external payable returns (uint256[] memory);
}

interface Factory {
	function getPair(address, address) external view returns (address);
}

interface Pair {
	function token0() external view returns (address);
	function totalSupply() external view returns (uint256);
	function balanceOf(address) external view returns (uint256);
	function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

/**
 * @dev These functions deal with verification of Merkle trees (hash trees),
 */
library MerkleProof {
	/**
	 * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
	 * defined by `root`. For this, a `proof` must be provided, containing
	 * sibling hashes on the branch from the leaf to the root of the tree. Each
	 * pair of leaves and each pair of pre-images are assumed to be sorted.
	 */
	function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
		bytes32 computedHash = leaf;

		for (uint256 i = 0; i < proof.length; i++) {
			bytes32 proofElement = proof[i];

			if (computedHash <= proofElement) {
				// Hash(current computed hash + current element of the proof)
				computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
			} else {
				// Hash(current element of the proof + current computed hash)
				computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
			}
		}

		// Check if the computed hash (root) is equal to the provided root
		return computedHash == root;
	}
}

// Allows anyone to claim a token if they exist in a merkle root.
interface IMerkleDistributor {
	// Returns the address of the token distributed by this contract.
	function token() external view returns (address);
	// Returns the merkle root of the merkle tree containing account balances available to claim.
	function merkleRoot() external view returns (bytes32);
	// Returns true if the index has been marked claimed.
	function isClaimed(uint256 index) external view returns (bool);
	// Claim the given amount of the token to the given address. Reverts if the inputs are invalid.
	function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external;

	// This event is triggered whenever a call to #claim succeeds.
	event Claimed(uint256 index, address account, uint256 amount);
}

contract MerkleDistributor is IMerkleDistributor {
	address public immutable override token;
	bytes32 public immutable override merkleRoot;
	TheBeach private theBeach;

	// This is a packed array of booleans.
	mapping(uint256 => uint256) private claimedBitMap;

	constructor(address token_, bytes32 merkleRoot_, TheBeach _theBeach) public {
		token = token_;
		merkleRoot = merkleRoot_;
		theBeach = _theBeach;
	}

	function isClaimed(uint256 index) public view override returns (bool) {
		uint256 claimedWordIndex = index / 256;
		uint256 claimedBitIndex = index % 256;
		uint256 claimedWord = claimedBitMap[claimedWordIndex];
		uint256 mask = (1 << claimedBitIndex);
		return claimedWord & mask == mask;
	}

	function _setClaimed(uint256 index) private {
		uint256 claimedWordIndex = index / 256;
		uint256 claimedBitIndex = index % 256;
		claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
	}

	function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external override {
		require(!isClaimed(index), 'MerkleDistributor: Drop already claimed.');

		// Verify the merkle proof.
		bytes32 node = keccak256(abi.encodePacked(index, account, amount));
		require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');

		// Mark it claimed and send the token.
		_setClaimed(index);
		theBeach.stakeFor(account, amount);

		emit Claimed(index, account, amount);
	}

	function claimFor(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external {
		require(!isClaimed(index), 'MerkleDistributor: Drop already claimed.');

		// Verify the merkle proof.
		bytes32 node = keccak256(abi.encodePacked(index, msg.sender, amount));
		require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');

		// Mark it claimed and send the token.
		_setClaimed(index);
		theBeach.stakeFor(account, amount);

		emit Claimed(index, msg.sender, amount);
	}
}


contract TheBeach {
	
	uint256 constant private FLOAT_SCALAR = 2**64;
	uint256 constant private INITIAL_UNSTAKE_PRICE = 0.1 ether;
	uint256 constant private UNSTAKE_PRICE_DURATION = 500 days;


	struct User {
		uint256 staked;
		int256 scaledPayout;
	}

	struct Info {
		uint256 startTime;
		address owner;
		uint256 totalStaked;
		mapping(address => User) users;
		uint256 scaledSurfPerStake;
		SURF surf;
		Towel towel;
		address surfForwarder;
	}
	Info private info;


	event Stake(address indexed user, uint256 amount);
	event Unstake(address indexed user, uint256 amount);
	event Withdraw(address indexed user, uint256 amount);
	event SurfDispersed(uint256 amount);


	constructor(SURF _surf) public {
		info.startTime = block.timestamp;
		info.surf = _surf;
		info.towel = Towel(msg.sender);
		info.surfForwarder = _surf.whirlpoolAddress();
	}

	receive() external payable {}

	function updateSurfForwarder(address _newForwarder) external {
		require(msg.sender == address(info.towel));
		info.surfForwarder = _newForwarder;
	}

	function disperseSurf(uint256 _amount) external {
		uint256 _balanceBefore = info.surf.balanceOf(address(this));
		info.surf.transferFrom(msg.sender, address(this), _amount);
		uint256 _amountReceived = info.surf.balanceOf(address(this)) - _balanceBefore;
		_disperse(_amountReceived);
	}

	function disperseETH() public {
		address _this = address(this);
		uint256 _balance = _this.balance;
		if (_balance > 0) {
			Router _router = Router(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
			address[] memory _poolPath = new address[](2);
			_poolPath[0] = _router.WETH();
			_poolPath[1] = address(info.surf);
			uint256 _balanceBefore = info.surf.balanceOf(_this);
			_router.swapExactETHForTokens{value: _this.balance}(0, _poolPath, _this, block.timestamp + 5 minutes);
			uint256 _amountReceived = info.surf.balanceOf(_this) - _balanceBefore;
			uint256 _amountToForward = _amountReceived * 618 / 1000; // 61.8%
			info.surf.transfer(info.surfForwarder, _amountToForward);
			_disperse(_amountReceived - _amountToForward);
		}
	}

	function tokenCallback(address _from, uint256 _tokens, bytes calldata) external returns (bool) {
		if (msg.sender == address(info.surf)) {
			_disperse(_tokens);
		} else {
			require(msg.sender == address(info.towel));
			require(_tokens > 0 && _tokens % 1e18 == 0);
			_stake(_from, _tokens);
		}
		return true;
	}

	function stake(uint256 _amount) external {
		stakeFor(msg.sender, _amount);
	}

	function stakeFor(address _user, uint256 _amount) public {
		require(_amount > 0 && _amount % 1e18 == 0);
		info.towel.transferFrom(msg.sender, address(this), _amount);
		_stake(_user, _amount);
	}

	function stakeAfterMint(address _user, uint256 _amount) external {
		require(msg.sender == address(info.towel));
		require(_amount > 0 && _amount % 1e18 == 0);
		_stake(_user, _amount);
	}

	function unstakeAll() external payable {
		unstake(stakeOf(msg.sender));
	}

	function unstake(uint256 _amount) public payable {
		require(_amount <= stakeOf(msg.sender));
		require(_amount > 0 && _amount % 1e18 == 0);
		uint256 _cost = unstakeCost();
		require(msg.value >= _cost);
		info.totalStaked -= _amount;
		info.users[msg.sender].staked -= _amount;
		info.users[msg.sender].scaledPayout -= int256(_amount * info.scaledSurfPerStake);
		info.towel.transfer(msg.sender, _amount);
		emit Unstake(msg.sender, _amount);
		if (msg.value > _cost) {
			msg.sender.transfer(msg.value - _cost);
		}
	}

	function withdraw() external {
		withdrawTo(msg.sender);
	}

	function withdrawTo(address _user) public {
		uint256 _dividends = dividendsOf(msg.sender);
		require(_dividends > 0);
		info.users[msg.sender].scaledPayout += int256(_dividends * FLOAT_SCALAR);
		info.surf.transfer(_user, _dividends);
		emit Withdraw(msg.sender, _dividends);
	}


	function totalStaked() public view returns (uint256) {
		return info.totalStaked;
	}

	function stakeOf(address _user) public view returns (uint256) {
		return info.users[_user].staked;
	}

	function dividendsOf(address _user) public view returns (uint256) {
		return uint256(int256(info.scaledSurfPerStake * stakeOf(_user)) - info.users[_user].scaledPayout) / FLOAT_SCALAR;
	}

	function unstakeCost() public view returns (uint256) {
		uint256 _diff = block.timestamp - info.startTime;
		if (_diff < UNSTAKE_PRICE_DURATION) {
			return INITIAL_UNSTAKE_PRICE - INITIAL_UNSTAKE_PRICE * _diff / UNSTAKE_PRICE_DURATION;
		} else {
			return 0;
		}
	}

	function allInfoFor(address _user) external view returns (uint256 totalTowelsStaked, uint256 costToUnstake, uint256 pendingPayout, uint256 userTowels, uint256 userStaked, uint256 userDividends) {
		totalTowelsStaked = totalStaked();
		costToUnstake = unstakeCost();
		pendingPayout = info.surf.balanceOf(address(this));
		userTowels = info.towel.balanceOf(_user);
		userStaked = stakeOf(_user);
		userDividends = dividendsOf(_user);
	}


	function _stake(address _user, uint256 _amount) internal {
		info.totalStaked += _amount;
		info.users[_user].staked += _amount;
		info.users[_user].scaledPayout += int256(_amount * info.scaledSurfPerStake);
		emit Stake(_user, _amount);
	}

	function _disperse(uint256 _amount) internal {
		info.scaledSurfPerStake += _amount * FLOAT_SCALAR / totalStaked();
		emit SurfDispersed(_amount);
	}
}


contract Towel {

	uint256 constant private UINT_MAX = uint256(-1);
	uint256 constant private INITIAL_SUPPLY = 1e22; // 10,000 TOWEL
	uint256 constant private POOL_SEED = 1e20; // 100 TOWEL
	uint256 constant private SUSHI_DISTRIBUTOR_SEED = 4415e18; // 4,415 TOWEL
	uint256 constant private SURF_DISTRIBUTOR_SEED = 1765e18; // 1,765 TOWEL
	uint256 constant private MINT_TOWEL_COST = 1e17; // 0.1 ETH
	uint256 constant private MINT_AND_LOCK_DURATION = 500 days;

	string constant public name = "SURF.Finance Towel";
	string constant public symbol = "TOWEL";
	uint8 constant public decimals = 18;

	struct User {
		uint256 balance;
		uint256[] mintLocks;
		mapping(address => uint256) allowance;
	}

	struct MintLock {
		uint256 surf;
		uint256 towels;
		uint256 endTime;
		address staker;
		bool unlocked;
	}

	struct Info {
		address owner;
		uint256 startTime;
		uint256 totalSupply;
		uint256 currentMintLock;
		mapping(address => User) users;
		mapping(uint256 => MintLock) mintLocks;
		Router router;
		Router priceRouter;
		SURF surf;
		TheBeach theBeach;
		address sushiDistributor;
		address surfDistributor;
	}
	Info private info;

	event Transfer(address indexed from, address indexed to, uint256 tokens);
	event Approval(address indexed owner, address indexed spender, uint256 tokens);
	event Mint(address indexed minter, address indexed staker, uint256 tokens, uint256 surfLocked);
	event SurfUnlocked(address indexed user, uint256 tokens);


	constructor(SURF _surf, bytes32 _sushiMerkleRoot, bytes32 _surfMerkleRoot) public {
		info.router = Router(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
		info.priceRouter = Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
		info.startTime = block.timestamp;
		info.owner = msg.sender;
		info.surf = _surf;
		info.theBeach = new TheBeach(_surf);
		info.sushiDistributor = address(new MerkleDistributor(address(this), _sushiMerkleRoot, info.theBeach));
		info.users[info.sushiDistributor].allowance[address(info.theBeach)] = UINT_MAX;
		info.surfDistributor = address(new MerkleDistributor(address(this), _surfMerkleRoot, info.theBeach));
		info.users[info.surfDistributor].allowance[address(info.theBeach)] = UINT_MAX;
	}

	receive() external payable {
		require(totalSupply() == 0);
	}

	function setOwner(address _newOwner) external {
		require(msg.sender == info.owner);
		info.owner = _newOwner;
	}

	function updateSurfForwarder(address _newForwarder) external {
		require(msg.sender == info.owner);
		info.theBeach.updateSurfForwarder(_newForwarder);
	}

	function upgradePriceRouter() external {
		require(msg.sender == info.owner);
		require(info.priceRouter != info.router);
		require(totalSupply() > 0);
		info.priceRouter = info.router;
	}

	function transferContractToken(address _token, address _to, uint256 _amount) external {
		require(msg.sender == info.owner);
		if (_token == address(this)) {
			_transfer(address(this), _to, _amount);
		} else {
			require(_token != address(info.surf));
			Token(_token).transfer(_to, _amount);
		}
	}

	function initialize(uint256 _lpSeedAmount) external {
		require(msg.sender == info.owner);
		require(totalSupply() == 0);
		require(_lpSeedAmount > 0);
		address _this = address(this);
		require(Token(info.surf.surfPoolAddress()).transferFrom(msg.sender, _this, _lpSeedAmount));
		Token(info.surf.surfPoolAddress()).approve(address(info.priceRouter), _lpSeedAmount);
		info.priceRouter.removeLiquidityETHSupportingFeeOnTransferTokens(address(info.surf), _lpSeedAmount, 0, 0, _this, block.timestamp + 5 minutes);
		info.totalSupply = INITIAL_SUPPLY;
		info.users[_this].balance = INITIAL_SUPPLY;
		emit Transfer(address(0x0), _this, INITIAL_SUPPLY);
		info.users[_this].allowance[address(info.router)] = 2 * POOL_SEED;
		info.router.addLiquidityETH{value: _this.balance}(_this, POOL_SEED, 0, 0, _this, block.timestamp + 5 minutes);
		info.surf.approve(address(info.router), info.surf.balanceOf(_this));
		info.router.addLiquidity(_this, address(info.surf), POOL_SEED, info.surf.balanceOf(_this), 0, 0, _this, block.timestamp + 5 minutes);
		_transfer(_this, info.sushiDistributor, SUSHI_DISTRIBUTOR_SEED);
		_transfer(_this, info.surfDistributor, SURF_DISTRIBUTOR_SEED);
	}

	function mint() external payable {
		mintFor(msg.sender);
	}

	function mintFor(address _user) public payable {
		require(totalSupply() > 0);
		uint256 _towels = msg.value / MINT_TOWEL_COST;
		require(_towels > 0);
		uint256 _cost = MINT_TOWEL_COST * _towels;
		address[] memory _poolPath = new address[](2);
		_poolPath[0] = info.router.WETH();
		_poolPath[1] = address(info.surf);
		uint256 _balanceBefore = info.surf.balanceOf(address(this));
		info.router.swapExactETHForTokens{value: _cost}(0, _poolPath, address(this), block.timestamp + 5 minutes);
		uint256 _amountReceived = info.surf.balanceOf(address(this)) - _balanceBefore;
		_mint(_user, _towels, _amountReceived);
		if (msg.value > _cost) {
			msg.sender.transfer(msg.value - _cost);
		}
	}

	function mintWithSurf(uint256 _towels) external {
		mintWithSurfFor(msg.sender, _towels);
	}

	function mintWithSurfFor(address _user, uint256 _towels) public {
		require(msg.sender == tx.origin);
		require(totalSupply() > 0);
		require(_towels > 0);
		Pair _pair = Pair(Factory(info.priceRouter.factory()).getPair(info.priceRouter.WETH(), address(info.surf)));
		(uint256 _res0, uint256 _res1, ) = _pair.getReserves();
		bool _weth0 = _pair.token0() == info.priceRouter.WETH();
		uint256 _price = 1e18 * (_weth0 ? _res0 : _res1) / (_weth0 ? _res1 : _res0);
		uint256 _balanceBefore = info.surf.balanceOf(address(this));
		info.surf.transferFrom(msg.sender, address(this), 1e18 * MINT_TOWEL_COST * _towels / _price);
		uint256 _amountReceived = info.surf.balanceOf(address(this)) - _balanceBefore;
		_mint(_user, _towels, _amountReceived);
	}

	function unlockSurf() external {
		uint256[] memory _userMintLocks = info.users[msg.sender].mintLocks;
		uint256 _length = _userMintLocks.length;
		uint256 _unlockableSurf = 0;
		for (uint256 _userMintLock = 0; _userMintLock < _length; _userMintLock++) {
			uint256 _mintLock = _userMintLocks[_userMintLock];
			if (info.mintLocks[_mintLock].endTime <= block.timestamp && !info.mintLocks[_mintLock].unlocked) {
				_unlockableSurf += info.mintLocks[_mintLock].surf;
				info.mintLocks[_mintLock].unlocked = true;
			}
		}
		require(_unlockableSurf > 0);
		info.surf.transfer(msg.sender, _unlockableSurf);
		emit SurfUnlocked(msg.sender, _unlockableSurf);
	}

	function transfer(address _to, uint256 _tokens) external returns (bool) {
		return _transfer(msg.sender, _to, _tokens);
	}

	function approve(address _spender, uint256 _tokens) external returns (bool) {
		info.users[msg.sender].allowance[_spender] = _tokens;
		emit Approval(msg.sender, _spender, _tokens);
		return true;
	}

	function transferFrom(address _from, address _to, uint256 _tokens) external returns (bool) {
		uint256 _allowance = allowance(_from, msg.sender);
		require(_allowance >= _tokens);
		if (_allowance != UINT_MAX) {
			info.users[_from].allowance[msg.sender] -= _tokens;
		}
		return _transfer(_from, _to, _tokens);
	}

	function transferAndCall(address _to, uint256 _tokens, bytes calldata _data) external returns (bool) {
		_transfer(msg.sender, _to, _tokens);
		uint32 _size;
		assembly {
			_size := extcodesize(_to)
		}
		if (_size > 0) {
			require(Callable(_to).tokenCallback(msg.sender, _tokens, _data));
		}
		return true;
	}
	

	function owner() external view returns (address) {
		return info.owner;
	}

	function theBeachAddress() external view returns (address) {
		return address(info.theBeach);
	}

	function sushiDistributorAddress() external view returns (address) {
		return address(info.sushiDistributor);
	}

	function surfDistributorAddress() external view returns (address) {
		return address(info.surfDistributor);
	}
	
	function totalSupply() public view returns (uint256) {
		return info.totalSupply;
	}

	function balanceOf(address _user) public view returns (uint256) {
		return info.users[_user].balance;
	}

	function lockedOf(address _user) public view returns (uint256 lockedSurf) {
		uint256[] memory _userMintLocks = info.users[_user].mintLocks;
		uint256 _length = _userMintLocks.length;
		for (uint256 _userMintLock = 0; _userMintLock < _length; _userMintLock++) {
			uint256 _mintLock = _userMintLocks[_userMintLock];
			if (!info.mintLocks[_mintLock].unlocked) {
				lockedSurf += info.mintLocks[_mintLock].surf;
			}
		}
	}

	function unlockableOf(address _user) public view returns (uint256 unlockableSurf) {
		uint256[] memory _userMintLocks = info.users[_user].mintLocks;
		uint256 _length = _userMintLocks.length;
		unlockableSurf = 0;
		for (uint256 _userMintLock = 0; _userMintLock < _length; _userMintLock++) {
			uint256 _mintLock = _userMintLocks[_userMintLock];
			if (info.mintLocks[_mintLock].endTime <= block.timestamp && !info.mintLocks[_mintLock].unlocked) {
				unlockableSurf += info.mintLocks[_mintLock].surf;
			}
		}
	}

	function allowance(address _user, address _spender) public view returns (uint256) {
		return info.users[_user].allowance[_spender];
	}

	function allInfoFor(address _user) external view returns (uint256 totalTokens, uint256 totalLocked, uint256 userSurf, uint256 userApproved, uint256 userBalance, uint256 userLocked, uint256 userUnlockable) {
		totalTokens = totalSupply();
		totalLocked = info.surf.balanceOf(address(this));
		userSurf = info.surf.balanceOf(_user);
		userApproved = info.surf.allowance(_user, address(this));
		userBalance = balanceOf(_user);
		userLocked = lockedOf(_user);
		userUnlockable = unlockableOf(_user);
	}

	function _transfer(address _from, address _to, uint256 _tokens) internal returns (bool) {
		require(balanceOf(_from) >= _tokens);
		info.users[_from].balance -= _tokens;
		info.users[_to].balance += _tokens;
		emit Transfer(_from, _to, _tokens);
		return true;
	}

	function _mint(address _user, uint256 _towels, uint256 _lockedSurf) internal {
		uint256 _amount = 1e18 * _towels;
		info.mintLocks[info.currentMintLock] = MintLock({
			surf: _lockedSurf,
			towels: _towels,
			staker: _user,
			endTime: block.timestamp + MINT_AND_LOCK_DURATION,
			unlocked: false
		});
		info.users[_user].mintLocks.push(info.currentMintLock);
		info.currentMintLock++;
		info.totalSupply += _amount;
		info.users[address(info.theBeach)].balance += _amount;
		info.theBeach.stakeAfterMint(_user, _amount);	
		emit Transfer(address(0x0), address(info.theBeach), _amount);
		emit Mint(msg.sender, _user, _amount, _lockedSurf);
	}
}
