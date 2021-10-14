import brownie
from brownie import *
from helpers.constants import *
from helpers.utils import *
from config import BADGER_PER_BLOCK


def test_basic_single_user_single_pool(deployer, user, vault, badger_tree, badger, want):
    # test that vault can be added to the tree
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
    badger_tree.harvest(pid, user, {"from": user})

    assert approx(badger.balanceOf(user), BADGER_PER_BLOCK, 0.001)
