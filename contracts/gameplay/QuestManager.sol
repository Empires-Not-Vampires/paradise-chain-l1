// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IParadiseItems.sol";
import "../core/AccessControl.sol";
import "../economy/Treasury.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title QuestManager
 * @notice Quest progress and completion tracking
 * @dev Records quest state and distributes rewards on completion
 */
contract QuestManager is ParadiseAccessControl, Pausable {
    /// @notice The Paradise Items contract
    IParadiseItems public immutable itemsContract;

    /// @notice The Treasury contract for MOANI rewards
    Treasury public immutable treasury;

    /// @notice Quest structure
    struct Quest {
        bool exists;
        uint256 questLineId;
        uint256 questIndex; // Position in quest line
        uint256[] requiredTaskIds;
        uint256[] rewardItemIds;
        uint256[] rewardAmounts;
        uint256 moaniReward; // MOANI reward (18 decimals)
    }

    /// @notice Quest state for a player
    struct QuestState {
        bool started;
        bool completed;
        uint256[] completedTaskIds;
        bool rewardsClaimed;
    }

    /// @notice Quest registry (questId => Quest)
    mapping(uint256 => Quest) private _quests;

    /// @notice Player quest states (player => questId => QuestState)
    mapping(address => mapping(uint256 => QuestState)) private _playerQuestStates;

    /// @notice Emitted when a quest is started
    event QuestStarted(address indexed player, uint256 indexed questId);

    /// @notice Emitted when a task is completed
    event TaskCompleted(address indexed player, uint256 indexed questId, uint256 taskId);

    /// @notice Emitted when a quest is completed
    event QuestCompleted(address indexed player, uint256 indexed questId);

    /// @notice Emitted when quest rewards are claimed
    event QuestRewardsClaimed(
        address indexed player,
        uint256 indexed questId,
        uint256[] itemIds,
        uint256[] amounts,
        uint256 moaniAmount
    );

    /**
     * @notice Constructor
     * @param itemsContract_ The Paradise Items contract address
     * @param treasury_ The Treasury contract address
     */
    constructor(address itemsContract_, address treasury_) ParadiseAccessControl() {
        if (itemsContract_ == address(0) || treasury_ == address(0)) {
            revert("Invalid address");
        }
        itemsContract = IParadiseItems(itemsContract_);
        treasury = Treasury(payable(treasury_));
    }

    /**
     * @notice Register a quest
     * @param questId The quest ID
     * @param questLineId The quest line ID
     * @param questIndex The position in quest line
     * @param requiredTaskIds Array of required task IDs
     * @param rewardItemIds Array of reward item IDs
     * @param rewardAmounts Array of reward amounts
     * @param moaniReward MOANI reward amount (18 decimals)
     * @dev Only callable by admin
     */
    function registerQuest(
        uint256 questId,
        uint256 questLineId,
        uint256 questIndex,
        uint256[] memory requiredTaskIds,
        uint256[] memory rewardItemIds,
        uint256[] memory rewardAmounts,
        uint256 moaniReward
    ) external onlyRole(ADMIN_ROLE) {
        if (_quests[questId].exists) {
            revert("Quest already exists");
        }
        if (requiredTaskIds.length == 0) {
            revert("No tasks");
        }
        if (rewardItemIds.length != rewardAmounts.length) {
            revert("Reward array mismatch");
        }

        _quests[questId] = Quest({
            exists: true,
            questLineId: questLineId,
            questIndex: questIndex,
            requiredTaskIds: requiredTaskIds,
            rewardItemIds: rewardItemIds,
            rewardAmounts: rewardAmounts,
            moaniReward: moaniReward
        });
    }

    /**
     * @notice Start a quest for a player
     * @param player The player address
     * @param questId The quest ID
     * @dev Only callable by authorized game contracts
     */
    function startQuest(address player, uint256 questId)
        external
        onlyRole(GAME_CONTRACT_ROLE)
        whenNotPaused
    {
        if (player == address(0)) {
            revert("Invalid player");
        }
        if (!_quests[questId].exists) {
            revert("Quest does not exist");
        }

        QuestState storage state = _playerQuestStates[player][questId];
        if (state.started) {
            revert("Quest already started");
        }

        state.started = true;
        emit QuestStarted(player, questId);
    }

    /**
     * @notice Complete a task (called by server after validation)
     * @param player The player address
     * @param questId The quest ID
     * @param taskId The completed task ID
     * @dev Only callable by authorized game contracts
     */
    function completeTask(address player, uint256 questId, uint256 taskId)
        external
        onlyRole(GAME_CONTRACT_ROLE)
        whenNotPaused
    {
        QuestState storage state = _playerQuestStates[player][questId];
        if (!state.started) {
            revert("Quest not started");
        }
        if (state.completed) {
            revert("Quest already completed");
        }

        // Check if task is already completed
        for (uint256 i = 0; i < state.completedTaskIds.length; i++) {
            if (state.completedTaskIds[i] == taskId) {
                revert("Task already completed");
            }
        }

        // Verify task is required for this quest
        Quest memory quest = _quests[questId];
        bool taskRequired = false;
        for (uint256 i = 0; i < quest.requiredTaskIds.length; i++) {
            if (quest.requiredTaskIds[i] == taskId) {
                taskRequired = true;
                break;
            }
        }
        if (!taskRequired) {
            revert("Task not required");
        }

        state.completedTaskIds.push(taskId);
        emit TaskCompleted(player, questId, taskId);

        // Check if all tasks are completed
        if (state.completedTaskIds.length == quest.requiredTaskIds.length) {
            state.completed = true;
            emit QuestCompleted(player, questId);
        }
    }

    /**
     * @notice Claim quest rewards
     * @param questId The quest ID
     */
    function claimRewards(uint256 questId) external whenNotPaused {
        QuestState storage state = _playerQuestStates[msg.sender][questId];
        if (!state.completed) {
            revert("Quest not completed");
        }
        if (state.rewardsClaimed) {
            revert("Rewards already claimed");
        }

        Quest memory quest = _quests[questId];
        state.rewardsClaimed = true;

        // Mint item rewards
        if (quest.rewardItemIds.length > 0) {
            itemsContract.mintBatch(
                msg.sender,
                quest.rewardItemIds,
                quest.rewardAmounts,
                ""
            );
        }

        // Distribute MOANI reward
        if (quest.moaniReward > 0) {
            treasury.distributeRewards(msg.sender, quest.moaniReward, "QUEST_REWARD");
        }

        emit QuestRewardsClaimed(
            msg.sender,
            questId,
            quest.rewardItemIds,
            quest.rewardAmounts,
            quest.moaniReward
        );
    }

    /**
     * @notice Get quest details
     * @param questId The quest ID
     * @return The quest structure
     */
    function getQuest(uint256 questId) external view returns (Quest memory) {
        return _quests[questId];
    }

    /**
     * @notice Get player quest state
     * @param player The player address
     * @param questId The quest ID
     * @return The quest state
     */
    function getPlayerQuestState(address player, uint256 questId)
        external
        view
        returns (QuestState memory)
    {
        return _playerQuestStates[player][questId];
    }

    /**
     * @notice Pause quest system (emergency only)
     * @dev Only callable by admin
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause quest system
     * @dev Only callable by admin
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
