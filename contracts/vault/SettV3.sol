// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../deps/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../../deps/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../../deps/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../../deps/@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../../deps/@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../deps/@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "../../interfaces/badger/IController.sol";
import "../../interfaces/token/IERC20Detailed.sol";
import "../../deps/SettAccessControlDefended.sol";
import "../../interfaces/yearn/BadgerGuestlistApi.sol";
import "../interfaces/IBadgerTreeV2.sol";


/*

Badger Vault contract for testing the rewards manager

*/

contract SettV3 is
    ERC20Upgradeable,
    SettAccessControlDefended,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;

    IERC20Upgradeable public token;

    uint256 public min;
    uint256 public constant max = 10000;

    address public controller;

    mapping(address => uint256) public blockLock;

    string internal constant _defaultNamePrefix = "Badger Sett ";
    string internal constant _symbolSymbolPrefix = "b";

    address public guardian;
    address public BADGERTREEV2;
    uint256 public PID; // PID for this vault in the BadgerTree Contract

    BadgerGuestListAPI public guestList;

    event FullPricePerShareUpdated(
        uint256 value,
        uint256 indexed timestamp,
        uint256 indexed blockNumber
    );

    function initialize(
        address _token,
        address _controller,
        address _governance,
        address _keeper,
        address _guardian,
        address _badgerTree,
        uint256 _pid,
        bool _overrideTokenName,
        string memory _namePrefix,
        string memory _symbolPrefix
    ) public initializer whenNotPaused {
        IERC20Detailed namedToken = IERC20Detailed(_token);
        string memory tokenName = namedToken.name();
        string memory tokenSymbol = namedToken.symbol();

        string memory name;
        string memory symbol;

        if (_overrideTokenName) {
            name = string(abi.encodePacked(_namePrefix, tokenName));
            symbol = string(abi.encodePacked(_symbolPrefix, tokenSymbol));
        } else {
            name = string(abi.encodePacked(_defaultNamePrefix, tokenName));
            symbol = string(abi.encodePacked(_symbolSymbolPrefix, tokenSymbol));
        }

        __ERC20_init(name, symbol);

        token = IERC20Upgradeable(_token);
        governance = _governance;
        strategist = address(0);
        keeper = _keeper;
        controller = _controller;
        guardian = _guardian;
        BADGERTREEV2 = _badgerTree;
        PID = _pid;

        min = 9500;

        emit FullPricePerShareUpdated(
            getPricePerFullShare(),
            block.timestamp,
            block.number
        );

        // Paused on launch
        _pause();
    }

    /// ===== Modifiers =====

    function _onlyController() internal view {
        require(msg.sender == controller, "onlyController");
    }

    function _onlyAuthorizedPausers() internal view {
        require(
            msg.sender == guardian || msg.sender == governance,
            "onlyPausers"
        );
    }

    function _blockLocked() internal view {
        require(blockLock[msg.sender] < block.number, "blockLocked");
    }

    /// ===== View Functions =====

    function version() public view returns (string memory) {
        return "1.3";
    }

    function getPricePerFullShare() public view virtual returns (uint256) {
        if (totalSupply() == 0) {
            return 1e18;
        }
        return (balance() * 1e18) / totalSupply();
    }

    /// @notice Return the total balance of the underlying token within the system
    /// @notice Sums the balance in the Sett, the Controller, and the Strategy
    function balance() public view virtual returns (uint256) {
        return
            token.balanceOf(address(this)) + (
                IController(controller).balanceOf(address(token))
            );
    }

    /// @notice Defines how much of the Setts' underlying can be borrowed by the Strategy for use
    /// @notice Custom logic in here for how much the vault allows to be borrowed
    /// @notice Sets minimum required on-hand to keep small withdrawals cheap
    function available() public view virtual returns (uint256) {
        return (token.balanceOf(address(this)) * min) / max;
    }

    /// ===== Public Actions =====

    /// @notice Deposit assets into the Sett, and return corresponding shares to the user
    /// @notice Only callable by EOA accounts that pass the _defend() check
    function deposit(uint256 _amount) public whenNotPaused {
        _defend();
        _blockLocked();

        _lockForBlock(msg.sender);
        _depositWithAuthorization(_amount, new bytes32[](0));
    }

    /// @notice Deposit variant with proof for merkle guest list
    function deposit(uint256 _amount, bytes32[] memory proof)
        public
        whenNotPaused
    {
        _defend();
        _blockLocked();

        _lockForBlock(msg.sender);
        _depositWithAuthorization(_amount, proof);
    }

    /// @notice Convenience function: Deposit entire balance of asset into the Sett, and return corresponding shares to the user
    /// @notice Only callable by EOA accounts that pass the _defend() check
    function depositAll() external whenNotPaused {
        _defend();
        _blockLocked();

        _lockForBlock(msg.sender);
        _depositWithAuthorization(
            token.balanceOf(msg.sender),
            new bytes32[](0)
        );
    }

    /// @notice DepositAll variant with proof for merkle guest list
    function depositAll(bytes32[] memory proof) external whenNotPaused {
        _defend();
        _blockLocked();

        _lockForBlock(msg.sender);
        _depositWithAuthorization(token.balanceOf(msg.sender), proof);
    }

    /// @notice No rebalance implementation for lower fees and faster swaps
    function withdraw(uint256 _shares) public whenNotPaused {
        _defend();
        _blockLocked();

        _lockForBlock(msg.sender);
        _withdraw(_shares);
    }

    /// @notice Convenience function: Withdraw all shares of the sender
    function withdrawAll() external whenNotPaused {
        _defend();
        _blockLocked();

        _lockForBlock(msg.sender);
        _withdraw(balanceOf(msg.sender));
    }

    /// ===== Permissioned Actions: Governance =====

    function setGuestList(address _guestList) external whenNotPaused {
        _onlyGovernance();
        guestList = BadgerGuestListAPI(_guestList);
    }

    /// @notice set the address for the badger rewards contract 
    function setBadgerTree(address _tree) external whenNotPaused {
        _onlyAuthorizedActors();
        BADGERTREEV2 = _tree;
    }

    /// @notice Set minimum threshold of underlying that must be deposited in strategy
    /// @notice Can only be changed by governance
    function setMin(uint256 _min) external whenNotPaused {
        _onlyGovernance();
        min = _min;
    }

    /// @notice Change controller address
    /// @notice Can only be changed by governance
    function setController(address _controller) public whenNotPaused {
        _onlyGovernance();
        controller = _controller;
    }

    /// @notice Change guardian address
    /// @notice Can only be changed by governance
    function setGuardian(address _guardian) external whenNotPaused {
        _onlyGovernance();
        guardian = _guardian;
    }

    /// ===== Permissioned Actions: Controller =====

    /// @notice Used to swap any borrowed reserve over the debt limit to liquidate to 'token'
    /// @notice Only controller can trigger harvests
    function harvest(address reserve, uint256 amount) external whenNotPaused {
        _onlyController();
        require(reserve != address(token), "token");
        IERC20Upgradeable(reserve).safeTransfer(controller, amount);
    }

    /// ===== Permissioned Functions: Trusted Actors =====

    /// @notice Transfer the underlying available to be claimed to the controller
    /// @notice The controller will deposit into the Strategy for yield-generating activities
    /// @notice Permissionless operation
    function earn() public whenNotPaused {
        _onlyAuthorizedActors();

        uint256 _bal = available();
        token.safeTransfer(controller, _bal);
        IController(controller).earn(address(token), _bal);
    }

    /// @dev Emit event tracking current full price per share
    /// @dev Provides a pure on-chain way of approximating APY
    function trackFullPricePerShare() external whenNotPaused {
        _onlyAuthorizedActors();
        emit FullPricePerShareUpdated(
            getPricePerFullShare(),
            block.timestamp,
            block.number
        );
    }

    function pause() external {
        _onlyAuthorizedPausers();
        _pause();
    }

    function unpause() external {
        _onlyGovernance();
        _unpause();
    }

    /// ===== Internal Implementations =====

    /// @dev Calculate the number of shares to issue for a given deposit
    /// @dev This is based on the realized value of underlying assets between Sett & associated Strategy
    function _deposit(uint256 _amount) internal virtual {
        uint256 _pool = balance();
        uint256 _before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = token.balanceOf(address(this));
        _amount = _after - _before; // Additional check for deflationary tokens
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply()) / _pool;
        }
        _mint(msg.sender, shares);
    }

    function _depositWithAuthorization(uint256 _amount, bytes32[] memory proof)
        internal
        virtual
    {
        if (address(guestList) != address(0)) {
            require(
                guestList.authorized(msg.sender, _amount, proof),
                "guest-list-authorization"
            );
        }
        _deposit(_amount);
    }

    // No rebalance implementation for lower fees and faster swaps
    function _withdraw(uint256 _shares) internal virtual {
        uint256 r = (balance() * _shares) / totalSupply();
        _burn(msg.sender, _shares);

        // Check balance
        uint256 b = token.balanceOf(address(this));
        if (b < r) {
            uint256 _toWithdraw = r - b;
            IController(controller).withdraw(address(token), _toWithdraw);
            uint256 _after = token.balanceOf(address(this));
            uint256 _diff = _after  - b;
            if (_diff < _toWithdraw) {
                r = b +_diff;
            }
        }

        token.safeTransfer(msg.sender, r);
    }

    function _lockForBlock(address account) internal {
        blockLock[account] = block.number;
    }

    /// ===== ERC20 Overrides =====

    /// @dev Add blockLock to transfers, users cannot transfer tokens in the same block as a deposit or withdrawal.
    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        _blockLocked();
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override whenNotPaused returns (bool) {
        _blockLocked();
        return  super.transferFrom(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal override {
        super._mint(account, amount);
        IBadgerTreeV2(BADGERTREEV2).notifyTransfer(PID, amount, address(0), account);
    }

    function _burn(address account, uint256 amount) internal override {
        super._burn(account, amount);
        IBadgerTreeV2(BADGERTREEV2).notifyTransfer(PID, amount, account, address(0)); 
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        super._transfer(sender, recipient, amount);
        IBadgerTreeV2(BADGERTREEV2).notifyTransfer(PID, amount, sender, recipient); 
    }
}
