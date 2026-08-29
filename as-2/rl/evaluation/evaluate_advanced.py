import asyncio
import json
import os

from rl.agents.sarsa_advanced import SARSAAgent
from rl.environment.godot_environment import GodotEnvironment


NUM_TEST_EPISODES = 100
MAX_STEPS = 450
NUM_ACTIONS = 6

Q_TABLE_PATH = "50.20% 26% Advanced/q_table_advanced_sarsa_v3.json"

VALID_ACTIONS = (0, 1, 2, 4, 5)


def load_q_table(agent: SARSAAgent, path: str) -> None:
    with open(path, "r", encoding="utf-8") as file:
        data = json.load(file)

    if hasattr(agent, "Q"):
        agent.Q = data
    elif hasattr(agent, "q_table"):
        agent.q_table = data
    else:
        raise AttributeError(
            "SARSAAgent has neither Q nor q_table."
        )


def greedy_action(agent: SARSAAgent, state: str) -> int:
    if hasattr(agent, "Q"):
        q_values = agent.Q.get(
            state,
            [0.0] * NUM_ACTIONS,
        )
    elif hasattr(agent, "q_table"):
        q_values = agent.q_table.get(
            state,
            [0.0] * NUM_ACTIONS,
        )
    else:
        raise AttributeError(
            "SARSAAgent has neither Q nor q_table."
        )

    # Same selectable actions used during Advanced SARSA training.
    # Lowest action ID is selected deterministically if Q-values tie.
    best_value = max(
        q_values[action]
        for action in VALID_ACTIONS
    )

    return min(
        action
        for action in VALID_ACTIONS
        if q_values[action] == best_value
    )


async def test() -> None:
    print("=" * 65)
    print("ADVANCED SARSA GREEDY EVALUATION")
    print("=" * 65)
    print(f"Q-table:       {Q_TABLE_PATH}")
    print(f"Episodes:      {NUM_TEST_EPISODES}")
    print(f"Max steps:     {MAX_STEPS}")
    print("Exploration:   OFF")
    print("Objective:     Collect all 3 apples")
    print()

    if not os.path.exists(Q_TABLE_PATH):
        raise FileNotFoundError(
            f"Q-table not found: {Q_TABLE_PATH}"
        )

    agent = SARSAAgent(
        n_actions=NUM_ACTIONS,
        alpha=0.15,
        gamma=0.997,
        epsilon=0.00,
        epsilon_min=0.0,
        epsilon_decay=1.0,
    )

    load_q_table(agent, Q_TABLE_PATH)

    env = GodotEnvironment()
    await env.connect()

    zero_apples = 0
    one_apple = 0
    two_apples = 0
    three_apples = 0

    scores = []
    steps_list = []

    for episode in range(1, NUM_TEST_EPISODES + 1):
        state, _reward, done, score = await env.reset()

        steps = 0
        best_score = score

        while not done and steps < MAX_STEPS:
            steps += 1

            action = greedy_action(
                agent,
                state,
            )

            next_state, _reward, done, score = (
                await env.step(action)
            )

            state = next_state
            best_score = max(best_score, score)

        # Advanced environment scoring:
        # 0 = 0 apples, 10 = 1, 20 = 2, 30 = 3.
        apple_count = min(3, best_score // 10)

        if apple_count == 0:
            zero_apples += 1
        elif apple_count == 1:
            one_apple += 1
        elif apple_count == 2:
            two_apples += 1
        else:
            three_apples += 1

        scores.append(best_score)
        steps_list.append(steps)

        if episode % 10 == 0:
            print(
                f"Episode {episode:3d}/{NUM_TEST_EPISODES} | "
                f"0:{zero_apples:3d} "
                f"1:{one_apple:3d} "
                f"2:{two_apples:3d} "
                f"3:{three_apples:3d}"
            )

    two_or_more = two_apples + three_apples

    success_rate_2plus = (
        two_or_more / NUM_TEST_EPISODES * 100.0
    )

    success_rate_3 = (
        three_apples / NUM_TEST_EPISODES * 100.0
    )

    average_score = sum(scores) / len(scores)
    average_steps = sum(steps_list) / len(steps_list)

    print()
    print("=" * 65)
    print("ADVANCED GREEDY EVALUATION COMPLETE")
    print("=" * 65)
    print(
        f"0 apples:          "
        f"{zero_apples}/{NUM_TEST_EPISODES}"
    )
    print(
        f"1 apple:           "
        f"{one_apple}/{NUM_TEST_EPISODES}"
    )
    print(
        f"2 apples:          "
        f"{two_apples}/{NUM_TEST_EPISODES}"
    )
    print(
        f"3 apples:          "
        f"{three_apples}/{NUM_TEST_EPISODES}"
    )
    print(
        f"2+ apple rate:     "
        f"{success_rate_2plus:.2f}%"
    )
    print(
        f"3-apple success:   "
        f"{success_rate_3:.2f}%"
    )
    print(
        f"Average score:     "
        f"{average_score:.2f}"
    )
    print(
        f"Average steps:     "
        f"{average_steps:.2f}"
    )

    await env.close()


if __name__ == "__main__":
    asyncio.run(test())
