import pandas as pd
import matplotlib.pyplot as plt


# ==========================================
# Load training results
# ==========================================

df = pd.read_csv("as-2/v2-1000results/training_results.csv")


# ==========================================
# Calculate apples collected
# ==========================================

# Your environment gives 10 points per apple
df["apples_collected"] = df["score"] / 10


# ==========================================
# Moving average
# ==========================================

window = 50

df["reward_ma"] = df["total_reward"].rolling(window).mean()
df["apples_ma"] = df["apples_collected"].rolling(window).mean()
df["steps_ma"] = df["steps"].rolling(window).mean()


# ==========================================
# Graph 1: Training Reward per Episode
# ==========================================

plt.figure(figsize=(10, 5))

plt.plot(
    df["episode"],
    df["total_reward"],
    alpha=0.3,
    label="Reward per episode"
)

plt.plot(
    df["episode"],
    df["reward_ma"],
    linewidth=2,
    label="50-episode moving average"
)

plt.xlabel("Episode")
plt.ylabel("Total Reward")
plt.title("Training Reward per Episode")
plt.legend()
plt.grid(True)

plt.tight_layout()
plt.savefig("as-2/v2-1000results/training_reward.png", dpi=300)
plt.show()


# ==========================================
# Graph 2: Apples Collected per Episode
# ==========================================

plt.figure(figsize=(10, 5))

plt.plot(
    df["episode"],
    df["apples_collected"],
    alpha=0.3,
    label="Apples collected"
)

plt.plot(
    df["episode"],
    df["apples_ma"],
    linewidth=2,
    label="50-episode moving average"
)

plt.xlabel("Episode")
plt.ylabel("Apples Collected")
plt.title("Apples Collected per Episode")

plt.yticks([0, 1, 2])

plt.legend()
plt.grid(True)

plt.tight_layout()
plt.savefig("as-2/v2-1000results/apples_collected.png", dpi=300)
plt.show()


# ==========================================
# Graph 3: Steps per Episode
# ==========================================

plt.figure(figsize=(10, 5))

plt.plot(
    df["episode"],
    df["steps"],
    alpha=0.3,
    label="Steps per episode"
)

plt.plot(
    df["episode"],
    df["steps_ma"],
    linewidth=2,
    label="50-episode moving average"
)

plt.xlabel("Episode")
plt.ylabel("Steps")
plt.title("Steps per Episode")

plt.legend()
plt.grid(True)

plt.tight_layout()
plt.savefig("as-2/v2-1000results/steps_per_episode.png", dpi=300)
plt.show()


# ==========================================
# Graph 4: Epsilon Decay
# ==========================================

plt.figure(figsize=(10, 5))

plt.plot(
    df["episode"],
    df["epsilon"],
    linewidth=2
)

plt.xlabel("Episode")
plt.ylabel("Epsilon")
plt.title("Epsilon Decay Over Training")

plt.grid(True)

plt.tight_layout()
plt.savefig("as-2/v2-1000results/epsilon_decay.png", dpi=300)
plt.show()


print("Graphs generated successfully!")
print("Saved to:")
print("as-2/v2-1000results/training_reward.png")
print("as-2/v2-1000results/apples_collected.png")
print("as-2/v2-1000results/steps_per_episode.png")
print("as-2/v2-1000results/epsilon_decay.png")