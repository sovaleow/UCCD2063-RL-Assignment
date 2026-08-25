import asyncio
import random

from rl.environment.godot_environment import GodotEnvironment


async def run_episode(env, episode_number):
    state, reward, done, score = await env.reset()

    total_reward = 0.0
    step_number = 0

    while not done:
        step_number += 1

        action = random.randint(1, 5)

        next_state, reward, done, score = await env.step(action)

        total_reward += reward
        state = next_state

    print(
        f"Episode {episode_number}: "
        f"Steps={step_number}, "
        f"Total Reward={total_reward:.2f}, "
        f"Score={score}"
    )

    return {
        "episode": episode_number,
        "steps": step_number,
        "total_reward": total_reward,
        "score": score,
    }


async def main():
    env = GodotEnvironment()

    await env.connect()

    results = []

    NUM_EPISODES = 10

    for episode in range(1, NUM_EPISODES + 1):
        result = await run_episode(env, episode)
        results.append(result)

    await env.close()

    print()
    print("=" * 50)
    print("RANDOM POLICY SUMMARY")
    print("=" * 50)

    average_reward = sum(
        result["total_reward"] for result in results
    ) / len(results)

    average_steps = sum(
        result["steps"] for result in results
    ) / len(results)

    average_score = sum(
        result["score"] for result in results
    ) / len(results)

    print(f"Average reward: {average_reward:.2f}")
    print(f"Average steps: {average_steps:.2f}")
    print(f"Average score: {average_score:.2f}")


if __name__ == "__main__":
    asyncio.run(main())