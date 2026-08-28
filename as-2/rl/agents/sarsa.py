import random


class SARSAAgent:
    """
    Tabular on-policy SARSA.

    Actions:

        0 = idle
        1 = left
        2 = right
        3 = jump
        4 = left + jump
        5 = right + jump
    """

    VALID_ACTIONS = (
        0,
        1,
        2,
        3,
        4,
        5,
    )

    def __init__(
        self,
        learning_rate=0.15,
        discount_factor=0.99,
        epsilon=1.0,
        epsilon_decay=0.997,
        epsilon_min=0.05,
        num_actions=6,
    ):

        if num_actions != 6:

            raise ValueError(
                "Expected six Godot action IDs."
            )

        self.alpha = learning_rate
        self.gamma = discount_factor

        self.epsilon = epsilon
        self.epsilon_decay = epsilon_decay
        self.epsilon_min = epsilon_min

        self.num_actions = num_actions

        self.q_table = {}


    def _ensure_state(self, state):

        if state not in self.q_table:

            self.q_table[state] = [
                0.0
            ] * self.num_actions


    def choose_action(
        self,
        state,
        explore=True,
    ):

        self._ensure_state(state)


        # ----------------------------------------------------
        # EXPLORATION
        # ----------------------------------------------------

        if (
            explore
            and
            random.random()
            < self.epsilon
        ):

            return random.choice(
                self.VALID_ACTIONS
            )


        # ----------------------------------------------------
        # GREEDY ACTION
        # ----------------------------------------------------

        q_values = self.q_table[state]


        highest_q = max(
            q_values[action]
            for action
            in self.VALID_ACTIONS
        )


        best_actions = [
            action
            for action
            in self.VALID_ACTIONS
            if q_values[action]
            == highest_q
        ]


        return random.choice(
            best_actions
        )


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


        current_q = (
            self.q_table[state][action]
        )


        # ----------------------------------------------------
        # TERMINAL STATE
        # ----------------------------------------------------

        if done:

            target = reward


        # ----------------------------------------------------
        # NORMAL SARSA
        # ----------------------------------------------------

        else:

            self._ensure_state(
                next_state
            )


            next_q = (
                self.q_table[next_state]
                [next_action]
            )


            target = (
                reward
                + self.gamma
                * next_q
            )


        # ----------------------------------------------------
        # TD UPDATE
        # ----------------------------------------------------

        td_error = (
            target
            - current_q
        )


        self.q_table[state][action] += (
            self.alpha
            * td_error
        )


        return td_error


    def decay_epsilon(self):

        self.epsilon = max(
            self.epsilon_min,
            self.epsilon
            * self.epsilon_decay
        )