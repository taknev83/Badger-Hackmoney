// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import {BaseStrategy} from "@badger-finance/BaseStrategy.sol";
import {IRouter} from "../interfaces/spooky/IRouter.sol";
import {IXBooToken} from "../interfaces/spooky/IXBooToken.sol";
import {IXBooStaking} from "../interfaces/spooky/IXBooStaking.sol";

contract MyStrategy is BaseStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    // address public want; // Inherited from BaseStrategy
    // address public lpComponent; // Token that represents ownership in a pool, not always used
    // address public reward; // Token we farm

    // address constant BADGER = 0x3472A5A71965499acd81997a54BBA8D852C6E53d;

    address constant XBOO = 0xa48d959AE2E88f1dAA7D5F611E01908106dE7598; // Spookyswap: xBOO Token
    address constant XBOOSTAKING = 0x2352b745561e7e6FCD03c093cE7220e3e126ace0; // Spookyswap: AcaLab xBOO Staking

    // As the Reward token address & pool ID changes, the values are set after initialization
    address public REWARD;
    uint256 public pid;
    // for swapping
    address constant USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address constant DAI = 0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E;

    // Spooky Router
    IRouter public constant ROUTER = IRouter(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
    IXBooToken public constant XBOOTOKEN = IXBooToken(0xa48d959AE2E88f1dAA7D5F611E01908106dE7598);
    IXBooStaking public constant XBOOSTAKING_CONTRACT = IXBooStaking(0x2352b745561e7e6FCD03c093cE7220e3e126ace0);

    /// @dev Initialize the Strategy with security settings as well as tokens
    /// @notice Proxies will set any non constant variable you declare as default value
    /// @dev add any extra changeable variable at end of initializer as shown
    function initialize(address _vault, address[1] memory _wantConfig) public initializer {
        __BaseStrategy_init(_vault);
        /// @dev Add config here
        want = _wantConfig[0];

        REWARD = 0x412a13C109aC30f0dB80AD3Bd1DeFd5D0A6c0Ac6; // Stader (wormhole) (SD)

        //Pool Id of SD Token in xBOO staking contract
        pid = 34;

        IERC20Upgradeable(want).safeApprove(address(XBOOTOKEN), type(uint256).max);
        IERC20Upgradeable(XBOO).safeApprove(address(XBOOSTAKING_CONTRACT), type(uint256).max);

        //Approve for reward swapping
        IERC20Upgradeable(REWARD).safeApprove(address(ROUTER), type(uint256).max);
        IERC20Upgradeable(want).safeApprove(address(ROUTER), type(uint256).max);
        IERC20Upgradeable(USDC).safeApprove(address(ROUTER), type(uint256).max);
        IERC20Upgradeable(DAI).safeApprove(address(ROUTER), type(uint256).max);

        // If you need to set new values that are not constants, set them like so
        // stakingContract = 0x79ba8b76F61Db3e7D994f7E384ba8f7870A043b7;

        // If you need to do one-off approvals do them here like so
        // IERC20Upgradeable(reward).safeApprove(
        //     address(DX_SWAP_ROUTER),
        //     type(uint256).max
        // );
    }

    /// @dev Return the name of the strategy
    function getName() external pure override returns (string memory) {
        return "Badger-BOO-xBOO-staking";
    }

    /// @dev Return a list of protected tokens
    /// @notice It's very important all tokens that are meant to be in the strategy to be marked as protected
    /// @notice this provides security guarantees to the depositors they can't be sweeped away
    function getProtectedTokens() public view virtual override returns (address[] memory) {
        address[] memory protectedTokens = new address[](3);
        protectedTokens[0] = want;
        protectedTokens[1] = XBOO;
        protectedTokens[2] = REWARD;
        return protectedTokens;
    }

    /// @dev Deposit `_amount` of want, investing it to earn yield
    function _deposit(uint256 _amount) internal override {
        // Add code here to invest `_amount` of want to earn yield
        XBOOTOKEN.enter(_amount);
        uint256 xBooToken = IERC20Upgradeable(XBOO).balanceOf(address(this));
        XBOOSTAKING_CONTRACT.deposit(pid, xBooToken);
    }

    /// @dev Withdraw all funds, this is used for migrations, most of the time for emergency reasons
    function _withdrawAll() internal override {
        // Add code here to unlock all available funds
        (uint256 xBooBalance, uint256 rewardDebt) = XBOOSTAKING_CONTRACT.userInfo(pid, address(this));
        XBOOSTAKING_CONTRACT.withdraw(pid, xBooBalance);
        XBOOTOKEN.leave(xBooBalance);
    }

    /// @dev Withdraw `_amount` of want, so that it can be sent to the vault / depositor
    /// @notice just unlock the funds and return the amount you could unlock
    function _withdrawSome(uint256 _amount) internal override returns (uint256) {
        // Add code here to unlock / withdraw `_amount` of tokens to the withdrawer
        // If there's a loss, make sure to have the withdrawer pay the loss to avoid exploits
        // Socializing loss is always a bad idea
        if (_amount > balanceOfPool()) {
            _amount = balanceOfPool();
        }
        uint256 balBefore = balanceOfWant();
        uint256 reqXBooToWithdraw = XBOOTOKEN.BOOForxBOO(_amount);
        XBOOSTAKING_CONTRACT.withdraw(pid, reqXBooToWithdraw);
        XBOOTOKEN.leave(reqXBooToWithdraw);
        uint256 balAfter = balanceOfWant();
        return balAfter.sub(balBefore);
    }

    /// @dev Does this function require `tend` to be called?
    function _isTendable() internal pure override returns (bool) {
        return true; // Change to true if the strategy should be tended
    }

    function _harvest() internal override returns (TokenAmount[] memory harvested) {
        // No-op as we don't do anything with funds
        // use autoCompoundRatio here to convert rewards to want ...

        uint256 beforeWant = IERC20Upgradeable(want).balanceOf(address(this));

        //Harvest rewars by withdrawing 0 xBoo
        XBOOSTAKING_CONTRACT.withdraw(pid, 0);
        uint256 allRewards = IERC20Upgradeable(REWARD).balanceOf(address(this));

        // Sell for more want
        harvested = new TokenAmount[](1);
        // harvested[0] = TokenAmount(REWARD, 0);

        if (allRewards > 0) {
            harvested[0] = TokenAmount(REWARD, allRewards);

            address[] memory path = new address[](4);
            path[0] = REWARD;
            path[1] = USDC;
            path[2] = DAI;
            path[3] = want;

            IRouter(ROUTER).swapExactTokensForTokens(allRewards, 0, path, address(this), block.timestamp);
        } else {
            harvested[0] = TokenAmount(REWARD, 0);
        }

        uint256 wantHarvested = IERC20Upgradeable(want).balanceOf(address(this)).sub(beforeWant);

        // Report profit for the want increase (NOTE: We are not getting perf fee on AAVE APY with this code)
        _reportToVault(wantHarvested);

        _withdrawAll();
        uint256 wantBalance = IERC20Upgradeable(want).balanceOf(address(this)); // Cache to save gas on worst case
        _deposit(wantBalance);

        // Use this if your strategy doesn't sell the extra tokens
        // This will take fees and send the token to the badgerTree
        // _processExtraToken(token, amount);

        return harvested;
    }

    // Example tend is a no-op which returns the values, could also just revert
    function _tend() internal override returns (TokenAmount[] memory tended) {
        uint256 balanceToTend = balanceOfWant();
        tended = new TokenAmount[](1);
        if (balanceToTend > 0) {
            _deposit(balanceToTend);
            tended[0] = TokenAmount(want, balanceToTend);
        } else {
            tended[0] = TokenAmount(want, 0);
        }
        return tended;
    }

    /// @dev Return the balance (in want) that the strategy has invested somewhere
    function balanceOfPool() public view override returns (uint256) {
        // Change this to return the amount of want invested in another protocol
        (uint256 xBooBalance, ) = XBOOSTAKING_CONTRACT.userInfo(pid, address(this));
        uint256 booBalance = XBOOTOKEN.xBOOForBOO(xBooBalance);
        return booBalance;
    }

    /// @dev Return the balance of rewards that the strategy has accrued
    /// @notice Used for offChain APY and Harvest Health monitoring
    function balanceOfRewards() external view override returns (TokenAmount[] memory rewards) {
        (uint256 accruedRewards, ) = XBOOSTAKING_CONTRACT.userInfo(pid, address(this));
        rewards = new TokenAmount[](1);
        rewards[0] = TokenAmount(REWARD, accruedRewards);
        return rewards;
    }
}
