"""
RL Evaluation Script — Evaluates a trained Q-Learning agent with a greedy policy.

Usage:
  1. Open the Godot project and run the game (it starts an RL server on port 9080)
  2. Run:  python evaluate.py

Loads qtable.pkl, runs 50 episodes with epsilon=0 (pure exploitation),
never updates the Q-table during evaluation, and prints a summary table
of performance at the end.
"""
from environment import GodotEnv
from q_learning import QLearning
from config import LEARNING_RATE, DISCOUNT_FACTOR, MAX_STEPS

import os
import sys

NUM_EVAL_EPISODES = 50


def main():
    # --- Connect to Godot ---
    print("=" * 60)
    print("Evaluating Trained Agent (epsilon=0, greedy policy)")
    print("=" * 60)

    env = GodotEnv()
    if not env.connect():
        print("\nCannot connect to Godot. Run the game first (F5 in Godot).")
        sys.exit(1)

    # --- Load trained Q-table ---
    agent = QLearning(LEARNING_RATE, DISCOUNT_FACTOR)  # lr/gamma unused here
    table_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "qtable.pkl")
    try:
        agent.load(table_path)
        print(f"Loaded Q-table: {len(agent.q_table)} entries")
    except FileNotFoundError:
        print("No qtable.pkl found. Run trainer.py first.")
        env.disconnect()
        sys.exit(1)

    # Evaluation must not touch the trained table: work on a copy so that
    # even zero-default lookups for unseen states stay off the loaded table,
    # and never call agent.update() below.
    agent.q_table = dict(agent.q_table)

    # --- Run evaluation episodes ---
    apple_counts = {0: 0, 1: 0, 2: 0}
    rewards = []
    steps_list = []
    total_deaths = 0
    successes = 0

    print(f"\nRunning {NUM_EVAL_EPISODES} evaluation episodes (epsilon=0)...\n")

    for ep in range(1, NUM_EVAL_EPISODES + 1):
        state = env.reset()
        done = False
        ep_reward = 0.0
        ep_steps = 0
        ep_apples = 0
        ep_deaths = 0

        while not done and ep_steps < MAX_STEPS:
            action = agent.choose_action(state, 0.0)  # greedy: no exploration
            state, reward, done, info = env.step(action)
            # NOTE: agent.update() intentionally NOT called — Q-table is frozen

            ep_reward += reward
            ep_steps += 1

            # Use Godot's cumulative count.  A per-step boolean can undercount
            # if collection signals arrive in the same action horizon.
            ep_apples = max(ep_apples, int(info.get("apples_collected", ep_apples)))
            if info.get("enemy_hit") or info.get("fell_off"):
                ep_deaths += 1

        total_apples = info.get("total_apples", 2)
        ep_apples = min(ep_apples, total_apples)
        apple_counts[ep_apples] = apple_counts.get(ep_apples, 0) + 1
        if ep_apples >= total_apples:
            successes += 1
        total_deaths += ep_deaths
        rewards.append(ep_reward)
        steps_list.append(ep_steps)

        print(f"Ep {ep:2d}:  Reward={ep_reward:7.1f}  "
              f"Apples={ep_apples}/{total_apples}  "
              f"Steps={ep_steps:3d}  Deaths={ep_deaths}  "
              f"{'SUCCESS' if ep_apples >= total_apples else ''}")

    # --- Summary table ---
    n = NUM_EVAL_EPISODES
    avg_reward = sum(rewards) / n
    avg_steps = sum(steps_list) / n

    print("\n" + "=" * 60)
    print("Evaluation Summary")
    print("=" * 60)
    print(f"{'Metric':<30}{'Value':>12}")
    print("-" * 42)
    print(f"{'Episodes with 0 apples':<30}{apple_counts[0]:>12}")
    print(f"{'Episodes with 1 apple':<30}{apple_counts[1]:>12}")
    print(f"{'Episodes with 2 apples':<30}{apple_counts[2]:>12}")
    print(f"{'Success rate (both apples)':<30}{successes}/{n} ({100*successes/n:.1f}%)")
    print(f"{'Average reward':<30}{avg_reward:>12.1f}")
    print(f"{'Average steps':<30}{avg_steps:>12.1f}")
    print(f"{'Total deaths':<30}{total_deaths:>12}")
    print("-" * 42)

    env.disconnect()
    print("\nDone.")


if __name__ == "__main__":
    main()
