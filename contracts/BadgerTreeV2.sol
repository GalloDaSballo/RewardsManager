// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../interfaces/BoringBatchable.sol";
import "../interfaces/BoringOwnable.sol";
import "../interfaces/token/IERC20.sol";
import "./interfaces/ISettV3.sol";
import "../libraries/BoringERC20.sol";
import "../deps/@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// TODO: 
// What happens if the contract doesn't have enough BADGER tokens for BADGER emissions per block
// Make a calculation of how many blocks the badger emmissions will last based on current balance
// And then create a function to pause the rewards once the badgers run out.

contract BadgerTreeV2 is BoringBatchable, BoringOwnable, PausableUpgradeable  {
    using BoringERC20 for IERC20;

    /// @notice Info of each user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of BADGER entitled to the user
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    /// @notice Info of each pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of BADGER to distribute per block.
    struct PoolInfo {
        uint128 accBadgerPerShare;
        uint64 lastRewardBlock;
        uint64 allocPoint; 
        uint256 lpSupply; // total deposits into that pool
        address token; // address of the vault
    }

    /// @notice Address of BADGER contract.
    IERC20 public immutable BADGER;

    /// @notice Info of each pool.
    PoolInfo[] public poolInfo;

     /// @notice Address of each `IRewarder` contract in MCV2.
    // IRewarder[] public rewarder;

    /// @notice Info of each user that stakes Vault tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    uint256 private BADGER_PER_BLOCK;
    uint256 private constant PRECISION = 1e12;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 indexed pid, uint256 amount);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint, address indexed vault);
    // event LogPoolAddition(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken, IRewarder indexed rewarder);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint);
    // event LogSetPool(uint256 indexed pid, uint256 allocPoint, IRewarder indexed rewarder, bool overwrite);
    event LogUpdatePool(uint256 indexed pid, uint64 lastRewardBlock, uint256 lpSupply, uint256 accBadgerPerShare);

    /// @param _badger The BADGER token contract address.
    constructor(IERC20 _badger, uint256 badger_per_block) {
        BADGER = _badger;
        BADGER_PER_BLOCK = badger_per_block;
    }

    /// @notice Returns the number of pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /// @notice set the number of bader emissions per block
    function setBadgerPerBlock(uint256 _val) external onlyOwner {
        BADGER_PER_BLOCK = _val;
    }

    function add(uint256 allocPoint, address _poolToken) public onlyOwner returns(uint256 pid) {
        uint256 lastRewardBlock = block.number;
        totalAllocPoint += allocPoint;
        // rewarder.push(_rewarder);

        poolInfo.push(PoolInfo({
            allocPoint: uint64(allocPoint),
            lastRewardBlock: uint64(lastRewardBlock),
            accBadgerPerShare: 0,
            lpSupply: 0,
            token: _poolToken
        }));
        pid = poolInfo.length -1;
        ISettV3(_poolToken).setPid(pid);
        emit LogPoolAddition(pid, allocPoint, _poolToken);
    }

    /// @notice Update the given pool's BADGER allocation point
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint256 _pid, uint256 _allocPoint) public onlyOwner {
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = uint64(_allocPoint);
        emit LogSetPool(_pid, _allocPoint);
    }

    /// @notice returns the badgers emitted per block for the vault
    function badgerPerVault(uint256 _pid) public view returns (uint256) {
        return (BADGER_PER_BLOCK * poolInfo[_pid].allocPoint) / totalAllocPoint;
    }

    /// @notice View function to see pending BADGER on frontend.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending BADGER reward for a given user.
    function pendingBadger(uint256 _pid, address _user) external view returns (uint256 pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accBadgerPerShare = pool.accBadgerPerShare;
        if (block.number > pool.lastRewardBlock && pool.lpSupply != 0) {
            uint256 blocks = block.number - pool.lastRewardBlock;
            uint256 badgerReward = (blocks * BADGER_PER_BLOCK * pool.allocPoint) / totalAllocPoint;
            accBadgerPerShare = accBadgerPerShare + ((badgerReward * PRECISION) / pool.lpSupply);
        }
        pending = uint256(int256((user.amount * accBadgerPerShare) / PRECISION) - user.rewardDebt);
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    /// @param pids Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if (block.number > pool.lastRewardBlock) {
            if (pool.lpSupply > 0) {
                uint256 blocks = block.number - pool.lastRewardBlock;
                uint256 badgerReward = (blocks * BADGER_PER_BLOCK * pool.allocPoint) / totalAllocPoint;
                pool.accBadgerPerShare += uint128((badgerReward * PRECISION) / pool.lpSupply);
            }
            pool.lastRewardBlock = uint64(block.number);
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardBlock, pool.lpSupply, pool.accBadgerPerShare);
        }
    }

    function notifyTransfer(uint256 _pid, uint256 _amount, address _from, address _to) public {
        PoolInfo memory pool = updatePool(_pid);
        require(msg.sender == pool.token, "Only Vault");
        UserInfo storage from = userInfo[_pid][_from];
        UserInfo storage to = userInfo[_pid][_to];

        int256 _rewardDebt = int256((_amount * pool.accBadgerPerShare) / PRECISION);

        if (_from == address(0)) {
            // notifyDepositp
            to.amount += _amount;
            to.rewardDebt += _rewardDebt;

            // Interactions
            // IRewarder _rewarder = rewarder[pid];
            // if (address(_rewarder) != address(0)) {
            //     _rewarder.onSushiReward(pid, to, to, 0, user.amount);
            // }

            poolInfo[_pid].lpSupply += _amount;
            emit Deposit(_to, _pid, _amount);
        } else if (_to == address(0)) {
            // notifyWithdraw
            from.rewardDebt -= _rewardDebt;
            from.amount -= _amount;

            // Interactions
            // IRewarder _rewarder = rewarder[pid];
            // if (address(_rewarder) != address(0)) {
            //     _rewarder.onSushiReward(pid, msg.sender, to, 0, user.amount);
            // }
            
            poolInfo[_pid].lpSupply -= _amount;

            emit Withdraw(_from, _pid, _amount);
        } else {
            // transfer between users
            to.amount += _amount;
            from.amount -= _amount;

            to.rewardDebt += _rewardDebt;
            from.rewardDebt -= _rewardDebt;

            emit Transfer(_from, _to, _pid, _amount);
        }
    }

    /// @notice Harvest badger rewards for a vault sender to `to`
    /// @param pid The index of the pool. See `poolInfo`
    /// @param to Receiver of BADGER rewards
    function claim(uint256 pid, address to) public whenNotPaused {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];
        int256 accumulatedBadger = int256((user.amount * pool.accBadgerPerShare) / PRECISION);
        uint256 _pendingBadger = uint256(accumulatedBadger - user.rewardDebt);

        // Effects
        user.rewardDebt = accumulatedBadger;

        // Interactions
        if (_pendingBadger != 0) {
            BADGER.safeTransfer(to, _pendingBadger);
        }
        
        // IRewarder _rewarder = rewarder[pid];
        // if (address(_rewarder) != address(0)) {
        //     _rewarder.onSushiReward( pid, msg.sender, to, _pendingBadger, user.amount);
        // }

        emit Harvest(msg.sender, pid, _pendingBadger);
    }
}