// SPDX-License-Identifier: MIT

import "./Ownable.sol";
import "./ERC20.sol";
import "./IUniswapV2Router02.sol";
import "./IUniswapV2Factory.sol";
import "./SafeMath.sol";

pragma solidity ^0.8.6;

contract FTCoin is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 private uniswapV2Router;
    address public uniswapV2Pair;

    address private constant deadWallet =
        address(0x000000000000000000000000000000000000dEaD);

    uint16 private buyBurnTax;
    uint16 private sellBurnTax;

    mapping(address => bool) private _isExcludedFromFees;

    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    constructor() ERC20("FastTruckCoin", "FTCoin") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );

        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        buyBurnTax = 5;
        sellBurnTax = 10;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);

        _mint(owner(), 3500000 * 10**uint256(decimals()));
    }

    function updateUniswapV2Router(address newAddress) external onlyOwner {
        require(
            newAddress != address(uniswapV2Router),
            "FTCoin: The router already has that address"
        );
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
        address _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());
        uniswapV2Pair = _uniswapV2Pair;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(
        address[] calldata accounts,
        bool excluded
    ) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function setBuyFee(uint16 _fee) external onlyOwner {
        buyBurnTax = _fee;
    }

    function setSellFee(uint16 _fee) external onlyOwner {
        sellBurnTax = _fee;
    }

    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
        require(
            pair != uniswapV2Pair,
            "FTCoin: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(
            automatedMarketMakerPairs[pair] != value,
            "FTCoin: Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != deadWallet, "ERC20: transfer from the dead address");
        require(amount > 0, "Amount must be greater than 0");

        bool takeFee = true;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        // Buy or Sell
        if (automatedMarketMakerPairs[from] || automatedMarketMakerPairs[to]) {
            if (takeFee) {
                if (automatedMarketMakerPairs[from]) {
                    // Buy
                    uint256 burnfee = amount.mul(buyBurnTax).div(100);
                    amount = amount.sub(burnfee);
                    super._transfer(from, deadWallet, burnfee);
                    super._transfer(from, to, amount);
                } else if (automatedMarketMakerPairs[to]) {
                    // Sell
                    uint256 burnfee = amount.mul(sellBurnTax).div(100);
                    amount = amount.sub(burnfee);
                    super._transfer(from, deadWallet, burnfee);
                    super._transfer(from, to, amount);
                }
            } else {
                super._transfer(from, to, amount);
            }
        } else {
            super._transfer(from, to, amount);
        }
    }
}
