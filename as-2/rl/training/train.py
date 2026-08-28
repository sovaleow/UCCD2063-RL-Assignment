import asyncio
import csv
import json
import os

from rl.agents.sarsa import SARSAAgent
from rl.environment.godot_environment import GodotEnvironment


# ============================================================
# TRAINING
# ============================================================

NUM_EPISODES = 1000
MAX_STEPS = 300


# ============================================================
# V7 OUTPUT
# ============================================================

RESULTS_DIR = "results_v7"

Q_TABLE_PATH = os.path.join(
    RESULTS_DIR,
    "q_table_v7.json",
)

TRAINING_RESULTS_PATH = os.path.join(
    RESULTS_DIR,
    "training_results_v7.csv",
)


# ============================================================
# TRAIN
# ============================================================

async def train():

    os.makedirs(
        RESULTS_DIR,
        exist_ok=True
    )


    env = GodotEnvironment()

    await env.connect()


    # ========================================================
    # SARSA
    # ========================================================

    agent = SARSAAgent(
        learning_rate=0.15,
        discount_factor=0.99,
        epsilon=1.0,
        epsilon_decay=0.997,
        epsilon_min=0.05,
        num_actions=6,
    )


    training_results = []


    # ========================================================
    # EPISODES
    # ========================================================

    for episode in range(
        1,
        NUM_EPISODES + 1
    ):

        # ----------------------------------------------------
        # RESET
        # ----------------------------------------------------

        (
            state,
            reward,
            done,
            score,
        ) = await env.reset()


        action = agent.choose_action(
            state,
            explore=True,
        )


        total_reward = 0.0
        steps = 0


        # ----------------------------------------------------
        # EPISODE
        # ----------------------------------------------------

        while (
            not done
            and
            steps < MAX_STEPS
        ):

            steps += 1


            (
                next_state,
                reward,
                done,
                score,
            ) = await env.step(
                action
            )


            # ------------------------------------------------
            # NEXT ACTION
            # ------------------------------------------------

            if not done:

                next_action = (
                    agent.choose_action(
                        next_state,
                        explore=True,
                    )
                )

            else:

                next_action = None


            # ------------------------------------------------
            # SARSA UPDATE
            # ------------------------------------------------

            agent.update(
                state,
                action,
                reward,
                next_state,
                next_action,
                done,
            )


            # ------------------------------------------------
            # REWARD
            # ------------------------------------------------

            total_reward += reward


            # ------------------------------------------------
            # NEXT STATE
            # ------------------------------------------------

            state = next_state


            if not done:

                action = next_action


        # ====================================================
        # TRUNCATION
        # ====================================================

        truncated = (
            steps >= MAX_STEPS
            and
            not done
        )


        if truncated:

            done = True


        # ====================================================
        # EPSILON
        # ====================================================

        agent.decay_epsilon()


        # ====================================================
        # SUCCESS
        #
        # ONLY SCORE 20 COUNTS
        #
        # 0  = 0 apples = failure
        # 10 = 1 apple   = failure
        # 20 = 2 apples  = SUCCESS
        # ====================================================

        success = (
            1
            if score >= 20
            else 0
        )


        # ====================================================
        # SAVE RESULT
        # ====================================================

        training_results.append({

            "episode": episode,

            "steps": steps,

            "total_reward": total_reward,

            "score": score,

            "success": success,

            "epsilon": agent.epsilon,

            "truncated": int(truncated),
        })


        # ====================================================
        # EPISODE LOG
        # ====================================================

        print(
            f"Episode {episode:04d} | "
            f"Steps={steps:03d} | "
            f"Reward={total_reward:8.2f} | "
            f"Score={score:2d} | "
            f"Success={success} | "
            f"Epsilon={agent.epsilon:.4f}"
        )


        # ====================================================
        # LAST 50
        # ====================================================

        if episode % 50 == 0:

            recent = (
                training_results[-50:]
            )


            zero_apples = 0
            one_apple = 0
            two_apples = 0


            for row in recent:

                if row["score"] >= 20:

                    two_apples += 1

                elif row["score"] >= 10:

                    one_apple += 1

                else:

                    zero_apples += 1


            recent_success = (
                sum(
                    row["success"]
                    for row in recent
                )
                / len(recent)
                * 100
            )


            recent_reward = (
                sum(
                    row["total_reward"]
                    for row in recent
                )
                / len(recent)
            )


            recent_score = (
                sum(
                    row["score"]
                    for row in recent
                )
                / len(recent)
            )


            recent_steps = (
                sum(
                    row["steps"]
                    for row in recent
                )
                / len(recent)
            )


            print()

            print(
                "--- Last 50 episodes ---"
            )

            print(
                f"0 apples:          "
                f"{zero_apples:2d}/50"
            )

            print(
                f"1 apple:           "
                f"{one_apple:2d}/50"
            )

            print(
                f"2 apples:          "
                f"{two_apples:2d}/50"
            )

            print(
                f"2-apple success:   "
                f"{recent_success:5.1f}%"
            )

            print(
                f"Average reward:    "
                f"{recent_reward:7.2f}"
            )

            print(
                f"Average score:     "
                f"{recent_score:5.2f}"
            )

            print(
                f"Average steps:     "
                f"{recent_steps:5.2f}"
            )

            print(
                f"Q-table states:    "
                f"{len(agent.q_table)}"
            )

            print()


    # ========================================================
    # OVERALL
    # ========================================================

    success_rate = (
        sum(
            row["success"]
            for row in training_results
        )
        / NUM_EPISODES
        * 100
    )


    average_reward = (
        sum(
            row["total_reward"]
            for row in training_results
        )
        / NUM_EPISODES
    )


    average_score = (
        sum(
            row["score"]
            for row in training_results
        )
        / NUM_EPISODES
    )


    average_steps = (
        sum(
            row["steps"]
            for row in training_results
        )
        / NUM_EPISODES
    )


    # ========================================================
    # FINAL 50
    # ========================================================

    final_50 = (
        training_results[-50:]
    )


    final_zero = 0
    final_one = 0
    final_two = 0


    for row in final_50:

        if row["score"] >= 20:

            final_two += 1

        elif row["score"] >= 10:

            final_one += 1

        else:

            final_zero += 1


    final_success = (
        final_two
        / len(final_50)
        * 100
    )


    final_reward = (
        sum(
            row["total_reward"]
            for row in final_50
        )
        / len(final_50)
    )


    final_score = (
        sum(
            row["score"]
            for row in final_50
        )
        / len(final_50)
    )


    final_steps = (
        sum(
            row["steps"]
            for row in final_50
        )
        / len(final_50)
    )


    # ========================================================
    # SUMMARY
    # ========================================================

    print()

    print("=" * 60)

    print(
        "SARSA V7 TRAINING SUMMARY"
    )

    print("=" * 60)

    print(
        f"Average reward:       "
        f"{average_reward:.2f}"
    )

    print(
        f"Average score:        "
        f"{average_score:.2f}"
    )

    print(
        f"Average steps:        "
        f"{average_steps:.2f}"
    )

    print(
        f"Overall success:      "
        f"{success_rate:.2f}%"
    )

    print(
        f"Final 50 success:     "
        f"{final_success:.2f}%"
    )

    print(
        f"Final 50 avg reward:  "
        f"{final_reward:.2f}"
    )

    print(
        f"Final 50 avg score:   "
        f"{final_score:.2f}"
    )

    print(
        f"Final 50 avg steps:   "
        f"{final_steps:.2f}"
    )

    print(
        f"Final 50 0 apples:    "
        f"{final_zero}/50"
    )

    print(
        f"Final 50 1 apple:     "
        f"{final_one}/50"
    )

    print(
        f"Final 50 2 apples:    "
        f"{final_two}/50"
    )

    print(
        f"Q-table states:       "
        f"{len(agent.q_table)}"
    )

    print(
        f"Final epsilon:        "
        f"{agent.epsilon:.4f}"
    )


    # ========================================================
    # SAVE Q TABLE
    # ========================================================

    with open(
        Q_TABLE_PATH,
        "w"
    ) as file:

        json.dump(
            agent.q_table,
            file,
            indent=2,
        )


    # ========================================================
    # SAVE CSV
    # ========================================================

    with open(
        TRAINING_RESULTS_PATH,
        "w",
        newline=""
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


    print()

    print(
        "Q-table saved to:",
        Q_TABLE_PATH
    )

    print(
        "Training results saved to:",
        TRAINING_RESULTS_PATH
    )


    await env.close()


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":

    asyncio.run(train())