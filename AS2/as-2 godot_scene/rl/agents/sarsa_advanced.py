
import math
import random
from collections import defaultdict


class SARSAAgent:
    VALID_ACTIONS = (0, 1, 2, 4, 5)

    def __init__(
        self,
        n_actions: int = 6,
        alpha: float = 0.15,
        gamma: float = 0.997,
        epsilon: float = 0.35,
        epsilon_min: float = 0.06,
        epsilon_decay: float = 0.999,
    ):
        if n_actions != 6:
            raise ValueError(
                "The Godot action space must contain 6 IDs."
            )

        self.n_actions = n_actions
        self.alpha = alpha
        self.gamma = gamma

        self.epsilon = epsilon
        self.epsilon_min = epsilon_min
        self.epsilon_decay = epsilon_decay

        self.Q = defaultdict(
            lambda: [0.0] * self.n_actions
        )

        self.episode = 0
        self.total_steps = 0

        self.recent_success = []
        self.early_episodes = 150

    def act(self, state, explore: bool = True) -> int:
        if (
            explore
            and random.random() < self.epsilon
        ):
            return random.choice(self.VALID_ACTIONS)

        q_values = self.Q[state]

        best_value = max(
            q_values[action]
            for action in self.VALID_ACTIONS
        )

        best_action = min(
            action
            for action in self.VALID_ACTIONS
            if q_values[action] == best_value
        )

        return best_action

    def update(
        self,
        state,
        action: int,
        reward: float,
        next_state,
        next_action,
        done: bool,
    ) -> float:
        current_q = self.Q[state][action]

        if done:
            target = reward
        else:
            if next_action is None:
                raise ValueError(
                    "next_action is required for SARSA."
                )

            target = (
                reward
                + self.gamma
                * self.Q[next_state][next_action]
            )

        td_error = target - current_q

        self.Q[state][action] = (
            current_q
            + self.alpha * td_error
        )

        self.total_steps += 1

        return abs(td_error)

    def record_success(self, success: bool) -> None:
        self.recent_success.append(
            1 if success else 0
        )

        if len(self.recent_success) > 50:
            self.recent_success.pop(0)

    def end_episode(self) -> None:
        self.episode += 1

        if self.episode <= self.early_episodes:
            decay = 0.9995
        else:
            recent_rate = (
                sum(self.recent_success)
                / len(self.recent_success)
                if self.recent_success
                else 0.0
            )

            if recent_rate >= 0.70:
                decay = 0.985
            elif recent_rate >= 0.40:
                decay = 0.992
            else:
                decay = self.epsilon_decay

        self.epsilon = max(
            self.epsilon_min,
            self.epsilon * decay,
        )

    def policy_entropy(self) -> float:
        n = len(self.VALID_ACTIONS)

        p_other = self.epsilon / n
        p_best = (
            (1.0 - self.epsilon)
            + p_other
        )

        entropy = 0.0

        if p_best > 0.0:
            entropy -= (
                p_best
                * math.log(p_best)
            )

        for _ in range(n - 1):
            if p_other > 0.0:
                entropy -= (
                    p_other
                    * math.log(p_other)
                )

        return entropy
