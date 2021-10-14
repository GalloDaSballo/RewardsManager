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


@pytest.fixture
def deployed():
    dev = accounts[0]
    user = accounts[1]
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
        {"from": dev, "value": 50000000000000000000}
    )

    assert badger.balanceOf(badger_tree) > 0

    # uniswap some want to user
    router.swapExactETHForTokens(
        0,  # Mint out
        ["0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", WANT],
        user,
        9999999999999999,
        {"from": user, "value": 5 * 10**18}
    )

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

    return DotMap(
        deployer=dev,
        user=user,
        vault=vault,
        badger_tree=badger_tree,
        badger=badger,
        want=want
    )


@pytest.fixture
def vault(deployed):
    return deployed.vault


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
def user(deployed):
    return deployed.user
