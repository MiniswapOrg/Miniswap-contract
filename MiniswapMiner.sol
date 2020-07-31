// SPDX-License-Identifier: SimPL-2.0
pragma solidity=0.6.9;

import './interfaces/IMiniswapMiner.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IMiniswapV2Pair.sol';
import './libraries/MiniswapV2Library.sol';
import './interfaces/IERC20.sol';
import './libraries/SafeMath.sol';
import './interfaces/IMini.sol';

contract MiniswapMiner is IMiniswapMiner{
    using SafeMath for uint;
    
    address public override owner;
    bool public override rewardStatus;
    uint public override rewardRound;
    mapping(address=>bool) public override whitelistMap;
    mapping(uint256=>uint256) public override mineInfo; // day=>issueAmount
    
    uint256 public override minFee;

    uint256 firstTxHeight;
    address MINI;
    address USDT;
    mapping (uint=>mapping(address=>bool)) rewardMap;
    mapping (uint=>uint) rewardAmountByRoundMap;

    constructor(uint256 _minFee,address _usdt,address _mini) public {
        owner = msg.sender;
        minFee = _minFee;
        MINI = _mini;
        USDT = _usdt;
    }

    modifier isOwner(){
        require(msg.sender == owner,"forbidden:owner");
        _;
    }

    modifier isWhiteAddress(){
        require(whitelistMap[msg.sender] == true,"forbidden:whitelist");
        _;
    }

    function isGetReward(uint index,address addr) public override returns(bool){
        require(index <= rewardRound, "Mine:rewardRound");
        return rewardMap[index][addr];
    }

    function changeMinFee(uint256 _minFee) override public isOwner() {
        minFee = _minFee;
    }

    function addWhitelist(address pair) override public isOwner() {
        whitelistMap[pair] = true;
    }

    function addWhitelistByTokens(address factory ,address token0,address token1) override public isOwner() {
        address pair = MiniswapV2Library.pairFor(factory, token0, token1);
        addWhitelist(pair);
    }

    function removeWhitelist(address pair) override public isOwner() {
        whitelistMap[pair] = false;
    }

    function removeWhitelistByTokens(address factory ,address token0,address token1) override public isOwner() {
        address pair = MiniswapV2Library.pairFor(factory, token0, token1);
        removeWhitelist(pair);
    }

    function startReward() override public isOwner(){
        require(rewardStatus == false,"Mine:startReward");
        rewardRound++;
        uint256 balance = IERC20(MINI).balanceOf(address(this));
        rewardAmountByRoundMap[rewardRound] = balance;
        rewardStatus = true;
    }

    function pauseReward() override public isOwner() {
         require(rewardStatus == true,"Mine:startReward");
         rewardStatus = false;
    }

    function getReward() override public{
        require(rewardStatus == true,"Mine:RewardStatus");
        require(isGetReward(rewardRound,msg.sender), "Mine:isGetReward");
        //get the balance of msg.sender
        uint256 balance = IERC20(MINI).balanceOf(msg.sender);
        uint256 totoalSupply = IERC20(MINI).totalSupply();
        uint256 amount = balance.mul(rewardAmountByRoundMap[rewardRound]).div(totoalSupply);
        if(amount >0){
            TransferHelper.safeTransfer(MINI,msg.sender,amount);
        }
        rewardMap[rewardRound][msg.sender] = true;
    }

    function mining(address factory,address to,address token,uint256 amount) override public isWhiteAddress(){
        //transfer amount token from sender to address(this)
        require(IERC20(token).transferFrom(msg.sender,address(this),amount),"transferFrom error");
        //get price from token-USDT-MINI
        address[] memory path;
        path[0] = token;
        path[1] = USDT;
        path[2] = MINI;
        uint256[] memory amountsOut = MiniswapV2Library.getAmountsInWithNoFee(factory,amount,path); //[tokenAmountOut,USDTAmountOut,MINIAmountOut]
        //only mine when usdtout more than minFee
        if(amountsOut[1] <= minFee)
            return;

        uint256 issueAmount = amountsOut[2];
        swapMini(factory,token,amountsOut[2],amount);
        issueMini(amountsOut[2],to);
        if (firstTxHeight == 0){
            firstTxHeight = block.number;
        }
    }

    function swapMini(address factory, address token,uint issueAmount,uint amount) internal {
        uint256 balance0 = IERC20(MINI).balanceOf(address(this));
        (address token0,address token1) = MiniswapV2Library.sortTokens(token,MINI);
        address pair_token_mini = MiniswapV2Library.pairFor(factory,token0,token1);
        (uint amount0Out ,uint amount1Out) = token0==token ? (uint(0),issueAmount):(issueAmount,uint(0));
        TransferHelper.safeTransfer(token,pair_token_mini,amount); //send token to pair
        IMiniswapV2Pair(pair_token_mini).swap(
                amount0Out, amount1Out, address(this), new bytes(0)
            );
        //send half of increment to address0,the other half stays in the contract
        TransferHelper.safeTransfer(MINI,address(0), IERC20(MINI).balanceOf(address(this)).sub(balance0).div(2));
    }

    function issueMini(uint256 issueAmount,address to) internal {
        ///////The 6000 block height is one day, 30 day is one month
        uint durationDay = (block.number.sub(firstTxHeight)).div(6000);
        uint256 issueAmountLimit = MiniswapV2Library.getIssueAmountLimit(durationDay);
        //issue mini to liquilidity && user
        if( mineInfo[durationDay].add(issueAmount).add(issueAmount).sub(issueAmountLimit) > 0){
            issueAmount = issueAmountLimit.sub( mineInfo[durationDay]).div(2);
        }
        if(issueAmount > 0){
            IMini(MINI).issueTo(to,issueAmount);
            IMini(MINI).issueTo(msg.sender,issueAmount);
            mineInfo[durationDay] = mineInfo[durationDay].add(issueAmount).add(issueAmount);
        }
    }

}