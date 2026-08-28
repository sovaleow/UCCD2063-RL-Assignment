# ==========================
# RL Server Connection
# ==========================
RL_HOST = "127.0.0.1"
RL_PORT = 9080
CONNECT_TIMEOUT = 10.0   # seconds
STEP_TIMEOUT = 5.0       # seconds

# ==========================
# Q-Learning Hyperparameters
# ==========================
# Legacy top-level defaults retained for compatibility; trainer.py uses the
# selected EXPERIMENTS entry below. The default experiment is 1000 episodes.
# With lockstep actions of 0.1s, MAX_STEPS=1800 permits 180s per episode.
MAX_STEPS = 1800
LEARNING_RATE = 0.1
DISCOUNT_FACTOR = 0.98

EPSILON = 1.0
EPSILON_DECAY = 0.997
MIN_EPSILON = 0.02

# ==========================
# Experiment Configurations
# ==========================
EXPERIMENTS = {
    "default": {
        "episodes": 1000,
        "lr": 0.1,
        "gamma": 0.98,
        "epsilon": 1.0,
        "epsilon_decay": 0.997,
        "min_epsilon": 0.02,
    },
    # Focused continuation: high exploration floor so the apple1 climb gets
    # enough samples for the greedy policy to follow it reliably.
    "resume": {
        "episodes": 600,
        "lr": 0.1,
        "gamma": 0.98,
        "epsilon": 0.3,
        "epsilon_decay": 0.998,
        "min_epsilon": 0.1,
    },
    "slower_decay": {
        "episodes": 1500,
        "lr": 0.1,
        "gamma": 0.95,
        "epsilon": 1.0,
        "epsilon_decay": 0.997,
        "min_epsilon": 0.05,
    },
    "higher_lr": {
        "episodes": 1000,
        "lr": 0.2,
        "gamma": 0.95,
        "epsilon": 1.0,
        "epsilon_decay": 0.995,
        "min_epsilon": 0.05,
    },
    "lower_gamma": {
        "episodes": 1000,
        "lr": 0.1,
        "gamma": 0.90,
        "epsilon": 1.0,
        "epsilon_decay": 0.995,
        "min_epsilon": 0.05,
    },
}

# ==========================
# State Discretization Bins
# ==========================
# Compact 9-feature state. Enemy timing preserves relative position and motion
# direction so the agent can wait or jump around a moving snail.
# This space is 63,360 states and remains practical for tabular learning.
# Features (tuple order in environment._discretize):
#   px, py, on_ground, apple_dir_x, apple_dir_y, apple_dist,
#   enemy_timing, apples_collected, near_gap
# Dropped: alive (terminal-only), vx_sign, and raw enemy position/direction.
STATE_BINS = {
    "px": 8,               # player x (0.0-1.0), 160px per bin
    "py": 5,               # player y (0.0-1.0), 144px per bin (separates the 3 platform levels)
    "on_ground": 2,        # 0 or 1
    "apple_dir_x": 3,      # -1, 0, 1
    "apple_dir_y": 3,      # -1, 0, 1  (vertical direction to nearest apple)
    "apple_dist": 2,       # near (<375px), far
    "enemy_timing": 11,    # far + 5 relative-x zones × 2 motion directions
    "apples_collected": 2, # 0 or 1 (2 = episode already over)
    "near_gap": 2,         # 0 or 1 — physics raycast, not hardcoded
}
