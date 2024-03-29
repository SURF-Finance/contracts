
pragma solidity ^0.6.12;

interface SURF {
	function whirlpoolAddress() external view returns (address);
	function balanceOf(address) external view returns (uint256);
	function transfer(address, uint256) external returns (bool);
}

interface Boards {
	function totalSupply() external view returns (uint256);
	function ownerOf(uint256) external view returns (address);
	function tokenByIndex(uint256) external view returns (uint256);
}

contract BoardDividends {

	struct Info {
		SURF surf;
		Boards boards;
		address whirlpool;
	}
	Info private info;

	constructor() public {
		info.surf = SURF(0xEa319e87Cf06203DAe107Dd8E5672175e3Ee976c);
		info.boards = Boards(0xf90AeeF57Ae8Bc85FE8d40a3f4a45042F4258c67);
		info.whirlpool = info.surf.whirlpoolAddress();
	}

	function release() external {
		uint256 _balance = info.surf.balanceOf(address(this));
		if (_balance > 0) {
			uint256 _boards = info.boards.totalSupply();
			uint256 _each = _balance / _boards;
			for (uint256 i = 0; i < _boards; i++) {
				address _owner = info.boards.ownerOf(info.boards.tokenByIndex(i));

				// If the SURF Board owner is 0x0, send the SURF to the Whirlpool otherwise the transaction will revert
				if (_owner == address(0)) _owner = info.whirlpool;
				info.surf.transfer(_owner, _each);
			}
		}
	}
}