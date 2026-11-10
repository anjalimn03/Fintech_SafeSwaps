// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * CROSS-CHAIN ATOMIC SETTLEMENT (DvP) FOR TOKENIZED ASSETS
 * --------------------------------------------------------
 * Two contracts live in this file:
 *
 *   1. TestToken      - a simple practice token with a free "mint" button.
 *                       Used as the tokenized ASSET on Network A and as the
 *                       PAYMENT token on Network B.
 *
 *   2. DvPSettlement  - the escrow. Deploy the SAME contract on BOTH networks.
 *                       It uses a hashed timelock:
 *                         - Seller locks the asset on Network A.
 *                         - Buyer locks the payment on Network B.
 *                         - Seller reveals a secret to take the payment.
 *                         - That same secret lets the buyer take the asset.
 *                         - If someone disappears, the deadline passes and
 *                           each side can get their own tokens back.
 *                       So delivery and payment happen together or not at all.
 *
 * HOW TO DEPLOY IN REMIX (see README.md for the full walk-through)
 *   Network A: deploy TestToken("Tokenized Bond","TBOND")  + DvPSettlement
 *   Network B: deploy TestToken("Payment Dollar","PUSD")   + DvPSettlement
 */

// ---------------------------------------------------------------------------
// Minimal token interface used by the settlement contract
// ---------------------------------------------------------------------------
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// ---------------------------------------------------------------------------
// 1. Practice token (ERC-20 style) - anyone can mint test tokens for themselves
// ---------------------------------------------------------------------------
contract TestToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    // Free test-token faucet (max 1,000,000 tokens per call)
    function mint(uint256 amount) external {
        require(amount <= 1_000_000 ether, "Too many tokens at once");
        totalSupply += amount;
        balanceOf[msg.sender] += amount;
        emit Transfer(address(0), msg.sender, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "Not approved for this amount");
        allowance[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "Invalid address");
        require(balanceOf[from] >= amount, "Not enough tokens");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
