from brownie import (
    accounts,
    BadgerTreeV2,
    SettV3,
    Controller,
    Contract,
    interface
)

from config import BADGER, WANT, BADGER_PER_BLOCK
from dotmap import DotMap
import pytest


def deploy_vault(dev, badger_tree):
    controller = Controller.deploy({"from": dev})
    controller.initialize(
        dev,
        dev,
        dev,
        dev
    )

    # deploy vault
    vault = SettV3.deploy(
        {"from": dev}
    )

    vault.initialize(
        WANT,
        controller,
        dev,
        dev,
        dev,
        badger_tree,
        False,
        " ",
        " ",
        {"from": dev}
    )

    vault.unpause({"from": dev})
    controller.setVault(WANT, vault)

    return vault


def get_want_for_user(user, want, router):
    router.swapExactETHForTokens(
        0,  # Mint out
        ["0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", want],
        user,
        9999999999999999,
        {"from": user, "value": 5 * 10**18}
    )

    return user


@pytest.fixture
def deployed():
    dev = accounts[0]
    badger = interface.IERC20(BADGER)
    want = interface.IERC20(WANT)

    # Deploy rewards contract
    badger_tree = BadgerTreeV2.deploy(
        BADGER,
        BADGER_PER_BLOCK,
        {"from": dev}
    )

    # uniswap some badgers into the tree
    router = Contract.from_explorer(
        "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D")
    router.swapExactETHForTokens(
        0,  # Mint out
        ["0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", BADGER],
        badger_tree,
        9999999999999999,
        {"from": dev, "value": 100000000000000000000}
    )

    assert badger.balanceOf(badger_tree) > 0

    # uniswap some want to user
    user1 = get_want_for_user(accounts[1], WANT, router)
    user2 = get_want_for_user(accounts[2], WANT, router)
    user3 = get_want_for_user(accounts[3], WANT, router)
    user4 = get_want_for_user(accounts[4], WANT, router)
    user5 = get_want_for_user(accounts[5], WANT, router)
    user6 = get_want_for_user(accounts[6], WANT, router)

    vault1 = deploy_vault(dev, badger_tree)
    vault2 = deploy_vault(dev, badger_tree)
    vault3 = deploy_vault(dev, badger_tree)

    return DotMap(
        deployer=dev,
        users=[user1, user2, user3, user4, user5, user6],
        vaults=[vault1, vault2, vault3],
        badger_tree=badger_tree,
        badger=badger,
        want=want
    )


@pytest.fixture
def vaults(deployed):
    return deployed.vaults


@pytest.fixture
def deployer(deployed):
    return deployed.deployer


@pytest.fixture
def badger_tree(deployed):
    return deployed.badger_tree


@pytest.fixture
def badger(deployed):
    return deployed.badger


@pytest.fixture
def want(deployed):
    return deployed.want


@pytest.fixture
def users(deployed):
    return deployed.users
