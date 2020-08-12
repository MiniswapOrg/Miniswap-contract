// SPDX-License-Identifier: SimPL-2.0
pragma solidity=0.6.9;

import './interfaces/IMiniswapMiner.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IMiniswapPair.sol';
import './libraries/MiniswapLibrary.sol';
import './interfaces/IERC20.sol';
import './libraries/SafeMath.sol';
import './interfaces/IMini.sol';

contract MiniswapMiner is IMiniswapMiner{
    using SafeMath for uint;
    
    address public override owner;
    address public override feeder;
    address public override developer;

    mapping(address=>bool) public override whitelistMap;
    mapping(uint256=>uint256) public override mineInfo; // day=>issueAmount
    mapping(address=>uint256) private balances;
    
    uint256 public override minFee;

    uint256 firstTxHeight;
    address MINI;
    mapping (uint=>mapping(address=>bool)) rewardMap;
    mapping (uint=>uint) rewardAmountByRoundMap;

    constructor(uint256 _minFee,address _mini,address _feeder,address _developer) public {
        owner = msg.sender;
        minFee = _minFee;
        MINI = _mini;
        feeder = _feeder;
        developer = _developer;
        firstTxHeight = block.number;
    }

    modifier isOwner(){
        require(msg.sender == owner,"forbidden:owner");
        _;
    }

    modifier isWhiteAddress(){
        require(whitelistMap[msg.sender] == true,"forbidden:whitelist");
        _;
    }

    function getToken(address token,address to) public isOwner() {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(to,balance);
    }

    function changeMinFee(uint256 _minFee) override public isOwner() {
        minFee = _minFee;
    }

    function addWhitelist(address pair) override public isOwner() {
        whitelistMap[pair] = true;
    }

    function addWhitelistByTokens(address factory ,address token0,address token1) override public isOwner() {
        address pair = MiniswapLibrary.pairFor(factory, token0, token1);
        addWhitelist(pair);
    }

    function removeWhitelist(address pair) override public isOwner() {
        whitelistMap[pair] = false;
    }

    function removeWhitelistByTokens(address factory ,address token0,address token1) override public isOwner() {
        address pair = MiniswapLibrary.pairFor(factory, token0, token1);
        removeWhitelist(pair);
    }

    function mining(address factory,address to,address token,uint amount) override public isWhiteAddress(){
        TransferHelper.safeTransferFrom(token,msg.sender,address(this),amount);
        if (token == MINI){
            //send half of increment to address0,the other send to feeder
            TransferHelper.safeTransfer(MINI,address(0x1111111111111111111111111111111111111111), amount.div(2));
            TransferHelper.safeTransfer(MINI,feeder, amount.sub(amount.div(2)));
            issueMini(amount,to);
        } else {
         //get price from token-USDT-MINI
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = MINI;
            uint256[] memory amountsOut = MiniswapLibrary.getAmountsOut(factory,amount,path); //[tokenAmountOut,USDTAmountOut,MINIAmountOut]

            uint256 issueAmount = amountsOut[1];
            //only mine when usdtout more than minFee
            if(issueAmount<= minFee)
                return;
            swapMini(factory,token,issueAmount,amount); 
            issueMini(issueAmount,to);
        }
    }

    function swapMini(address factory, address token,uint issueAmount,uint amount) internal {
        uint256 balance0 = IERC20(MINI).balanceOf(address(this));
        (address token0,address token1) = MiniswapLibrary.sortTokens(token,MINI);
        address pair_token_mini = MiniswapLibrary.pairFor(factory,token0,token1);
        (uint amount0Out ,uint amount1Out) = token0==token ? (uint(0),issueAmount):(issueAmount,uint(0));
        TransferHelper.safeTransfer(token,pair_token_mini,amount); //send token to pair
        IMiniswapPair(pair_token_mini).swap(
                amount0Out, amount1Out, address(this), new bytes(0)
            );
        uint miniAmount = IERC20(MINI).balanceOf(address(this)).sub(balance0);
        //send half of increment to address0,the other half send to feeder
        TransferHelper.safeTransfer(MINI,address(0x1111111111111111111111111111111111111111), miniAmount.div(2));
        TransferHelper.safeTransfer(MINI,feeder, miniAmount.div(2));
    }

    function issueMini(uint256 issueAmount,address to) internal{
        ///////The 6000 block height is one day, 30 day is one month
        uint durationDay = (block.number.sub(firstTxHeight)).div(6000);
        uint256 issueAmountLimit = MiniswapLibrary.getIssueAmountLimit(durationDay);
        //issue mini to liquilidity && user
        if( mineInfo[durationDay].add(issueAmount).add(issueAmount) > issueAmountLimit){
            issueAmount = issueAmountLimit.sub( mineInfo[durationDay]).div(2);
        }
        uint issueAmount_90 = issueAmount.mul(90).div(100);
        uint issueAmount_10 = issueAmount.sub(issueAmount_90);
        if(issueAmount > 0){
            IMini(MINI).issueTo(to,issueAmount_90);
            IMini(MINI).issueTo(msg.sender,issueAmount_90);
            IMini(MINI).issueTo(developer,issueAmount_10.mul(2));
            mineInfo[durationDay] = mineInfo[durationDay].add(issueAmount).add(issueAmount);
        }
    }
}