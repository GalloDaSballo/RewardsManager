// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract RewardsManager {

    uint256 private constant SECONDS_PER_EPOCH = 604800; // One epoch is one week
    // This allows to specify rewards on a per week basis, making it easier to interact with contract

    address[] public vaults; // list of vaults, just used for iterations and convenience

    struct Epoch {
        uint256 id; // Probably implicit in list of epochs
        uint256 blockstart;
        uint256 blockEnd;
    }

    struct EpochVaultRewards {
        uint256 epochId;
        address vault;
        uint256 totalBadger;
    }

    uint256 public currentEpoch = 1; // NOTE: Epoch 0 means you have withdrawn

    mapping(uint256 => Epoch) public epochs; // Epoch data for each epoch epochs[epochId]
    mapping(uint256 => mapping(address => uint256)) public badgerEmissionPerEpochPerVault; // Epoch data for each epoch badgerEmissionPerEpochPerVault[epochId][vaultAddress]
    

    mapping(uint256 => mapping(address => mapping(address => uint256))) public points; // Calculate points per each epoch points[epochId][vaultAddress][userAddress]
    mapping(uint256 => mapping(address => mapping(address => uint256))) public pointsWithdrawn; // Given point for epoch how many where withdrawn by user? pointsWithdrawn[epochId][vaultAddress][userAddress]
    
    mapping(uint256 => mapping(address => uint256)) public totalPoints; // Sum of all points given for a vault at an epoch totalPoints[epochId][vaultAddress]

    mapping(uint256 => mapping(address => mapping(address => uint256))) lastVaultAccruedTimestamp; // Last timestamp in which the vault was accrued in the epoch lastUserAccrueTimestamp[epochId][vaultAddress][userAddress]
    mapping(uint256 => mapping(address => mapping(address => uint256))) lastUserAccrueTimestamp; // Last timestamp in we accrued user to calculate rewards in epochs without interaction lastUserAccrueTimestamp[epochId][vaultAddress][userAddress]
    mapping(address => uint256) lastVaultDeposit; // Last Epoch in which any user deposited in the vault, used to know if vault needs to be brought to new epoch
    // AFAIK changing storage to the same value is a NO-OP and won't cost extra gas
    // Or just have the check and skip the op if need be

    mapping(uint256 => mapping(address => mapping(address => uint256))) public shares; // Calculate points per each epoch shares[epochId][vaultAddress][userAddress]    
    mapping(uint256 => mapping(address => uint256)) public totalSupply; // Sum of all deposits for a vault at an epoch totalSupply[epochId][vaultAddress]
    // User share of token X is equal to tokensForEpoch * points[epochId][vaultId][userAddress] / totalPoints[epochId][vaultAddress]
    // You accrue one point per second for each second you are in the vault


    // NOTE ABOUT ARCHITECTURE
    // This contract is fundamentally tracking the balances on all vaults for all users
    // This basically means we have duplicated logic, we could do without by simply adding this to the vault
    // Adding it may also allow to solve Yield Theft issues as we're accounting for value * time as a way to reward more fairly
    // NOTE: Pool Together has 100% gone through these ideas, we have 4 public audits to read through
    // CREDIT: Most of the code is inspired by:
    // AAVE STAKE V2
    // COMPOUND
    // INVERSE.FINANCE Dividend Token
    // Pool Together V4


    // Invariant for deposits
    // If you had X token at epoch N, you'll have X tokens at epoch N+1
    // Total supply may be different
    // However, we calculate your share by just multiplying the share * secodns in theb vault
    // If you had X tokens a epoch N, and you had X tokens at epoch N+1
    // You'll get N + 1 * SECONDS_PER_EPOCH points in epoch N+1 if you redeem at N+2
    // If you have X tokens at epoch N and withdraw, you'll get TIME_IN_EPOCH * X points


    // MAIN ISSUE
    // You'd need to accrue every single user to make sure that everyone get's the fair share
    // Alternatively you'd need to calcualate each share on each block
    // The alternative would be to check the vault.totalSupply()
    // However note that will change (can change at any time in any magnitude)
    // and as such cannot be trusted as much
    // NOTE: That the invariant for deposits works also for totalSupply


    // If totalSupply was X tokens at epoch N, and nothing changes in epoch N+1
    // Then in epoch N+1 the totalSupply was the same as in epoch N
    // If that's the case
    // and we accrue on every account change
    // then all we gotta do is take totalSupply * lastAccrue amount and that should net us the totalPoints per epoch
    // Remaining, non accrued users, have to be accrued without increasing the totalPoints as they are already accounted for in the totalSupply * time
    

    // If the invariant that shares at x are the same as shares at n+1
    // And we accrue users on any shares changes
    // Then we do not need

    mapping(uint256 => mapping(address => uint256)) public totalSupply; // totalSupply[epochId][vault] // totalSupply for each vault at that time // Used when we switch to new epoch as caching mechanism

    mapping(uint256 => mapping(address => mapping(address => uint256))) additionalReward; // additionalReward[epochId][vaultAddress][tokenAddress] = AMOUNT 

    function setNextEpoch(uint256 blockstart, uint256 blockEnd) {
        require(msg.sender == governance) // dev: !gov
        
        // TODO: Verify previous epoch ended

        // Lock reward value per vault per epoch

        // Due to Invariant:
        // totalSupply is same as last changed
        // because all deposits are same since last change
        // We can calculate the maxPoints this way, which means we have the exact total amount of points
        // Each user can be accrued just when they claim to save them the extra gas cost
        

        // if current epoch has no points, it means that this epoch had zero transfer, withdrawals, etc
        // I don't believe this will happen in practice, but in the case it does
        // Points for each person are equal to deposit * multiplier
        // Total points are just totalSupply * multiplier


        // Start new epoch
        ++currentEpoch;

        // Rewards can be specified until end of new epoch
    }
    // NOTE: What happens if you have no points for epoch

    /// @dev Add emissions for an epoch for a vault given the badger amount
    /// @notice You can only increase emissions, no rugging
    /// @notice You can only add emissions to this epoch or future ones, no retroactive
    function setEmission(uint256 epochId, address vault, uint256 badgerAmount) external {
        require(epochId >= currentEpoch); // dev: already ended

        // require(badgerEmissionPerEpochPerVault[epochId][vault] == 0); // dev: already set
        // NOTE: Instead of requiring emission, let's just increase the amount, it gives more flexibility
        // Basically you can only get rugged in the positive, cannot go below the amount provided

        // Check change in balance just to be sure
        uint256 startBalance = IERC20(BADGER).balanceOf(address(this));  
        IERC20(BADGER).safeTransferFrom(msg.sender, address(this), amount);
        uint256 endBalance = IERC20(BADGER).balanceOf(address(this));
 
        badgerEmissionPerEpochPerVault[epochId][vault] += endBalance - startBalance;
    }

    function setEmissions(uint256 epochId, address[] vaults, uint256[] badgerAmounts) external {
        require(vaults.length == badgerAmounts); // dev: length mistamtch

        for(uint256 i = 0; i < vaults.length; i++){
            setEmission(epochId, vaults[i], badgerAmounts[i]);   
        }
    }

    /// @dev Allows to setup new rewards with extra tokens, can only be positive (no rugging)
    /// @notice You can only add rewards for the currentEpoch or future ones, no retroactive stuff
    /// @notice This function can be called by anyone, effectively allowing for bribes / airdrops to vaults
    /// @notice If you want to allow retroactive airdrops, get in touch, we can figure something out
    function sendExtraReward(uint256 epochId, address vault, address extraReward, uint256 amount) external {
        require(epochId >= currentEpoch); // dev: already ended

        // Check change in balance to support `feeOnTransfer` tokens as well
        uint256 startBalance = IERC20(extraReward).balanceOf(address(this));  
        IERC20(extraReward).safeTransferFrom(msg.sender, address(this), amount);
        uint256 endBalance = IERC20(extraReward).balanceOf(address(this));

        additionalReward[currentEpoch][vault][extraReward] += endBalance - startBalance;
    }
    // NOTE: If you wanna do multiple rewards, just do a helper contract


    /// @dev given epochs and vaults, accrue all the points earned
    /// @notice pass in a list of epochs and vaults
    /// @notice each epoch must match with the vault
    /// E.g. 
    /// epochs = [1, 1, 2]
    /// vaults = [VAULT_1, VAULT_2, VAULT_1] 
    function accruePastRewards(uint256[] epochs, address[] vaults) public {
        require(epochs.length == vaults.length); // dev: length mistmatch 

        // You need to be in epoch 2 to claim epoch 1, strict check
        for(uint256 i = 0; i < epochs.length; i++){
            require(epochs[i] < currentEpoch); // dev: epoch hasn't ended
        }

        // May need to figure out the balance of the last user depoist

        // The balance is going to be
        // 0 if it's 0 and the lastUpdate is non-zero
        // The balance if the balance is non-zero and the lastUpdate is non-zero
        // The balance of the previous epoch (iterate) if the balance is zero and the last update is zero
        for(uint256 x = 0; x < epochs.length; x++) {
            accruePast(epochs[x], vaults[x], user);
        }
        

        // Loop over all epochs given

        // Accrue / Check if we need to accrue

        // Give them points

        // NOTE: We assume that the va

        // To assign points
        // Check if lastAccruedTimestamp == epochEnd
        // If it does, we already accrued until end

        

        // Have them specify the callData for the first epoch to accrueFrom
        // This saves gas and it should be fairly easy to implement frontend-side
    }

    function accruePast(uint256 epochId, address vault, address user) public {
        // We need to get the balance of user at epochId

        // We need to get the last time we accrued

        // Multiply by the rest of the duration

        //
    }

    function claimReward() {

    }

    function claimAllTokens(address[] tokens){

    }



    // NOTE: You have a growth factor when you deposit, that is based on the % of the deposit you made at the time
    // NOTE: If you go from epoch x to epoch y, then how do we know
    // If you don't change, then you have the same points, it's the cap of points that can go up or down based on vault interaction
    // That means that we're tracking


    function _getEmissionIndex(address vault) internal returns (uint256) {
        return points[currentEpoch][vault];
    }
    // Total Points per epoch = Total Deposits * Total Points per Second * Seconds in Epoch



    function notifyTransfer(uint256 _amount, address _from, address _to) external {
        // NOTE: Anybody can call this because it's indexed by msg.sender
        address vault = msg.sender; // Only the vault can change these

        if (_from == address(0)) {
            _handleDeposit(vault, to, amount);
        } else if (_to == address(0)) {
            _handleWithdrawal(vault, from, amount);
        } else {
            _handleTransfer(vault, from, to, amount);
        }
    }


    /// @dev handles a deposit for vault, to address of amount
    /// @notice,
    function _handleDeposit(address vault, address to, uint256 amount) internal {
        _accrueUser(vault, to);
        
        // Add deposit data for user
        shares[currentEpoch][vault][to] += amount;

        // And total shares for epoch
        totalSupply[currentEpoch][vault] += amount;
    }

    function _handleWithdrawal(address vault, address from, uint256 amount) internal {
        _accrueUser(vault, from);

        // Delete last shares
        // Delete deposit data or user
        shares[currentEpoch][vault][from] -= amount;
        // Reduce totalSupply
        totalSupply[currentEpoch][vault] -= amount;

    }

    function _handleTransfer(address vault, address from, address to, uint256 amount) internal {
        // Accrue points for from, so they get rewards
        _accrueUser(vault, from);
        // Accrue points for to, so they don't get too many rewards
        _accrueUser(vault, to);

         // Add deposit data for to
        shares[currentEpoch][vault][to] += amount;

         // Delete deposit data for from
        shares[currentEpoch][vault][from] -= amount;
    }

    /// @dev Accrue points gained during this epoch
    /// @notice This is called for both receiving and sending
    function _accrueUser(address vault, address user) {
        uint256 toMultiply = _getBalanceAtCurrentEpoch();

        // Update user balance at epoch 
        // We update becasue this may be 0 if we never updated before
        shares[currentEpoch][vault][user] = toMultiply;
        // Update vault totalSupply at epoch
        totalSupply[currentEpoch][vault] = _getTotalSupplyAtCurrentEpoch();

        if(toMultiply > 0){
            uint256 timeInEpochSinceLastAccrue = _getTimeInEpochFromLastAccrue();

            // Run the math and update the system
            uint256 newPoints = toMultiply * timeInEpochSinceLastAccrue;
            
            // Track user rewards
            points[currentEpoch][vault][user] += newPoints;
            // Track total points
            totalPoints[currentEpoch][vault] += newPoints;
            // At end of epoch userPoints / totalPoints is the percentage the user can receive of rewards (valid for any reward)
        }

        // Set last time for updating the user
        lastUserAccrueTimestamp[currentEpoch][vault][user] = block.timestamp;
    }



    /// @dev Given vault and user, find the last known balance
    /// @notice since we may look in the past, we also update the balance for current epoch
    function _getBalanceAtCurrentEpoch(address vault, address user) internal returns (uint256) {
        // Just ask the balance to the vault, avoids tons of issues
        uint256 balance = IVault(vault).balanceOf(user);

        return balance;
    }

    function _getTotalSupplyAtCurrentEpoch(address vault) internal returns (uint256) {
        // Just ask the totalSupply to the vault, avoids tons of issues
        uint256 totalSupply = IVault(vault).totalSupply();

        return totalSupply;
    }

    // NOTE: Due to lack of checks, it may be easier to check if numbers are wrong and just provide boundaries
    function _getTimeInEpochFromLastAccrue() internal returns (uint256) {
        uint256 lastBalanceChangeTime = lastUserAccrueTimestamp[currentEpoch][vault][user];

        // Change in balance happened this epoch, just ensure we are in active epoch and return difference
        if(lastBalanceChangeTime > 0) {
            require(block.timestamp < epochs[currentEpoch].blockEnd, "No epoch active"); // I believe this require can be helpful if we're not in an active epoch, which hopefully we can avoid
            return lastBalanceChangeTime - epochs[currentEpoch].blockStart; // Also avoids overflow
        }

        // Otherwise we return max time which is current - epochStart
        return block.timestamp - epochs[currentEpoch].blockStart;
    }

    // YOU DO NOT NEED TO ACCRUE OLD EPOCHS UNTIL YOU REDEEM
    // The reason is: They are not changing, the points that have changed have already and the points that are not changed are
    // just going to be deposit * time_spent as per the invariant

}