pragma solidity ^0.4.22;

import "./DOO.sol";
import "../node_modules/zeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract Dootron is DOO {
    uint256 constant internal magnitude = 2 ** 64;

    mapping (address => bool) public games;

    mapping (address => uint256) public frozenBalances;
    mapping (address => uint256) public unfreezingBalances;
    mapping (address => uint256) public unfreezingUntil;
    mapping (address => address) public payoutAddress;
    mapping (address => mapping (address => uint256)) public payout;
    mapping (address => uint256) public pendingDividends;
    mapping (address => uint256) public principal;
    mapping (address => uint256) private profitPerShare;
    mapping (address => uint256) public tokenRatio;
    mapping (uint256 => address) public tokenId2Address;
    mapping (address => uint256) public totalPayoutDividends;
    mapping (address => uint256) public gameMiningEfficiency;
    mapping (address => bool) public isAdmin;

    uint256 public totalFrozenBalances;
    uint256 public unfreezingPeriod = 1 days;
    uint256 public tokenCount = 1;

    event Freeze(address indexed user, uint256 amount);
    event Unfreeze(address indexed user, uint256 amount);
    event DeclareDividends(address indexed token, uint256 amount, uint256 totalFrozenBalances);
    event WithdrawDividends(address indexed user, address indexed token, uint256 amount);

    modifier onlyGames() {
        require(games[msg.sender]);
        _;
    }

    constructor() public {
        tokenId2Address[0] = address(0);
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender] || msg.sender == owner);
        _;
    }

    // only Owner
    function addGame(address _game, bool isGame) external onlyOwner {
        games[_game] = isGame;
    }

    function addToken(address _token) external onlyOwner {
        tokenId2Address[tokenCount] = _token;
        tokenCount++;
    }

    function setUnfreezingPeriod(uint256 _numberOfDays) external onlyOwner {
        unfreezingPeriod = _numberOfDays * 1 days;
    }

    function setGameMiningEfficency(address _game, uint256 _rate) external onlyOwner {
        require(games[_game]);
        gameMiningEfficiency[_game] = _rate;
    }

    function declareDividends() external onlyAdmin {
        for (uint256 i = 0; i < tokenCount; ++i) {
            address token = tokenId2Address[i];
            if (availableBalance(token) > principal[token]) {
                uint256 dividends = availableBalance(token) - principal[token];
                profitPerShare[token] += dividends * magnitude / totalFrozenBalances;
                pendingDividends[token] += dividends;
                totalPayoutDividends[token] += dividends;
                emit DeclareDividends(token, dividends, totalFrozenBalances);
            }
        }
    }

    function setAdmin(address _user, bool _isAdmin) external onlyOwner {
        isAdmin[_user] = _isAdmin;
    }

    function withdrawPrincipal(address token, uint256 _amount) external onlyOwner {
        require(_amount <= principal[token]);
        principal[token] -= _amount;
        if (token == address(0)) {
            owner.transfer(_amount);
        } else {
            ERC20(token).transfer(owner, _amount);
        }
    }

    function setTokenRatio(address token, uint256 _tokenRatio) external onlyOwner {
        tokenRatio[token] = _tokenRatio;
    }
    // end of only owner

    // onlyGames (trx)
    function bet_6Ew(address _player, address _referrer) external payable onlyGames {
        mine(_player, _referrer, msg.value);
    }

    // token
    function betToken_B17(address _player, address _referrer, address _token, uint256 amount) external onlyGames {
        require(principal[_token] > 0);
        require(ERC20(_token).transferFrom(_player, this, amount));
        mine(_player, _referrer, amount * tokenRatio[_token] / 1000000);
    }

    function mine_r5F(address _player, address _referrer, address _token, uint256 amount) external onlyGames {
        require(principal[_token] > 0);
        mine(_player, _referrer, amount * tokenRatio[_token] / 1000000);
    }

    function payOut_IoB(address _player, address _token, uint256 amount) external onlyGames {
        require(availableBalance(_token) >= amount);
        if (_token == address(0)) {
            _player.transfer(amount);
        } else {
            ERC20(_token).transfer(_player, amount);
        }
    }

    // helper
    function balanceOf(address _owner) public view returns (uint256) { //override
        if (unfreezingBalances[_owner] > 0 && now > unfreezingUntil[_owner]) {
            return unfreezingBalances[_owner] + balances[_owner];
        }
        return balances[_owner];
    }

    function unfreezingBalanceOf(address _owner) external view returns (uint256) {
        return unfreezingBalances[_owner] > 0 && now <= unfreezingUntil[_owner] ? unfreezingBalances[_owner] : 0;
    }

    function dividendOf(address _token, address _user) public view returns (uint256) {
        return (profitPerShare[_token] * frozenBalances[_user] - payout[address(_token)][_user]) / magnitude;
    }
    // end of helper

    // public
    function () external payable {
        principal[address(0)] += msg.value;
    }

    function depositPrincipal() external payable {
        principal[address(0)] += msg.value;
    }

    function depositTokenPrincipal(address token, uint256 amount) external {
        require(ERC20(token).transferFrom(msg.sender, this, amount));
        principal[token] += amount;
    }

    function freeze(uint256 _amount) external {
        require(_amount <= balanceOf(msg.sender));
        flushUnfreezingBalance(msg.sender);
        balances[msg.sender] -= _amount;
        frozenBalances[msg.sender] += _amount;
        for (uint256 i = 0; i < tokenCount; ++i) {
            payout[tokenId2Address[i]][msg.sender] += _amount * profitPerShare[tokenId2Address[i]];
        }
        totalFrozenBalances += _amount;
        emit Freeze(msg.sender, _amount);
    }

    function unfreeze(uint256 _amount) external {
        require(frozenBalances[msg.sender] >= _amount);
        flushUnfreezingBalance(msg.sender);
        for (uint256 i = 0; i < tokenCount; ++i) {
            withdrawDividends(tokenId2Address[i], msg.sender);
            payout[tokenId2Address[i]][msg.sender] -= _amount * profitPerShare[tokenId2Address[i]];
        }
        frozenBalances[msg.sender] -= _amount;
        totalFrozenBalances -= _amount;
        unfreezingBalances[msg.sender] += _amount;
        unfreezingUntil[msg.sender] = now + unfreezingPeriod;
        emit Unfreeze(msg.sender, _amount);
    }

    function setPayoutAddress(address _addr) external {
        payoutAddress[msg.sender] = _addr;
    }

    function withdrawDividends(address _token) external {
        withdrawDividends(_token, msg.sender);
    }

    function availableBalance(address token) public view returns(uint256) {
        if (token == address(0)) {
            return address(this).balance - pendingDividends[address(0)];
        } else {
            return ERC20(token).balanceOf(this) - pendingDividends[token];
        }
    }
    // end of public

    // internal
    function withdrawDividends(address _token, address _user) internal {
        uint256 dividend = dividendOf(_token, _user);
        if (dividend > 0) {
            address payoutTo = payoutAddress[_user] == address(0) ? _user : payoutAddress[_user];
            payout[_token][_user] += dividend * magnitude;
            pendingDividends[_token] -= dividend;
            if (_token == address(0)) {
                payoutTo.transfer(dividend);
            } else {
                ERC20(_token).transfer(payoutTo, dividend);
            }
            emit WithdrawDividends(_token, payoutTo, dividend);
        }
    }

    function flushUnfreezingBalance(address user) internal {
        uint256 amount = unfreezingBalances[user];
        if (amount > 0 && now > unfreezingUntil[user]) {
            balances[user] += amount;
            unfreezingBalances[user] = 0;
        }
    }

    function transfer(address _from, address _to, uint256 _value) internal returns (bool) { //override
        require(balanceOf(_from) >= _value);
        flushUnfreezingBalance(_from);
        return super.transfer(_from, _to, _value);
    }

    function mine(address _player, address _referrer, uint256 _amount) internal {
        if (totalSupply_ == HARDCAP || _amount == 0) {
            return;
        }
        if (gameMiningEfficiency[msg.sender] != 0) {
            _amount = _amount * gameMiningEfficiency[msg.sender] / 10000;
        }
        uint256 level = totalSupply_ / 1000000000000 * 1000000000000;
        uint256 tokenAmount = _amount * 1250000000000 / (level + 10000000000000);
        mint(_player, getMineAmount(tokenAmount), address(0));
        if (_referrer != address(0) && _referrer != _player && totalSupply_ < HARDCAP) {
            mint(_referrer, getMineAmount(tokenAmount * 15 / 100), _player);
        }
    }

    function getMineAmount(uint256 amount) internal view returns (uint256) {
        return totalSupply_.add(amount) < HARDCAP ? amount : HARDCAP - totalSupply_;
    }
}
