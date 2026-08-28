import asyncio
import csv
import json
import os

from rl.environment.godot_environment import GodotEnvironment
from rl.agents.sarsa import SARSAAgent


Q_TABLE_PATH = "results/q_table.json"

NUM_EPISODES = 100
MAX_STEPS = 500


async def run_episode(env, agent, episode_number):
    state, reward, done, score = await env.reset()

    total_reward = 0.0
    steps = 0

    while not done and steps < MAX_STEPS:
        steps += 1

        # Greedy action selection:
        # epsilon = 0 means no exploration.
        action = agent.choose_action(state)

        next_state, reward, done, score = await env.step(action)

        total_reward += reward
        state = next_state

    success = 1 if score >= 20 else 0

    if score >= 20:
        outcome = "complete"
    elif score >= 10:
        outcome = "one_apple"
    else:
        outcome = "failed"

    print(
        f"Episode {episode_number}: "
        f"Steps={steps}, "
        f"Reward={total_reward:.2f}, "
        f"Score={score}, "
        f"Outcome={outcome}"
    )

    return {
        "episode": episode_number,
        "steps": steps,
        "total_reward": total_reward,
        "score": score,
        "success": success,
        "outcome": outcome,
    }


async def evaluate():
    # -----------------------------------------
    # Load trained Q-table
    # -----------------------------------------

    with open(Q_TABLE_PATH, "r") as f:
        q_table = json.load(f)

    print(f"Loaded Q-table: {Q_TABLE_PATH}")
    print(f"Number of learned states: {len(q_table)}")

    # -----------------------------------------
    # Create SARSA agent
    # -----------------------------------------

    agent = SARSAAgent(
        learning_rate=0.1,
        discount_factor=0.98,
        epsilon=0.0,
        epsilon_decay=1.0,
        epsilon_min=0.0,
        num_actions=6,
    )

    # Replace empty Q-table with trained Q-table
    agent.q_table = q_table

    env = GodotEnvironment()

    await env.connect()

    results = []

    for episode in range(1, NUM_EPISODES + 1):
        result = await run_episode(
            env,
            agent,
            episode
        )

        results.append(result)

    await env.close()

    # -----------------------------------------
    # Calculate evaluation statistics
    # -----------------------------------------

    total_successes = sum(
        result["success"]
        for result in results
    )

    total_completions = sum(
        1
        for result in results
        if result["outcome"] == "complete"
    )

    total_one_apple = sum(
        1
        for result in results
        if result["outcome"] == "one_apple"
    )

    total_failed = sum(
        1
        for result in results
        if result["outcome"] == "failed"
    )

    average_reward = sum(
        result["total_reward"]
        for result in results
    ) / NUM_EPISODES

    average_score = sum(
        result["score"]
        for result in results
    ) / NUM_EPISODES

    average_steps = sum(
        result["steps"]
        for result in results
    ) / NUM_EPISODES

    success_rate = (
        total_successes / NUM_EPISODES
    ) * 100

    # -----------------------------------------
    # Print summary
    # -----------------------------------------

    print()
    print("=" * 50)
    print("FINAL EVALUATION SUMMARY")
    print("=" * 50)

    print(f"Episodes tested: {NUM_EPISODES}")
    print(f"Completed (2 apples): {total_completions}")
    print(f"One apple: {total_one_apple}")
    print(f"Failed: {total_failed}")
    print(f"Average reward: {average_reward:.2f}")
    print(f"Average score: {average_score:.2f}")
    print(f"Average steps: {average_steps:.2f}")
    print(f"Success rate: {success_rate:.2f}%")

    # -----------------------------------------
    # Save evaluation results
    # -----------------------------------------

    results_path = "results/evaluation_results.csv"

    with open(
        results_path,
        "w",
        newline=""
    ) as f:

        writer = csv.DictWriter(
            f,
            fieldnames=[
                "episode",
                "steps",
                "total_reward",
                "score",
                "success",
                "outcome",
            ]
        )

        writer.writeheader()
        writer.writerows(results)

    print()
    print(f"Evaluation results saved to {results_path}")


if __name__ == "__main__":
    asyncio.run(evaluate())