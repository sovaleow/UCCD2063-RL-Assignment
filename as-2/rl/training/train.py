import asyncio
import csv
import json
import os

from rl.agents.sarsa import SARSAAgent
from rl.environment.godot_environment import GodotEnvironment


async def train():
    env = GodotEnvironment()

    await env.connect()

    agent = SARSAAgent(
        learning_rate=0.1,
        discount_factor=0.9,
        epsilon=1.0,
        epsilon_decay=0.995,
        epsilon_min=0.05,
        num_actions=5,
    )

    num_episodes = 10

    results_dir = "results"
    os.makedirs(results_dir, exist_ok=True)

    training_results = []

    for episode in range(1, num_episodes + 1):

        state, reward, done, score = await env.reset()

        action = agent.choose_action(state)

        total_reward = 0.0
        steps = 0

        while not done:
            steps += 1

            next_state, reward, done, score = await env.step(action)

            total_reward += reward

            if not done:
                next_action = agent.choose_action(next_state)
            else:
                next_action = None

            agent.update(
                state=state,
                action=action,
                reward=reward,
                next_state=next_state,
                next_action=next_action,
                done=done,
            )

            state = next_state

            if not done:
                action = next_action

        agent.decay_epsilon()

        success = 1 if score > 0 else 0

        training_results.append({
            "episode": episode,
            "steps": steps,
            "total_reward": total_reward,
            "score": score,
            "success": success,
            "epsilon": agent.epsilon
        })

        print(
            f"Episode {episode}: "
            f"Steps={steps}, "
            f"Total Reward={total_reward:.2f}, "
            f"Score={score}, "
            f"Success={success},"
            f"Epsilon={agent.epsilon:.4f}"
        )

    #Training summary
    success_count = sum(
        result["success"] for result in training_results
    )

    success_rate = (
        success_count / num_episodes
    ) * 100

    average_reward = sum(
        result["total_reward"] for result in training_results
    ) / num_episodes

    average_score = sum(
        result["score"] for result in training_results
    ) / num_episodes

    average_steps = sum(
        result["steps"] for result in training_results
    ) / num_episodes

    print()
    print("=" * 50)
    print("TRAINING SUMMARY")
    print("=" * 50)
    print(f"Average reward: {average_reward:.2f}")
    print(f"Average score: {average_score:.2f}")
    print(f"Average steps: {average_steps:.2f}")
    print(f"Success rate: {success_rate:.2f}%")

    # Save Q-table
    with open(
        os.path.join(results_dir, "q_table.json"),
        "w"
    ) as f:
        json.dump(agent.q_table, f, indent=4)

    # Save training metrics
    with open(
        os.path.join(results_dir, "training_results.csv"),
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
                "epsilon"
            ]
        )

        writer.writeheader()
        writer.writerows(training_results)

    print()
    print("Training complete.")
    print("Q-table saved to results/q_table.json")
    print("Training results saved to results/training_results.csv")

    await env.close()


if __name__ == "__main__":
    asyncio.run(train())
