import asyncio
import csv
import json
import os
import random

from rl.agents.sarsa import SARSAAgent
from rl.environment.godot_environment import GodotEnvironment


# ============================================================
# TRAINING CONFIGURATION
# ============================================================
# These settings are informed by the successful SARSA setup
# you showed me, but this file keeps YOUR SARSA implementation
# and API.
# ============================================================

NUM_EPISODES = 2000
MAX_STEPS = 500

LEARNING_RATE = 0.15
DISCOUNT_FACTOR = 0.997

EPSILON_START = 0.35
EPSILON_DECAY = 0.999
EPSILON_MIN = 0.06

NUM_ACTIONS = 6

RESULTS_DIR = "results_basic_improved"

Q_TABLE_PATH = os.path.join(
    RESULTS_DIR,
    "q_table_basic_improved.json",
)

TRAINING_RESULTS_PATH = os.path.join(
    RESULTS_DIR,
    "training_results_basic_improved.csv",
)

SEED = 43


# ============================================================
# DO NOT CHANGE THE USER'S SARSA ACTION API.
# These are the actions used by the existing Godot player.
# ============================================================

ACTION_NAMES = {
    0: "idle",
    1: "left",
    2: "right",
    3: "jump",
    4: "left+jump",
    5: "right+jump",
}


# ============================================================
# TRAINING
# ============================================================

async def train() -> None:

    random.seed(SEED)

    os.makedirs(
        RESULTS_DIR,
        exist_ok=True,
    )

    env = GodotEnvironment()

    await env.connect()


    agent = SARSAAgent(
        n_actions=NUM_ACTIONS,
        alpha=LEARNING_RATE,
        gamma=DISCOUNT_FACTOR,
        epsilon=EPSILON_START,
        epsilon_min=EPSILON_MIN,
        epsilon_decay=EPSILON_DECAY,
    )

    training_results = []

    print("=" * 60)
    print("SARSA BASIC IMPROVED TRAINING")
    print("=" * 60)
    print(f"Seed:             {SEED}")
    print(f"Episodes:         {NUM_EPISODES}")
    print("Objective:        Collect 2 apples")
    print(f"Alpha:            {LEARNING_RATE}")
    print(f"Gamma:            {DISCOUNT_FACTOR}")
    print(f"Epsilon:          {EPSILON_START}")
    print(f"Epsilon min:      {EPSILON_MIN}")
    print(f"Epsilon decay:    {EPSILON_DECAY}")
    print(f"Max steps:        {MAX_STEPS}")
    print()

    for episode in range(
        1,
        NUM_EPISODES + 1,
    ):

        state, reward, done, score = (
            await env.reset()
        )

        action = agent.act(
            state,
            explore=True,
        )

        total_reward = 0.0
        steps = 0

        while (
            not done
            and steps < MAX_STEPS
        ):

            steps += 1

            (
                next_state,
                reward,
                done,
                score,
            ) = await env.step(action)

            total_reward += reward

            if done:

                next_action = None

            else:

                next_action = agent.act(
                    next_state,
                    explore=True,
                )

            agent.update(
                state,
                action,
                reward,
                next_state,
                next_action,
                done,
            )

            state = next_state

            if not done:
                action = next_action

        truncated = (
            steps >= MAX_STEPS
            and not done
        )

        # End the episode through the user's actual SARSA API.
        # This is also where epsilon decay is handled by that class.
        agent.end_episode()

        # Basic scene objective: collect 2 apples.
        # The environment uses score 10 per collected apple.
        success = (
            1
            if score >= 20
            else 0
        )

        training_results.append({
            "episode": episode,
            "steps": steps,
            "total_reward": total_reward,
            "score": score,
            "success": success,
            "epsilon": agent.epsilon,
            "truncated": int(truncated),
        })

        if episode % 50 == 0:

            recent = training_results[-50:]

            zero_apples = sum(
                1
                for row in recent
                if row["score"] < 10
            )

            one_apple = sum(
                1
                for row in recent
                if row["score"] == 10
            )

            two_apples = sum(
                1
                for row in recent
                if row["score"] >= 20
            )

            recent_success = (
                sum(
                    row["success"]
                    for row in recent
                )
                / len(recent)
                * 100.0
            )

            print()
            print(
                f"--- Last 50 episodes "
                f"({episode}) ---"
            )

            print(
                f"0 apples:       "
                f"{zero_apples:2d}/50"
            )

            print(
                f"1 apple:        "
                f"{one_apple:2d}/50"
            )

            print(
                f"2 apples:       "
                f"{two_apples:2d}/50"
            )

            print(
                f"Objective:      "
                f"2 apples"
            )

            print(
                f"Success:        "
                f"{recent_success:5.1f}%"
            )

            print(
                f"Q-table states: "
                f"{len(agent.Q)}"
            )

            print(
                f"Epsilon:        "
                f"{agent.epsilon:.3f}"
            )

    # ========================================================
    # SAVE Q-TABLE
    # ========================================================

    serializable_q = {
        str(state): values
        for state, values in agent.Q.items()
    }

    with open(
        Q_TABLE_PATH,
        "w",
        encoding="utf-8",
    ) as file:

        json.dump(
            serializable_q,
            file,
            indent=2,
        )

    # ========================================================
    # SAVE RESULTS
    # ========================================================

    with open(
        TRAINING_RESULTS_PATH,
        "w",
        newline="",
        encoding="utf-8",
    ) as file:

        writer = csv.DictWriter(
            file,
            fieldnames=[
                "episode",
                "steps",
                "total_reward",
                "score",
                "success",
                "epsilon",
                "truncated",
            ],
        )

        writer.writeheader()

        writer.writerows(
            training_results
        )

    # ========================================================
    # SUMMARY
    # ========================================================

    success_rate = (
        sum(
            row["success"]
            for row in training_results
        )
        / len(training_results)
        * 100.0
    )

    final_50 = training_results[-50:]

    final_success = (
        sum(
            row["success"]
            for row in final_50
        )
        / len(final_50)
        * 100.0
    )

    print()
    print("=" * 60)
    print("SARSA BASIC TRAINING COMPLETE")
    print("=" * 60)

    print(
        f"Overall success: "
        f"{success_rate:.2f}%"
    )

    print(
        f"Final 50:        "
        f"{final_success:.2f}%"
    )

    print(
        f"Q-table states:  "
        f"{len(agent.Q)}"
    )

    print(
        f"Q-table saved:   "
        f"{Q_TABLE_PATH}"
    )

    print(
        f"Results saved:   "
        f"{TRAINING_RESULTS_PATH}"
    )

    await env.close()


if __name__ == "__main__":
    asyncio.run(train())
