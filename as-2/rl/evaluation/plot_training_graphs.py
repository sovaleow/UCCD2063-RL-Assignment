import pandas as pd
import matplotlib.pyplot as plt


# ============================================================
# LOAD TRAINING RESULTS
# ============================================================

df = pd.read_csv("results/training_results.csv")

WINDOW = 100


# ============================================================
# FIGURE 1 — TRAINING REWARD
# ============================================================

reward_avg = df["total_reward"].rolling(WINDOW).mean()

plt.figure(figsize=(10, 5))

plt.plot(
    df["episode"],
    df["total_reward"],
    alpha=0.25,
    label="Per episode"
)

plt.plot(
    df["episode"],
    reward_avg,
    linewidth=2,
    label="Moving average (100)"
)

plt.xlabel("Episode")
plt.ylabel("Total Reward")
plt.title("SARSA Training Reward per Episode")
plt.legend()
plt.tight_layout()

plt.savefig(
    "results/sarsa_training_reward.png",
    dpi=300
)

plt.show()


# ============================================================
# FIGURE 2 — SCORE
# ============================================================

score_avg = df["score"].rolling(WINDOW).mean()

plt.figure(figsize=(10, 5))

plt.plot(
    df["episode"],
    df["score"],
    alpha=0.25,
    label="Per episode"
)

plt.plot(
    df["episode"],
    score_avg,
    linewidth=2,
    label="Moving average (100)"
)

plt.xlabel("Episode")
plt.ylabel("Score")
plt.title("SARSA Score per Episode")
plt.legend()
plt.tight_layout()

plt.savefig(
    "results/sarsa_training_score.png",
    dpi=300
)

plt.show()


# ============================================================
# FIGURE 3 — STEPS
# ============================================================

steps_avg = df["steps"].rolling(WINDOW).mean()

plt.figure(figsize=(10, 5))

plt.plot(
    df["episode"],
    df["steps"],
    alpha=0.25,
    label="Per episode"
)

plt.plot(
    df["episode"],
    steps_avg,
    linewidth=2,
    label="Moving average (100)"
)

plt.xlabel("Episode")
plt.ylabel("Steps")
plt.title("SARSA Steps per Episode")
plt.legend()
plt.tight_layout()

plt.savefig(
    "results/sarsa_training_steps.png",
    dpi=300
)

plt.show()


# ============================================================
# FIGURE 4 — EPSILON
# ============================================================

plt.figure(figsize=(10, 5))

plt.plot(
    df["episode"],
    df["epsilon"],
    linewidth=2
)

plt.xlabel("Episode")
plt.ylabel("Epsilon")
plt.title("SARSA Epsilon Decay")
plt.tight_layout()

plt.savefig(
    "results/sarsa_epsilon_decay.png",
    dpi=300
)

plt.show()


print()
print("Training graphs saved:")
print("results/sarsa_training_reward.png")
print("results/sarsa_training_score.png")
print("results/sarsa_training_steps.png")
print("results/sarsa_epsilon_decay.png")