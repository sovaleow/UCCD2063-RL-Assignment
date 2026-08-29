import asyncio
import json
import os

from rl.agents.sarsa import SARSAAgent
from rl.environment.godot_environment import GodotEnvironment


# ============================================================
# CONFIG
# ============================================================

NUM_TEST_EPISODES = 100
MAX_STEPS = 500
NUM_ACTIONS = 6

Q_TABLE_PATH = "30.30% Basic/q_table_basic_improved.json"


# ============================================================
# LOAD Q-TABLE
# ============================================================

def load_q_table(agent: SARSAAgent, path: str) -> None:

    with open(
        path,
        "r",
        encoding="utf-8",
    ) as file:

        data = json.load(file)

    # Convert JSON keys back to strings used by your SARSA state.
    if hasattr(agent, "q_table"):
        agent.q_table = data

    elif hasattr(agent, "Q"):
        agent.Q = data

    else:
        raise AttributeError(
            "SARSAAgent has neither q_table nor Q."
        )


# ============================================================
# GREEDY ACTION
# ============================================================
VALID_ACTIONS = (0, 1, 2, 4, 5)

def greedy_action(
    agent: SARSAAgent,
    state: str,
) -> int:

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

    return max(
        VALID_ACTIONS,
        key=lambda action: q_values[action],
    )

# ============================================================
# TEST
# ============================================================

async def test() -> None:

    print("=" * 60)
    print("SARSA V14 GREEDY EVALUATION")
    print("=" * 60)

    print(
        f"Q-table:       {Q_TABLE_PATH}"
    )

    print(
        f"Episodes:      {NUM_TEST_EPISODES}"
    )

    print(
        f"Max steps:     {MAX_STEPS}"
    )

    print(
        "Exploration:   OFF"
    )

    print()

    # Create agent only as a container for the learned table.
    agent = SARSAAgent(
        n_actions=NUM_ACTIONS,
        alpha=0.15,
        gamma=0.997,
        epsilon=0.0,
        epsilon_min=0.0,
        epsilon_decay=1.0,
    )

    load_q_table(
        agent,
        Q_TABLE_PATH,
    )

    env = GodotEnvironment()

    await env.connect()

    successes = 0
    scores = []
    steps_list = []

    for episode in range(
        1,
        NUM_TEST_EPISODES + 1,
    ):

        (
            state,
            _reward,
            done,
            score,
        ) = await env.reset()

        steps = 0
        total_reward = 0.0

        while (
            not done
            and steps < MAX_STEPS
        ):

            steps += 1

            action = greedy_action(
                agent,
                state,
            )

            (
                next_state,
                reward,
                done,
                score,
            ) = await env.step(
                action
            )

            total_reward += reward
            state = next_state

        if score >= 20:
            successes += 1

        scores.append(score)
        steps_list.append(steps)

        if episode % 10 == 0:

            print(
                f"Episode {episode:3d}/"
                f"{NUM_TEST_EPISODES} | "
                f"Successes: {successes:3d} | "
                f"Current score: {score:2d}"
            )


    # ========================================================
    # SUMMARY
    # ========================================================

    success_rate = (
        successes
        / NUM_TEST_EPISODES
        * 100.0
    )

    average_score = (
        sum(scores)
        / len(scores)
    )

    average_steps = (
        sum(steps_list)
        / len(steps_list)
    )

    zero_apples = sum(
        1
        for score in scores
        if score == 0
    )

    one_apple = sum(
        1
        for score in scores
        if score == 10
    )

    two_apples = sum(
        1
        for score in scores
        if score >= 20
    )

    print()
    print("=" * 60)
    print("GREEDY EVALUATION COMPLETE")
    print("=" * 60)

    print(
        f"0 apples:      "
        f"{zero_apples}/{NUM_TEST_EPISODES}"
    )

    print(
        f"1 apple:       "
        f"{one_apple}/{NUM_TEST_EPISODES}"
    )

    print(
        f"2 apples:      "
        f"{two_apples}/{NUM_TEST_EPISODES}"
    )

    print(
        f"Successes:     "
        f"{successes}/{NUM_TEST_EPISODES}"
    )

    print(
        f"Success rate:  "
        f"{success_rate:.2f}%"
    )

    print(
        f"Average score: "
        f"{average_score:.2f}"
    )

    print(
        f"Average steps: "
        f"{average_steps:.2f}"
    )

    await env.close()


if __name__ == "__main__":
    asyncio.run(test())