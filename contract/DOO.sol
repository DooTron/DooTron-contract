pragma solidity ^0.4.22;

import "../node_modules/zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./libs/SafeMath.sol";
import "./Ownable.sol";


contract DOO is ERC20, Ownable {
    using SafeMath for uint256;

    string public constant name = "Dootron";
    string public constant symbol = "DOO";
    uint256 public constant decimals = 6;
    uint256 public constant HARDCAP = 100000000 * (10 ** decimals);

    uint256 public burned;
    mapping(address => uint256) internal balances;
    mapping(address => mapping (address => uint256)) internal allowed;
    uint256 internal totalSupply_;

    event Mine(address indexed user, uint256 amount, address referee);

    constructor () public {
        mint(msg.sender, 40000000 * (10 ** decimals), address(0));
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        return transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        return transfer(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function burn(uint256 _value) public returns (bool) {
        return burn(msg.sender, _value);
    }

    function burnFrom(address _from, uint256 _value) public returns (bool) {
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        return burn(_from, _value);
    }

    function burn(address _from, uint256 _value) internal returns (bool) {
        balances[_from] = balances[_from].sub(_value);
        burned = burned.add(_value);
        return true;
    }

    function transfer(address _from, address _to, uint256 _value) internal returns (bool) {
        require(_to != address(0));

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function mint(address _reciver, uint256 _value, address refernee) internal {
        require(totalSupply_.add(_value) <= HARDCAP);
        totalSupply_ = totalSupply_.add(_value);
        balances[_reciver] = balances[_reciver].add(_value);
        emit Mine(_reciver, _value, refernee);
    }

    function totalSupply() public view returns (uint256) {
        return totalSupply_.sub(burned);
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }
}
