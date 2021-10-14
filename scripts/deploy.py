from brownie import (
    accounts,
    network,
    BadgerTreeV2,
    SettV3,
)

from config import BADGER, WANT


def main():
    """
        WARNING: Only for testing purposes!!! Please dont deploy on production
    """

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
