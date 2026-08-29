
import asyncio
import csv
import json
import os
import random

from rl.agents.sarsa_advanced import SARSAAgent
from rl.environment.godot_environment import GodotEnvironment


NUM_EPISODES = 1000
MAX_STEPS = 450

LEARNING_RATE = 0.15
DISCOUNT_FACTOR = 0.997

EPSILON_START = 0.35
EPSILON_MIN = 0.06
EPSILON_DECAY = 0.999

NUM_ACTIONS = 6

RESULTS_DIR = "results_advanced_sarsa_v3"

Q_TABLE_PATH = os.path.join(
    RESULTS_DIR,
    "q_table_advanced_sarsa_v3.json",
)

TRAINING_RESULTS_PATH = os.path.join(
    RESULTS_DIR,
    "training_results_advanced_sarsa_v3.csv",
)

SEED = 43


async def train() -> None:
    random.seed(SEED)

    os.makedirs(
        RESULTS_DIR,
        exist_ok=True,
    )

    print("=" * 65)
    print("ADVANCED TABULAR SARSA")
    print("=" * 65)
    print("Episodes:         ", NUM_EPISODES)
    print("Max steps:        ", MAX_STEPS)
    print("Alpha:             ", LEARNING_RATE)
    print("Gamma:             ", DISCOUNT_FACTOR)
    print("Epsilon start:     ", EPSILON_START)
    print("Epsilon minimum:  ", EPSILON_MIN)
    print()
    print("Route: Apple 1 -> Apple 2 -> Apple 3")
    print("Target: remaining apple relative position")
    print("State: compact")
    print("Exploration: epsilon-greedy")
    print()

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

    results = []

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
        best_score = 0

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

            best_score = max(
                best_score,
                score,
            )

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

        two_success = (
            1 if best_score >= 20 else 0
        )

        three_success = (
            1 if best_score >= 30 else 0
        )

        agent.record_success(
            three_success == 1
        )

        agent.end_episode()

        results.append(
            {
                "episode": episode,
                "steps": steps,
                "reward": total_reward,
                "score": best_score,
                "apples": min(
                    3,
                    best_score // 10,
                ),
                "two_apple_success": two_success,
                "three_apple_success": three_success,
                "epsilon": agent.epsilon,
                "entropy": agent.policy_entropy(),
                "truncated": int(truncated),
            }
        )

        if episode % 50 == 0:
            recent = results[-50:]

            zero = sum(
                1
                for row in recent
                if row["apples"] == 0
            )

            one = sum(
                1
                for row in recent
                if row["apples"] == 1
            )

            two = sum(
                1
                for row in recent
                if row["apples"] == 2
            )

            three = sum(
                1
                for row in recent
                if row["apples"] == 3
            )

            two_rate = (
                sum(
                    row["two_apple_success"]
                    for row in recent
                )
                / 50.0
                * 100.0
            )

            three_rate = (
                sum(
                    row["three_apple_success"]
                    for row in recent
                )
                / 50.0
                * 100.0
            )

            print()
            print(
                f"--- Last 50 episodes "
                f"({episode}) ---"
            )
            print(f"0 apples:       {zero:2d}/50")
            print(f"1 apple:        {one:2d}/50")
            print(f"2 apples:       {two:2d}/50")
            print(f"3 apples:       {three:2d}/50")
            print(f"2-apple rate:   {two_rate:5.1f}%")
            print(f"3-apple rate:   {three_rate:5.1f}%")
            print(
                f"Epsilon:        "
                f"{agent.epsilon:.4f}"
            )
            print(
                f"Policy entropy: "
                f"{agent.policy_entropy():.4f}"
            )
            print(
                f"Q-table states: "
                f"{len(agent.Q)}"
            )

            if two_rate >= 90.0:
                print(
                    ">>> 90% 2-APPLE MILESTONE <<<"
                )

            if three_rate >= 90.0:
                print(
                    ">>> 90% 3-APPLE COMPLETION <<<"
                )

    with open(
        Q_TABLE_PATH,
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(
            {
                str(state): values
                for state, values in agent.Q.items()
            },
            file,
            indent=2,
        )

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
                "reward",
                "score",
                "apples",
                "two_apple_success",
                "three_apple_success",
                "epsilon",
                "entropy",
                "truncated",
            ],
        )

        writer.writeheader()
        writer.writerows(results)

    overall_two = (
        sum(
            row["two_apple_success"]
            for row in results
        )
        / len(results)
        * 100.0
    )

    overall_three = (
        sum(
            row["three_apple_success"]
            for row in results
        )
        / len(results)
        * 100.0
    )

    final = results[-50:]

    final_two = (
        sum(
            row["two_apple_success"]
            for row in final
        )
        / 50.0
        * 100.0
    )

    final_three = (
        sum(
            row["three_apple_success"]
            for row in final
        )
        / 50.0
        * 100.0
    )

    print()
    print("=" * 65)
    print("ADVANCED SARSA TRAINING COMPLETE")
    print("=" * 65)
    print(
        f"Overall 2-apple rate: "
        f"{overall_two:.2f}%"
    )
    print(
        f"Final 50 2-apple rate: "
        f"{final_two:.2f}%"
    )
    print(
        f"Overall 3-apple rate: "
        f"{overall_three:.2f}%"
    )
    print(
        f"Final 50 3-apple rate: "
        f"{final_three:.2f}%"
    )
    print(
        f"Final epsilon: "
        f"{agent.epsilon:.4f}"
    )
    print(
        f"Q-table states: "
        f"{len(agent.Q)}"
    )
    print(
        f"Q-table saved: "
        f"{Q_TABLE_PATH}"
    )
    print(
        f"Results saved: "
        f"{TRAINING_RESULTS_PATH}"
    )

    await env.close()


if __name__ == "__main__":
    asyncio.run(train())
