// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DvPSettlement {
    enum Status { None, Locked, Claimed, Refunded }

    struct Swap {
        address sender;
        address receiver;
        address token;
        uint256 amount;
        uint256 expiry;
        Status status;
        bytes32 secret;
    }

    mapping(bytes32 => Swap) public swaps;
    mapping(address => bytes32[]) private userSwaps;

    event Locked(bytes32 indexed tradeId, address indexed sender, address indexed receiver, address token, uint256 amount, uint256 expiry);
    event Claimed(bytes32 indexed tradeId, address indexed receiver, bytes32 secret);
    event Refunded(bytes32 indexed tradeId, address indexed sender);

    function lock(
        bytes32 tradeId,
        address receiver,
        address token,
        uint256 amount,
        uint256 durationSeconds
    ) external {
        require(swaps[tradeId].status == Status.None, "Trade ID already used");
        require(receiver != address(0) && token != address(0), "Invalid address");
        require(amount > 0, "Amount must be above zero");
        require(durationSeconds >= 60 && durationSeconds <= 30 days, "Deadline must be 1 minute to 30 days");

        uint256 expiry = block.timestamp + durationSeconds;

        swaps[tradeId] = Swap(msg.sender, receiver, token, amount, expiry, Status.Locked, bytes32(0));
        userSwaps[msg.sender].push(tradeId);
        if (receiver != msg.sender) userSwaps[receiver].push(tradeId);

        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        emit Locked(tradeId, msg.sender, receiver, token, amount, expiry);
    }

    function claim(bytes32 tradeId, bytes32 secret) external {
        Swap storage s = swaps[tradeId];
        require(s.status == Status.Locked, "Trade is not open");
        require(block.timestamp < s.expiry, "Deadline has passed");
        require(sha256(abi.encodePacked(secret)) == tradeId, "Wrong secret");

        s.status = Status.Claimed;
        s.secret = secret;

        require(IERC20(s.token).transfer(s.receiver, s.amount), "Token transfer failed");
        emit Claimed(tradeId, s.receiver, secret);
    }

    function refund(bytes32 tradeId) external {
        Swap storage s = swaps[tradeId];
        require(s.status == Status.Locked, "Trade is not open");
        require(block.timestamp >= s.expiry, "Deadline not reached yet");

        s.status = Status.Refunded;

        require(IERC20(s.token).transfer(s.sender, s.amount), "Token transfer failed");
        emit Refunded(tradeId, s.sender);
    }

    function getUserSwaps(address user) external view returns (bytes32[] memory) {
        return userSwaps[user];
    }
}
