import random
from collections import defaultdict


class SARSAAgent:
    """Tabular on-policy SARSA compatible with the existing Godot bridge."""

    # Keep six Q-values for compatibility with the Godot action IDs,
    # but use the same selectable actions as the supplied SARSA notebook.
    VALID_ACTIONS = (0, 1, 2, 4, 5)

    def __init__(
        self,
        n_actions=6,
        alpha=0.15,
        gamma=0.997,
        epsilon=1.0,
        epsilon_min=0.05,
        epsilon_decay=0.997,
    ):
        if n_actions != 6:
            raise ValueError("This environment expects six Godot action IDs.")

        self.n_actions = n_actions
        self.alpha = alpha
        self.gamma = gamma
        self.epsilon = epsilon
        self.epsilon_min = epsilon_min
        self.epsilon_decay = epsilon_decay
        self.Q = defaultdict(lambda: [0.0] * self.n_actions)
        self.episode = 0
        self.total_steps = 0

    def act(self, state, explore=True):
        if explore and random.random() < self.epsilon:
            return random.choice(self.VALID_ACTIONS)

        q_values = self.Q[state]
        highest_q = max(q_values[action] for action in self.VALID_ACTIONS)
        best_actions = [
            action for action in self.VALID_ACTIONS
            if q_values[action] == highest_q
        ]
        return random.choice(best_actions)

    def update(self, state, action, reward, next_state, next_action, done):
        current_q = self.Q[state][action]

        if done:
            target = reward
        else:
            target = reward + self.gamma * self.Q[next_state][next_action]

        td_error = target - current_q
        self.Q[state][action] = current_q + self.alpha * td_error
        return abs(td_error)

    def end_episode(self):
        self.episode += 1
        self.epsilon = max(
            self.epsilon_min,
            self.epsilon * self.epsilon_decay,
        )
