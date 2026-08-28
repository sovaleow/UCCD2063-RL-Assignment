import pandas as pd
import matplotlib.pyplot as plt


# Load final training results
df = pd.read_csv("results/training_results.csv")


# -----------------------------------------
# 1. Reward learning curve
# -----------------------------------------

window = 100

reward_average = (
    df["total_reward"]
    .rolling(window)
    .mean()
)

plt.figure(figsize=(10, 5))

plt.plot(
    df["episode"],
    df["total_reward"],
    alpha=0.25,
    label="Episode Reward"
)

plt.plot(
    df["episode"],
    reward_average,
    label="100-Episode Moving Average"
)

plt.xlabel("Episode")
plt.ylabel("Total Reward")
plt.title("SARSA Training Reward")
plt.legend()
plt.tight_layout()

plt.savefig(
    "results/final_reward_curve.png",
    dpi=300
)

plt.show()


# -----------------------------------------
# 2. Score learning curve
# -----------------------------------------

score_average = (
    df["score"]
    .rolling(window)
    .mean()
)

plt.figure(figsize=(10, 5))

plt.plot(
    df["episode"],
    df["score"],
    alpha=0.25,
    label="Episode Score"
)

plt.plot(
    df["episode"],
    score_average,
    label="100-Episode Moving Average"
)

plt.xlabel("Episode")
plt.ylabel("Score")
plt.title("SARSA Training Score")
plt.legend()
plt.tight_layout()

plt.savefig(
    "results/final_score_curve.png",
    dpi=300
)

plt.show()


# -----------------------------------------
# 3. Success-rate learning curve
# -----------------------------------------

success_average = (
    df["success"]
    .rolling(window)
    .mean()
    * 100
)

plt.figure(figsize=(10, 5))

plt.plot(
    df["episode"],
    success_average
)

plt.xlabel("Episode")
plt.ylabel("Success Rate (%)")
plt.title("SARSA Training Success Rate")
plt.tight_layout()

plt.savefig(
    "results/final_success_curve.png",
    dpi=300
)

plt.show()