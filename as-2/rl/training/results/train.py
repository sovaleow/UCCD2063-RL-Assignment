import asyncio
import csv
import os
import time

import numpy as np

from rl.agents.sarsa import (
    ACTION_NAMES,
    ALPHA,
    GAMMA,
    EPSILON_DECAY,
    EPSILON_MIN,
    EPSILON_START,
    SARSAAgent,
)
from rl.environment.godot_environment import GodotEnvironment


MAX_EPISODES = 450
MAX_STEPS = 500
SAVE_EVERY_N_EPISODES = 10

MODEL_PATH = "results/sarsa_friend_config_q_table.pkl"
LOG_PATH = "results/sarsa_friend_config_training_log.csv"

LOG_COLUMNS = [
    "episode",
    "total_reward",
    "score",
    "apples_collected",
    "episode_length",
    "distance_travelled",
    "episode_time_seconds",
    "epsilon",
    "q_table_size",
    "mean_td_error",
    "completion",
    "reason",
]


def save_results(training_log):
    if not training_log:
        return

    os.makedirs("results", exist_ok=True)

    with open(LOG_PATH, "w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=LOG_COLUMNS)
        writer.writeheader()
        writer.writerows(training_log)


async def train():
    os.makedirs("results", exist_ok=True)

    env = GodotEnvironment()
    await env.connect()

    agent = SARSAAgent(
        n_actions=6,
        alpha=ALPHA,
        gamma=GAMMA,
        epsilon=EPSILON_START,
        epsilon_min=EPSILON_MIN,
        epsilon_decay=EPSILON_DECAY,
    )

    training_log = []

    try:
        for episode in range(1, MAX_EPISODES + 1):
            (
                state,
                _initial_reward,
                done,
                score,
                reason,
            ) = await env.reset()

            action = agent.choose_action(state, explore=True)

            total_reward = 0.0
            steps = 0
            td_errors = []
            distance_travelled = 0.0
            previous_position = None
            start_time = time.perf_counter()

            while not done and steps < MAX_STEPS:
                steps += 1

                (
                    next_state,
                    reward,
                    done,
                    score,
                    reason,
                ) = await env.step(action)

                total_reward += reward

                # Position is not part of the returned transition metadata,
                # so distance is calculated from the state representation.
                # State[0] and state[1] are player x/y divided by 1000.
                current_position = np.array(
                    [float(next_state[0]), float(next_state[1])],
                    dtype=np.float32,
                )

                if previous_position is not None:
                    distance_travelled += float(
                        np.linalg.norm(
                            current_position - previous_position
                        )
                    )

                previous_position = current_position

                steps_reached_limit = steps >= MAX_STEPS and not done

                if steps_reached_limit:
                    done = True
                    reason = "step_limit"

                if not done:
                    next_action = agent.choose_action(
                        next_state,
                        explore=True,
                    )
                else:
                    next_action = 0

                td_error = agent.update(
                    state=state,
                    action=action,
                    reward=reward,
                    next_state=next_state,
                    next_action=next_action,
                    done=done,
                )

                td_errors.append(td_error)

                state = next_state
                score = score

                if not done:
                    action = next_action

                agent.total_steps += 1

            agent.decay_epsilon()

            apples_collected = score // 10

            completion = int(
                reason == "all_apples_collected"
                or score >= 20
            )

            episode_time = time.perf_counter() - start_time
            mean_td_error = (
                float(np.mean(td_errors))
                if td_errors
                else 0.0
            )

            record = {
                "episode": episode,
                "total_reward": total_reward,
                "score": score,
                "apples_collected": apples_collected,
                "episode_length": steps,
                "distance_travelled": distance_travelled,
                "episode_time_seconds": episode_time,
                "epsilon": agent.epsilon,
                "q_table_size": len(agent.q_table),
                "mean_td_error": mean_td_error,
                "completion": completion,
                "reason": reason,
            }

            training_log.append(record)

            print(
                f"Episode {episode}: "
                f"Steps={steps}, "
                f"Reward={total_reward:.2f}, "
                f"Score={score}, "
                f"Apples={apples_collected}, "
                f"Completion={completion}, "
                f"Epsilon={agent.epsilon:.4f}, "
                f"Q-states={len(agent.q_table)}"
            )

            if episode % SAVE_EVERY_N_EPISODES == 0:
                agent.save(MODEL_PATH)
                save_results(training_log)

        agent.save(MODEL_PATH)
        save_results(training_log)

    finally:
        await env.close()

    average_reward = (
        sum(row["total_reward"] for row in training_log)
        / len(training_log)
    )
    average_score = (
        sum(row["score"] for row in training_log)
        / len(training_log)
    )
    average_steps = (
        sum(row["episode_length"] for row in training_log)
        / len(training_log)
    )
    success_count = sum(
        row["completion"] for row in training_log
    )
    success_rate = (
        100.0 * success_count / len(training_log)
    )

    print()
    print("=" * 50)
    print("TRAINING SUMMARY")
    print("=" * 50)
    print(f"Episodes: {len(training_log)}")
    print(f"Average reward: {average_reward:.2f}")
    print(f"Average score: {average_score:.2f}")
    print(f"Average steps: {average_steps:.2f}")
    print(f"Success rate: {success_rate:.2f}%")
    print(f"Q-table saved to: {MODEL_PATH}")
    print(f"Training results saved to: {LOG_PATH}")
    print()
    print("Configuration:")
    print(f"alpha={ALPHA}")
    print(f"gamma={GAMMA}")
    print(f"epsilon_start={EPSILON_START}")
    print(f"epsilon_min={EPSILON_MIN}")
    print(f"epsilon_decay={EPSILON_DECAY}")
    print("valid actions=0,1,2,4,5")


if __name__ == "__main__":
    asyncio.run(train())
