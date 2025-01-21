// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract WithdrawalQueue {

    address public owner;

    /**
     * @dev 提款队列信息
     * @param user              可以领取该队列资产的用户
     * @param token             可以领取的ERC20 Token地址
     * @param amount            金额
     * @param earliestWithdrawal 最早可以提款的时间戳
     * @param claimed           是否已经提款
     * @param claimTime         具体提款时间（0 表示尚未领取）
     */
    struct QueueInfo {
        address user;
        address token;
        uint256 amount;
        uint256 earliestWithdrawal;
        bool claimed;
        uint256 claimTime;
    }

    uint256 public currentQueueId;

    // 队列ID => 队列信息
    mapping(uint256 => QueueInfo) public queues;

    // 统计每个 Token：
    //   totalAdded[token]   = 通过 addWithdrawalQueueBatch() 添加的总量
    //   totalClaimed[token] = 已经被 claim() 领取的总量
    mapping(address => uint256) public totalAdded;
    mapping(address => uint256) public totalClaimed;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        owner = newOwner;
    }

    function addWithdrawalQueueBatch(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata times
    ) external onlyOwner {
        require(
            users.length == tokens.length &&
            tokens.length == amounts.length &&
            amounts.length == times.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < users.length; i++) {
            currentQueueId++;

            queues[currentQueueId] = QueueInfo({
                user: users[i],
                token: tokens[i],
                amount: amounts[i],
                earliestWithdrawal: times[i],
                claimed: false,
                claimTime: 0
            });

            totalAdded[tokens[i]] += amounts[i];
        }
    }

    function claim(uint256 claimId) external {
        QueueInfo storage qInfo = queues[claimId];

        require(qInfo.user == msg.sender, "Not queue user");
        require(block.timestamp >= qInfo.earliestWithdrawal, "Not time to withdraw");
        require(!qInfo.claimed, "Already withdrawn");

        qInfo.claimed = true;
        qInfo.claimTime = block.timestamp;

        totalClaimed[qInfo.token] += qInfo.amount;

        IERC20(qInfo.token).transfer(msg.sender, qInfo.amount);
    }

    function emergencyWithdraw(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Cannot withdraw to zero address");
        IERC20(token).transfer(to, amount);
    }

    /**
     * @dev 获取某个 Token 剩余待领取的数量
     */
    function getUnclaimedAmount(address token) external view returns (uint256) {
        return totalAdded[token] - totalClaimed[token];
    }

    /**
     * @dev 获取某个队列的详细信息
     */
    function getQueueInfo(uint256 claimId) 
        external 
        view 
        returns (
            address user,
            address token,
            uint256 amount,
            uint256 earliestWithdrawal,
            bool claimed,
            uint256 claimTime
        ) 
    {
        QueueInfo storage qInfo = queues[claimId];
        return (
            qInfo.user,
            qInfo.token,
            qInfo.amount,
            qInfo.earliestWithdrawal,
            qInfo.claimed,
            qInfo.claimTime
        );
    }

    function updateQueueInfo(
        uint256 claimId,
        uint256 newAmount,
        uint256 newEarliestWithdrawal
    ) external onlyOwner {
        QueueInfo storage qInfo = queues[claimId];

        require(!qInfo.claimed, "Already claimed. Cannot update claimed record.");

        // 如果金额变动，需要同步更新 totalAdded 统计
        if (newAmount != qInfo.amount) {
            address token = qInfo.token;

            if (newAmount > qInfo.amount) {
                // 增加
                uint256 diff = newAmount - qInfo.amount;
                totalAdded[token] += diff;
            } else {
                // 减少
                uint256 diff = qInfo.amount - newAmount;
                totalAdded[token] -= diff;
            }

            qInfo.amount = newAmount;
        }

        // 更新最早可领取时间
        qInfo.earliestWithdrawal = newEarliestWithdrawal;
    }
}