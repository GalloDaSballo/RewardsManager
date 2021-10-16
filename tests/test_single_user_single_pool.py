from brownie import *
from helpers.constants import *
from helpers.utils import *
from config import BADGER_PER_BLOCK


def test_single_user_single_pool(deployer, users, vaults, badger_tree, badger, want):
    # test that vault can be added to the tree
    vault = vaults[0]
    user = users[0]
    tx = badger_tree.add(20, vault, {"from": deployer})
    pid = tx.return_value

    pool = badger_tree.poolInfo(pid)

    assert pool[2] == 20
    assert pool[4] == vault

    # user must get added to pool rewards on deposit to vault
    want.approve(vault, MaxUint256, {"from": user})
    toDeposit = want.balanceOf(user)
    vault.deposit(toDeposit, {"from": user})

    userInfo = badger_tree.userInfo(pid, user)

    assert userInfo[0] == toDeposit

    # user must get exactly BADGER_PER_BLOCK badgers after 1 block
    # since the user currently owns 100% of the reward pool
    badger_tree.claim(pid, user, {"from": user})

    assert approx(badger.balanceOf(user), BADGER_PER_BLOCK, 0.001)

    # after withdrawing all the first claim must give the pending rewards to the user
    # and then any other claim after that must give zero rewards
    vault.withdrawAll({"from": user})
    userInfo = badger_tree.userInfo(pid, user)
    assert userInfo[0] == 0

    # if there are pending rewards
    if (userInfo[1] < 0):  # rewardDebt will be negative if there are rewards
        bal1 = badger.balanceOf(user)

        badger_tree.claim(pid, user, {"from": user})
        bal2 = badger.balanceOf(user)

        assert bal2 - bal1 == -userInfo[1]

    bal2 = badger.balanceOf(user)
    # all other subsequent claims must give zero rewards
    badger_tree.claim(pid, user, {"from": user})
    bal3 = badger.balanceOf(user)
    assert bal3 - bal2 == 0

    # another check for sanity
    badger_tree.claim(pid, user, {"from": user})
    bal4 = badger.balanceOf(user)
    assert bal4 - bal3 == 0
