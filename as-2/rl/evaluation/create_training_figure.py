import pandas as pd
import matplotlib.pyplot as plt


df = pd.read_csv("results/training_results.csv")

WINDOW = 100

reward_avg = df["total_reward"].rolling(WINDOW).mean()
score_avg = df["score"].rolling(WINDOW).mean()
steps_avg = df["steps"].rolling(WINDOW).mean()


fig, axes = plt.subplots(
    2,
    2,
    figsize=(12, 8)
)


# ============================================================
# REWARD
# ============================================================

axes[0, 0].plot(
    df["episode"],
    df["total_reward"],
    alpha=0.20,
    label="Per episode"
)

axes[0, 0].plot(
    df["episode"],
    reward_avg,
    linewidth=2,
    label="Moving avg (100)"
)

axes[0, 0].set_title("SARSA Training Reward")
axes[0, 0].set_xlabel("Episode")
axes[0, 0].set_ylabel("Total Reward")
axes[0, 0].legend()


# ============================================================
# SCORE
# ============================================================

axes[0, 1].plot(
    df["episode"],
    df["score"],
    alpha=0.20,
    label="Per episode"
)

axes[0, 1].plot(
    df["episode"],
    score_avg,
    linewidth=2,
    label="Moving avg (100)"
)

axes[0, 1].set_title("SARSA Training Score")
axes[0, 1].set_xlabel("Episode")
axes[0, 1].set_ylabel("Score")
axes[0, 1].legend()


# ============================================================
# STEPS
# ============================================================

axes[1, 0].plot(
    df["episode"],
    df["steps"],
    alpha=0.20,
    label="Per episode"
)

axes[1, 0].plot(
    df["episode"],
    steps_avg,
    linewidth=2,
    label="Moving avg (100)"
)

axes[1, 0].set_title("SARSA Steps per Episode")
axes[1, 0].set_xlabel("Episode")
axes[1, 0].set_ylabel("Steps")
axes[1, 0].legend()


# ============================================================
# EPSILON
# ============================================================

axes[1, 1].plot(
    df["episode"],
    df["epsilon"],
    linewidth=2
)

axes[1, 1].set_title("SARSA Epsilon Decay")
axes[1, 1].set_xlabel("Episode")
axes[1, 1].set_ylabel("Epsilon")


plt.tight_layout()

plt.savefig(
    "results/sarsa_training_results_all.png",
    dpi=300,
    bbox_inches="tight"
)

plt.show()

print("Saved:")
print("results/sarsa_training_results_all.png")