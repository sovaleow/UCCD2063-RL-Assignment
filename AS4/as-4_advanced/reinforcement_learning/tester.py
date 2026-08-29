"""
RL Testing Script — Evaluates a trained Q-Learning agent on the Godot game.

Usage:
  1. Open the Godot project and run the game
  2. Run:  python tester.py

Runs the agent with epsilon=0 (pure exploitation) and reports detailed metrics.
"""
from environment import GodotEnv
from q_learning import QLearning
from config import *

import os
import sys


TABLE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "qtable.pkl")


def main():
    # --- Connect ---
    print("=" * 50)
    print("Testing Trained Agent on Godot Environment")
    print("=" * 50)

    env = GodotEnv()
    if not env.connect():
        print("\nCannot connect to Godot. Run the game first (F5 in Godot).")
        sys.exit(1)

    # --- Load trained agent ---
    agent = QLearning(LEARNING_RATE, DISCOUNT_FACTOR)
    try:
        agent.load(TABLE_PATH)
        print(f"Loaded Q-table: {len(agent.q_table)} entries")
    except FileNotFoundError:
        print("No qtable.pkl found. Run trainer.py first.")
        env.disconnect()
        sys.exit(1)

    # --- Test episodes ---
    num_episodes = 10
    print(f"\nRunning {num_episodes} test episodes (epsilon=0)...\n")

    total_rewards = []
    total_apples = []
    total_steps = []
    total_deaths = []
    completions = 0

    for ep in range(num_episodes):
        state = env.reset()
        done = False
        ep_reward = 0.0
        ep_steps = 0
        ep_apples = 0
        ep_deaths = 0

        while not done and ep_steps < MAX_STEPS:
            action = agent.choose_action(state, 0.0)  # epsilon=0, no exploration
            state, reward, done, info = env.step(action)

            ep_reward += reward
            ep_steps += 1

            ep_apples = max(ep_apples, int(info.get("apples_collected", ep_apples)))
            if info.get("enemy_hit") or info.get("fell_off"):
                ep_deaths += 1

            if done:
                if info.get("apples_collected", 0) >= info.get("total_apples", 2):
                    completions += 1

        total_rewards.append(ep_reward)
        total_apples.append(ep_apples)
        total_steps.append(ep_steps)
        total_deaths.append(ep_deaths)

        print(f"Ep {ep+1:2d}:  "
              f"Reward={ep_reward:7.1f}  "
              f"Apples={ep_apples}/{info.get('total_apples',2)}  "
              f"Steps={ep_steps:3d}  "
              f"Deaths={ep_deaths}  "
              f"{'COMPLETED' if info.get('apples_collected',0) >= info.get('total_apples',2) else ''}")

    # --- Summary ---
    print("\n" + "=" * 50)
    print("Test Summary")
    print("=" * 50)
    print(f"Episodes:          {num_episodes}")
    print(f"Avg Reward:        {sum(total_rewards)/num_episodes:.1f}")
    print(f"Avg Apples:        {sum(total_apples)/num_episodes:.1f}")
    print(f"Avg Steps:         {sum(total_steps)/num_episodes:.1f}")
    print(f"Avg Deaths:        {sum(total_deaths)/num_episodes:.1f}")
    print(f"Completion Rate:   {completions}/{num_episodes} ({100*completions/num_episodes:.0f}%)")
    print(f"Max Reward:        {max(total_rewards):.1f}")
    print(f"Min Reward:        {min(total_rewards):.1f}")

    env.disconnect()


if __name__ == "__main__":
    main()
