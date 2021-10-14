import brownie
from brownie import *


def test_basic_single_pool(deployer, vault, badger_tree, badger, want):
    user1 = accounts[1]
    user2 = accounts[2]

    # test that vault can be added to the tree
    tx = badger_tree.add(20, vault, {"from": deployer})
    pid = tx.return_value

    pool = badger_tree.poolInfo(pid)

    assert pool[2] == 20
    assert pool[4] == vault
