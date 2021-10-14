from brownie import (
    accounts,
    network,
    BadgerTreeV2,
    SettV3,
)

from config import BADGER, WANT

from dotmap import DotMap
import pytest


@pytest.fixture
def deployed():
    dev = accounts[0]
    CONTROLLER = dev  # pretty sure not making any calls to the controller for our tests

    # Deploy rewards contract
    badger_tree = BadgerTreeV2.deploy(
        BADGER,
        {"from": dev}
    )

    # deploy vault
    vault = SettV3.deploy(
        {"from": dev}
    )

    vault.initialize(
        WANT,
        CONTROLLER,
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

    return DotMap(
        deployer=dev,
        vault=vault,
        badger_tree=badger_tree,
        badger=BADGER,
        want=WANT
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
