from helpers.StrategyCoreResolver import StrategyCoreResolver
from rich.console import Console

console = Console()


class StrategyResolver(StrategyCoreResolver):
    def get_strategy_destinations(self):
        """
        Track balances for all strategy implementations
        (Strategy Must Implement)
        """
        strategy = self.manager.strategy
        return {
            "Want": strategy.want(),
            # "Reward": strategy.REWARD(),
            # "XBoo": strategy.XBOO(),
            # "XBooStaking": strategy.XBOOStaking(),
        }

    def hook_after_confirm_withdraw(self, before, after, params):
        """
        Specifies extra check for ordinary operation on withdrawal
        Use this to verify that balances in the get_strategy_destinations are properly set
        """
        # want is withdrawn from the Lending pool
        # assert after.balances("want", "pool") < before.balances("want", "pool")

        # strategy balanceOfPool goes down
        assert after.get("strategy.balanceOfPool") < before.get(
            "strategy.balanceOfPool"
        )

    def hook_after_confirm_deposit(self, before, after, params):
        """
        Specifies extra check for ordinary operation on deposit
        Use this to verify that balances in the get_strategy_destinations are properly set
        """
        assert True  ## Done in earn

    def hook_after_earn(self, before, after, params):
        """
        Specifies extra check for ordinary operation on earn
        Use this to verify that balances in the get_strategy_destinations are properly set
        """
        # want in the vault goes down
        assert after.balances("want", "sett") < before.balances("want", "sett")

        # want invested by the strategy goes up
        assert after.get("strategy.balanceOfPool") > before.get(
            "strategy.balanceOfPool"
        )

    def confirm_harvest(self, before, after, tx):
        #     """
        #     Verfies that the Harvest produced yield and fees
        #     NOTE: This overrides default check, use only if you know what you're doing
        #     """
        console.print("=== Compare Harvest ===")
        self.manager.printCompare(before, after)
        self.confirm_harvest_state(before, after, tx)

        valueGained = after.get("sett.getPricePerFullShare") > before.get(
            "sett.getPricePerFullShare"
        )

        assert valueGained

    def confirm_tend(self, before, after, tx):
        """
        Tend Should;
        - Increase the number of staked tended tokens in the strategy-specific mechanism
        - Reduce the number of tended tokens in the Strategy to zero

        (Strategy Must Implement)
        """
        if before.get("strategy.balanceOfWant") > 0:
            assert after.get("strategy.balanceOfWant") == 0
            assert after.get("strategy.balanceOfPool") > before.get(
                "strategy.balanceOfPool"
            )
