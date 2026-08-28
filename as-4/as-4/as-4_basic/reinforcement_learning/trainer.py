"""
RL Training Script — Trains a Q-Learning agent against the Godot game.

Usage:
  1. Open the Godot project and run the game (it starts an RL server on port 9080)
  2. Run:  python trainer.py

The script connects to Godot, trains the agent, saves the Q-table, and
generates training curves.
"""
from environment import GodotEnv
from q_learning import QLearning
from config import *

import matplotlib
matplotlib.use("Agg")  # non-interactive backend
import matplotlib.pyplot as plt
import time
import os
import sys


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TABLE_PATH = os.path.join(BASE_DIR, "qtable.pkl")


# ============================================================
# Training function
# ============================================================
def train_agent(env, agent, config_dict, label="default", debug=False):
    """
    Train a Q-Learning agent on the connected Godot environment.

    Returns dict of training history for analysis.
    """
    episodes = config_dict["episodes"]
    lr = config_dict["lr"]
    gamma = config_dict["gamma"]
    epsilon = config_dict["epsilon"]
    epsilon_decay = config_dict["epsilon_decay"]
    min_epsilon = config_dict["min_epsilon"]

    # Recreate agent with specified params
    agent.lr = lr
    agent.gamma = gamma

    reward_history = []
    epsilon_history = []
    apples_history = []
    deaths_history = []
    steps_history = []

    for episode in range(episodes):
        print(f"[PY] Starting episode {episode+1}")
        state = env.reset()
        if debug or episode < 3:
            print(f"[PY] Ep {episode+1} reset: discrete_state={state}")
        total_reward = 0.0
        done = False
        step = 0
        apples_ep = 0
        deaths_ep = 0

        while not done and step < MAX_STEPS:
            action = agent.choose_action(state, epsilon)
            next_state, reward, done, info = env.step(action)
            agent.update(state, action, reward, next_state, done)

            state = next_state
            total_reward += reward
            step += 1

            # Godot reports the cumulative count; do not count only the
            # per-action boolean event.
            apples_ep = max(apples_ep, int(info.get("apples_collected", apples_ep)))
            if info.get("enemy_hit") or info.get("fell_off"):
                deaths_ep += 1

        # Debug: print why episode ended
        if debug or episode < 5:
            reason = "max_steps" if step >= MAX_STEPS else "done"
            print(f"[PY] Ep {episode+1} ended: {reason}  steps={step}  "
                  f"reward={total_reward:.1f}  apples={apples_ep}  deaths={deaths_ep}  "
                  f"alive={info.get('player_alive', '?')}  "
                  f"pos=({info.get('player_x', '?'):.0f}, {info.get('player_y', '?'):.0f})")

        reward_history.append(total_reward)
        epsilon_history.append(epsilon)
        apples_history.append(apples_ep)
        deaths_history.append(deaths_ep)
        steps_history.append(step)

        # Decay epsilon
        epsilon = max(min_epsilon, epsilon * epsilon_decay)

        # Progress
        if (episode + 1) % 100 == 0:
            avg_r = sum(reward_history[-100:]) / min(len(reward_history), 100)
            avg_a = sum(apples_history[-100:]) / min(len(apples_history), 100)
            print(f"[{label}] Ep {episode+1}/{episodes}  "
                  f"AvgR={avg_r:.1f}  Apples={avg_a:.1f}  Eps={epsilon:.3f}")

        # Periodic checkpoint so a long run isn't lost on interruption
        if (episode + 1) % 200 == 0:
            agent.save(TABLE_PATH)

    return {
        "label": label,
        "rewards": reward_history,
        "epsilons": epsilon_history,
        "apples": apples_history,
        "deaths": deaths_history,
        "steps": steps_history,
        "config": config_dict,
    }


# ============================================================
# Plotting
# ============================================================
def _moving_average(values, window):
    """Trailing (running) moving average.

    The first `window - 1` points are averages of the data seen so far, so the
    trend line starts exactly where the raw line starts.
    """
    ma = []
    for i in range(len(values)):
        start = max(0, i - window + 1)
        ma.append(sum(values[start:i + 1]) / (i - start + 1))
    return ma


def plot_results(all_histories, save_dir="."):
    """Generate training plots for one or more experiment runs.

    Reward, Apples Collected and Steps each show the raw per-episode values
    (blue, thin) plus a moving-average trend line (orange, thick) so the
    learning trend is clearly visible. Epsilon is already smooth and stays a
    single curve. X-axis is Episode (1..N). All existing plots are kept.
    """
    window = 50
    multi_run = len(all_histories) > 1

    def plot_raw_and_trend(hist_key, ylabel, title, filename):
        """One figure per metric: raw per-episode values (blue) + trend (orange)."""
        plt.figure(figsize=(14, 8), dpi=150)
        for hist in all_histories:
            series = hist[hist_key]
            episodes = range(1, len(series) + 1)
            raw_label = f"Raw ({hist['label']})" if multi_run else "Raw per-episode"
            trend_label = f"Trend ({hist['label']})" if multi_run else "Moving average"
            # Raw per-episode values first, so the trend line draws on top.
            plt.plot(episodes, series, color="blue", linewidth=0.8, alpha=0.5,
                     label=raw_label)
            plt.plot(episodes, _moving_average(series, window), color="orange",
                     linewidth=2.0, label=trend_label)
        plt.xlabel("Episode")
        plt.ylabel(ylabel)
        plt.title(title)
        plt.legend()
        plt.grid(True)
        plt.tight_layout()
        path = os.path.join(save_dir, filename)
        plt.savefig(path)
        plt.close()
        print(f"Saved: {path}")

    # --- Reward curve ---
    plot_raw_and_trend("rewards", "Reward",
                       "Training Reward per Episode", "learning_curve.png")

    # --- Epsilon decay (already smooth: single curve, no trend line) ---
    plt.figure(figsize=(14, 8), dpi=150)
    for hist in all_histories:
        episodes = range(1, len(hist["epsilons"]) + 1)
        plt.plot(episodes, hist["epsilons"], linewidth=2, label=hist["label"])
    plt.xlabel("Episode")
    plt.ylabel("Epsilon")
    plt.title("Epsilon Decay over Episodes")
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    path = os.path.join(save_dir, "epsilon_curve.png")
    plt.savefig(path)
    plt.close()
    print(f"Saved: {path}")

    # --- Apples collected ---
    plot_raw_and_trend("apples", "Apples Collected",
                       "Apples Collected per Episode", "apples_curve.png")

    # --- Steps survived ---
    plot_raw_and_trend("steps", "Steps",
                       "Steps per Episode", "steps_curve.png")


# ============================================================
# Main
# ============================================================
def main():
    # --- Connect to Godot ---
    print("=" * 50)
    print("Connecting to Godot RL Server...")
    print("Ensure the Godot game is running first!")
    print("=" * 50)

    debug = "--debug" in sys.argv
    env = GodotEnv(debug=debug)
    if not env.connect():
        print("\nCannot connect to Godot. Exiting.")
        print("Tip: Open the Godot project and press F5 to run the game,")
        print("     then re-run this script.")
        sys.exit(1)

    agent = QLearning(LEARNING_RATE, DISCOUNT_FACTOR)
    if "--resume" in sys.argv:
        try:
            agent.load(TABLE_PATH)
            print(f"Resuming from existing Q-table: {len(agent.q_table)} entries")
        except FileNotFoundError:
            print("No qtable.pkl to resume from; starting fresh.")

    # --- Choose experiment ---
    # Run "default" for quick training, or loop over EXPERIMENTS for the report
    run_all = "--all" in sys.argv
    exp_name = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else None

    if exp_name and exp_name in EXPERIMENTS:
        experiments_to_run = {exp_name: EXPERIMENTS[exp_name]}
    elif run_all:
        experiments_to_run = EXPERIMENTS
    else:
        experiments_to_run = {"default": EXPERIMENTS["default"]}

    all_histories = []

    for name, cfg in experiments_to_run.items():
        print(f"\n{'='*50}")
        print(f"Running experiment: {name}")
        print(f"Config: episodes={cfg['episodes']}, lr={cfg['lr']}, "
              f"gamma={cfg['gamma']}, eps_decay={cfg['epsilon_decay']}")
        print(f"{'='*50}")

        start_time = time.time()
        history = train_agent(env, agent, cfg, label=name, debug=debug)
        elapsed = time.time() - start_time
        print(f"Experiment '{name}' finished in {elapsed:.1f}s")
        all_histories.append(history)

    # --- Save Q-table ---
    agent.save(TABLE_PATH)
    print(f"\nQ-table saved: {TABLE_PATH}")
    print(f"Q-table size: {len(agent.q_table)} entries")

    # --- Plot results ---
    plot_results(all_histories, save_dir=BASE_DIR)

    # --- Print summary ---
    print("\n" + "=" * 50)
    print("Training Summary")
    print("=" * 50)
    for hist in all_histories:
        rewards = hist["rewards"]
        last_100 = rewards[-100:] if len(rewards) >= 100 else rewards
        print(f"\n{hist['label']}:")
        print(f"  Final avg reward (last 100): {sum(last_100)/len(last_100):.1f}")
        print(f"  Max reward: {max(rewards):.1f}")
        print(f"  Final apples/eps: {sum(hist['apples'][-100:])/100:.1f}")
        print(f"  Final steps/eps: {sum(hist['steps'][-100:])/100:.1f}")

    # --- Cleanup ---
    env.disconnect()
    print("\nDone.")


if __name__ == "__main__":
    main()
