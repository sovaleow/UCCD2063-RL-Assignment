import random


class SARSAAgent:
    def __init__(
        self,
        learning_rate=0.1,
        discount_factor=0.98,
        epsilon=1.0,
        epsilon_decay=0.997,
        epsilon_min=0.02,
        num_actions=6,
    ):
        self.alpha = learning_rate
        self.gamma = discount_factor

        self.epsilon = epsilon
        self.epsilon_decay = epsilon_decay
        self.epsilon_min = epsilon_min

        self.num_actions = num_actions

        # Q-table:
        # key   = state
        # value = [Q(STOP), Q(LEFT), Q(RIGHT),
        #          Q(JUMP), Q(LEFT+JUMP), Q(RIGHT+JUMP)]
        self.q_table = {}

    def _ensure_state(self, state):
        if state not in self.q_table:
            self.q_table[state] = [0.0] * self.num_actions

    def choose_action(self, state):
        self._ensure_state(state)

        # Exploration
        if random.random() < self.epsilon:
            return random.randint(0, self.num_actions - 1)

        # Exploitation
        q_values = self.q_table[state]
        max_q = max(q_values)

        best_actions = [
            action
            for action, value in enumerate(q_values)
            if value == max_q
        ]

        return random.choice(best_actions)

    def update(
        self,
        state,
        action,
        reward,
        next_state,
        next_action,
        done,
    ):
        self._ensure_state(state)

        current_q = self.q_table[state][action]

        if done:
            target = reward
        else:
            self._ensure_state(next_state)

            next_q = self.q_table[next_state][next_action]

            target = reward + self.gamma * next_q

        self.q_table[state][action] += (
            self.alpha * (target - current_q)
        )

    def decay_epsilon(self):
        self.epsilon = max(
            self.epsilon_min,
            self.epsilon * self.epsilon_decay,
        )