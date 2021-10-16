from brownie import *
from helpers.constants import *
from helpers.utils import *
from config import BADGER_PER_BLOCK


def test_multi_user_multi_pools(deployer, users, vaults, badger_tree, badger, want):
    want.approve(vaults[0], MaxUint256, {"from": users[0]})
    want.approve(vaults[1], MaxUint256, {"from": users[1]})
    want.approve(vaults[1], MaxUint256, {"from": users[2]})
    # want.approve(vaults[2], MaxUint256, {"from": users[3]})
    # want.approve(vaults[2], MaxUint256, {"from": users[4]})
    # want.approve(vaults[2], MaxUint256, {"from": users[5]})

    # Emissions will be 25%,25%,50% respectively
    pid0 = (badger_tree.add(20, vaults[0], {"from": deployer})).return_value
    pid1 = (badger_tree.add(40, vaults[1], {"from": deployer})).return_value
    # pid2 = (badger_tree.add(40, vaults[2], {"from": deployer})).return_value

    # We have 6 users. lets put 1 user => Vault 0, 2 users => Vault 1, 3 users => Vault 2

    # VAULT 0
    start_block = web3.eth.block_number
    # vault 0 will start getting 25% badger rewards
    vaults[0].depositAll({"from": users[0]})

    # VAULT 1
    # first user of vault 1 owns 25% of vault shares
    # vault 1 will start getting 25% badger rewards
    vaults[1].deposit(want.balanceOf(users[1]) * 0.25, {"from": users[1]})
    # second user of vault 1 owns 75% of vault shares
    vaults[1].deposit(want.balanceOf(users[2]) * 0.75, {"from": users[2]})

    # VAULT 2
    # # first user of vault 2 owns 30% of vault shares
    # # vault 2 will start getting 50% badger rewards
    # vaults[2].deposit(want.balanceOf(users[3]) * 0.3, {"from": users[3]})
    # # second user of vault 2 owns 30% of vault shares
    # vaults[2].deposit(want.balanceOf(users[4]) * 0.3, {"from": users[4]})
    # # third user of vault 2 owns 40% of vault shares
    # vaults[2].deposit(want.balanceOf(users[5]) * 0.4, {"from": users[5]})

    # fast-forward 200 blocks
    # chain.mine(100)

    # will change all the emissions to 33.3%, 33.33%, 33.3%
    # badger_tree.set(pid0, 40)

    # chain.mine(100)

    blocks_spent = web3.eth.block_number - start_block

    expected_badger_emissions = blocks_spent * \
        BADGER_PER_BLOCK - (BADGER_PER_BLOCK * 0.66)
    # (BADGER_PER_BLOCK * 0.5 * 2)

    badger_tree.massUpdatePools([pid0, pid1])

    actual_badger_emissions = badger_tree.pendingBadger(
        pid0, users[0]) + badger_tree.pendingBadger(pid1, users[1]) + badger_tree.pendingBadger(pid1, users[2])
    #  + badger_tree.pendingBadger(pid2, users[3]) + badger_tree.pendingBadger(pid2, users[4]) + badger_tree.pendingBadger(pid2, users[5])

    # claim(pid0, users[0])
    # # since a new block was mined when calling the above mine function
    # # in the next claim function the user will get the rewards for the new mined block too
    # expected_badger_emissions += 0.5 * 0.25 * BADGER_PER_BLOCK
    # claim(pid1, users[1])
    # # since 2 new blocks has been mined
    # expected_badger_emissions += 2 * 0.5 * 0.75 * BADGER_PER_BLOCK
    # # claim(pid1, users[2])
    # actual_badger_emissions = badger.balanceOf(
    #     users[0]) + badger.balanceOf(users[1]) + badger.balanceOf(users[2])
    # + claim(pid1, users[2])
    # + claim(pid2, users[3]) + claim(pid2, users[4]) + claim(pid2, users[5])

    assert approx(actual_badger_emissions,
                  expected_badger_emissions, 0.001)
