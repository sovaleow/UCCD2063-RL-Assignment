from rl.agents.sarsa import SARSAAgent


def main():
    agent = SARSAAgent(
        learning_rate=0.1,
        discount_factor=0.9,
        epsilon=1.0,
        epsilon_decay=0.995,
        epsilon_min=0.05,
        num_actions=5,
    )

    # Example states
    state = "2,2,1,0,1,1"
    next_state = "2,1,1,0,1,1"

    # Choose an action
    action = agent.choose_action(state)

    print("Initial action:", action)
    print("Initial Q-table:", agent.q_table)

    # Choose next action — this is important for SARSA
    next_action = agent.choose_action(next_state)

    # Simulate a reward
    reward = -0.01
    done = False

    # Perform SARSA update
    agent.update(
        state=state,
        action=action,
        reward=reward,
        next_state=next_state,
        next_action=next_action,
        done=done,
    )

    print()
    print("Next action:", next_action)
    print("Reward:", reward)
    print("Updated Q-table:", agent.q_table)

    # Test epsilon decay
    old_epsilon = agent.epsilon

    agent.decay_epsilon()

    print()
    print("Epsilon before decay:", old_epsilon)
    print("Epsilon after decay:", agent.epsilon)


if __name__ == "__main__":
    main()