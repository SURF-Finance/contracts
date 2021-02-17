
pragma solidity ^0.6.12;

interface Router {
	function WETH() external pure returns (address);
	function swapExactETHForTokens(uint256 _amountOutMin, address[] calldata _path, address _to, uint256 _deadline) external payable returns (uint256[] memory);
}

interface SURF {
	function whirlpoolAddress() external view returns (address);
	function balanceOf(address) external view returns (uint256);
	function transfer(address, uint256) external returns (bool);
	function transferFrom(address, address, uint256) external returns (bool);
	function transferAndCall(address, uint256, bytes calldata) external returns (bool);
}

interface SURF3d {
	function whirlpoolManager() external view returns (address);
	function balanceOf(address) external view returns (uint256);
	function dividendsOf(address) external view returns (uint256);
	function transfer(address, uint256) external returns (bool);
	function withdraw() external returns (uint256);
}

interface Whirlpool {
	function userInfo(address) external view returns (uint256, uint256, uint256);
	function claim() external;
}

contract SURFstackerPLUS {

	uint256 constant private FLOAT_SCALAR = 2**64;
	uint256 constant private MIN_DEPOSIT = 1e20; // 100 SURF min
	uint256 constant private MAX_DEPOSIT = 1e22; // 10,000 SURF max
	uint256 constant private RETURN = 125; // deposit + 25% extra repaid
	uint256 constant private S3D_BUY = 10; // 10% of deposits buy S3D
	uint256 constant private S3D_TO_WM = 25; // 25% of each S3D buy goes to the whirlpool manager
	uint256 constant private DIVIDENDS = 10; // 10% of deposits are spread as dividends
	uint256 constant private DIVIDENDS_TO_QUEUE = 50; // 50% of external dividends claimed pay off the queue

	struct Deposit {
		address user;
		uint96 timestamp;
		uint128 deposited;
		uint128 paid;
	}

	struct User {
		uint256 deposited;
		int256 scaledPayout;
	}

	struct Info {
		Deposit[] queue;
		uint256 paidToIndex;
		uint256 totalDeposited;
		mapping(address => User) users;
		uint256 scaledSurfPerShare;
		uint256 openingBlock;
		Router router;
		SURF surf;
		SURF3d s3d;
		Whirlpool whirlpool;
	}
	Info private info;
	

	event Deposited(uint256 indexed index, address indexed user, uint256 amount);
	event Paid(uint256 indexed index, address indexed user, uint256 amount);
	event PaidOff(uint256 indexed index, address indexed user, uint256 totalPaid);
	event Withdraw(address indexed user, uint256 amount);
	event Dispersed(uint256 amount);


	constructor(address _surf, address _s3d, uint256 _openingBlock) public {
		info.router = Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
		info.surf = SURF(_surf);
		info.s3d = SURF3d(_s3d);
		info.whirlpool = Whirlpool(info.surf.whirlpoolAddress());
		info.openingBlock = _openingBlock;
	}

	receive() external payable {
		if (msg.sender == tx.origin) {
			deposit();
		}
	}

	function deposit() public payable {
		depositFor(msg.sender);
	}

	function depositFor(address _user) public payable {
		require(msg.value > 0);
		_depositETH(msg.value, _user);
	}

	function buy(uint256 _amount) external {
		buyFor(_amount, msg.sender);
	}

	function buyFor(uint256 _amount, address _user) public {
		uint256 _balanceBefore = info.surf.balanceOf(address(this));
		info.surf.transferFrom(msg.sender, address(this), _amount);
		uint256 _amountReceived = info.surf.balanceOf(address(this)) - _balanceBefore;
		_deposit(_amountReceived, _user);
	}

	function tokenCallback(address _from, uint256 _tokens, bytes calldata) external returns (bool) {
		require(msg.sender == address(info.surf));
		_deposit(_tokens, _from);
		return true;
	}

	function withdraw() external {
		uint256 _dividends = dividendsOf(msg.sender);
		require(_dividends > 0);
		info.users[msg.sender].scaledPayout += int256(_dividends * FLOAT_SCALAR);
		info.surf.transfer(msg.sender, _dividends);
		emit Withdraw(msg.sender, _dividends);
	}

	function processDividends() external {
		uint256 _balanceBefore = info.surf.balanceOf(address(this));
		if (info.s3d.dividendsOf(address(this)) > 0) {
			info.s3d.withdraw();
		}
		(uint256 _staked, , ) = info.whirlpool.userInfo(address(this));
		if (_staked > 0) {
			info.whirlpool.claim();
		}
		uint256 _amountReceived = info.surf.balanceOf(address(this)) - _balanceBefore;
		if (_amountReceived > 0) {
			uint256 _amountToProcess = DIVIDENDS_TO_QUEUE * _amountReceived / 100;
			_process(_amountToProcess);
			_disperse(_amountReceived - _amountToProcess);
		}
	}


	function dividendsOf(address _user) public view returns (uint256) {
		return uint256(int256(info.scaledSurfPerShare * info.users[_user].deposited) - info.users[_user].scaledPayout) / FLOAT_SCALAR;
	}

	function allInfoFor(address _user) external view returns (uint256 totalDeposits, uint256 paidToIndex, uint256 totalDeposited, uint256 openingBlock, uint256 currentBlock, uint256 userETH, uint256 userSURF, uint256 userDeposited, uint256 userDividends) {
		totalDeposits = info.queue.length;
		paidToIndex = info.paidToIndex;
		totalDeposited = info.totalDeposited;
		openingBlock = info.openingBlock;
		currentBlock = block.number;
		userETH = _user.balance;
		userSURF = info.surf.balanceOf(_user);
		userDeposited = info.users[_user].deposited;
		userDividends = dividendsOf(_user);
	}

	function getDeposit(uint256 _index) public view returns (address user, uint256 timestamp, uint256 deposited, uint256 paid, uint256 remaining) {
		require(_index < info.queue.length);
		Deposit memory _dep = info.queue[_index];
		user = _dep.user;
		timestamp = _dep.timestamp;
		deposited = _dep.deposited;
		paid = _dep.paid;
		remaining = RETURN * deposited / 100 - paid;
	}

	function getDeposits(uint256[] memory _indexes) public view returns (address[] memory users, uint256[] memory timestamps, uint256[] memory depositeds, uint256[] memory paids, uint256[] memory remainings) {
		uint256 _length = _indexes.length;
		users = new address[](_length);
		timestamps = new uint256[](_length);
		depositeds = new uint256[](_length);
		paids = new uint256[](_length);
		remainings = new uint256[](_length);
		for (uint256 i = 0; i < _length; i++) {
			(users[i], timestamps[i], depositeds[i], paids[i], remainings[i]) = getDeposit(_indexes[i]);
		}
	}

	function getDepositsTable(uint256 _limit, uint256 _page, bool _isAsc, bool _onlyUnpaid) external view returns (uint256[] memory indexes, address[] memory users, uint256[] memory timestamps, uint256[] memory depositeds, uint256[] memory paids, uint256[] memory remainings, uint256 totalDeposits, uint256 totalPages) {
		require(_limit > 0);
		totalDeposits = info.queue.length - (_onlyUnpaid ? info.paidToIndex : 0);

		if (totalDeposits > 0) {
			totalPages = (totalDeposits / _limit) + (totalDeposits % _limit == 0 ? 0 : 1);
			require(_page < totalPages);

			uint256 _offset = _limit * _page;
			if (_page == totalPages - 1 && totalDeposits % _limit != 0) {
				_limit = totalDeposits % _limit;
			}

			indexes = new uint256[](_limit);
			for (uint256 i = 0; i < _limit; i++) {
				indexes[i] = (_isAsc ? _offset + i : totalDeposits - _offset - i - 1) + (_onlyUnpaid ? info.paidToIndex : 0);
			}
		} else {
			totalPages = 0;
			indexes = new uint256[](0);
		}
		(users, timestamps, depositeds, paids, remainings) = getDeposits(indexes);
	}


	function _depositETH(uint256 _value, address _user) internal {
		uint256 _balanceBefore = info.surf.balanceOf(address(this));
		address[] memory _poolPath = new address[](2);
		_poolPath[0] = info.router.WETH();
		_poolPath[1] = address(info.surf);
		info.router.swapExactETHForTokens{value: _value}(0, _poolPath, address(this), block.timestamp + 5 minutes);
		uint256 _amount = info.surf.balanceOf(address(this)) - _balanceBefore;
		_deposit(_amount, _user);
	}

	function _deposit(uint256 _amount, address _user) internal {
		require(_user != address(0x0));
		require(block.number >= info.openingBlock && _amount >= MIN_DEPOSIT && _amount <= MAX_DEPOSIT);

		Deposit memory _newDeposit = Deposit({
			user: _user,
			timestamp: uint96(block.timestamp),
			deposited: uint128(_amount),
			paid: 0
		});
		info.queue.push(_newDeposit);
		info.totalDeposited += _amount;
		info.users[_user].deposited += _amount;
		info.users[_user].scaledPayout += int256(_amount * info.scaledSurfPerShare);
		emit Deposited(info.queue.length - 1, _user, _amount);

		uint256 _s3dBuyAmount = S3D_BUY * _amount / 100;
		_purchaseS3D(_s3dBuyAmount);

		uint256 _dividendsAmount = DIVIDENDS * _amount / 100;
		_disperse(_dividendsAmount);

		uint256 _amountPayable = _amount - _s3dBuyAmount - _dividendsAmount;
		_process(_amountPayable);
	}

	function _purchaseS3D(uint256 _amount) internal {
		uint256 _balanceBefore = info.s3d.balanceOf(address(this));
		info.surf.transferAndCall(address(info.s3d), _amount, new bytes(0));
		uint256 _s3dReceived = info.s3d.balanceOf(address(this)) - _balanceBefore;
		info.s3d.transfer(info.s3d.whirlpoolManager(), S3D_TO_WM * _s3dReceived / 100);
	}

	function _process(uint256 _amount) internal {
		while (_amount > 0) {
			uint256 _currentIndex = info.paidToIndex;
			if (_currentIndex >= info.queue.length) {
				_purchaseS3D(_amount);
				_amount = 0;
			} else {
				Deposit storage _currentDeposit = info.queue[_currentIndex];
				uint256 _amountPayable = _amount;
				uint256 _totalPayable = RETURN * _currentDeposit.deposited / 100;
				uint256 _amountRemaining = _totalPayable - _currentDeposit.paid;
				if (_amountRemaining <= _amountPayable) {
					_amountPayable = _amountRemaining;
					emit PaidOff(_currentIndex, _currentDeposit.user, _totalPayable);
					info.paidToIndex++;
				}
				_currentDeposit.paid += uint128(_amountPayable);
				info.surf.transfer(_currentDeposit.user, _amountPayable);
				emit Paid(_currentIndex, _currentDeposit.user, _amountPayable);
				_amount -= _amountPayable;
			}
		}
	}

	function _disperse(uint256 _amount) internal {
		info.scaledSurfPerShare += _amount * FLOAT_SCALAR / info.totalDeposited;
		emit Dispersed(_amount);
	}
}