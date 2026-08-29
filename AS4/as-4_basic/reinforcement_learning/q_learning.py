import random
import pickle

NUM_ACTIONS = 6  # 0=idle 1=right 2=left 3=jump 4=right+jump 5=left+jump


class QLearning:

    def __init__(self, learning_rate, discount_factor):
        self.lr = learning_rate
        self.gamma = discount_factor
        self.q_table = {}

    def get_q_value(self, state, action):
        key = (state, action)
        if key not in self.q_table:
            self.q_table[key] = 0.0
        return self.q_table[key]

    def choose_action(self, state, epsilon):
        # Epsilon-greedy over all 6 actions
        if random.random() < epsilon:
            return random.randint(0, NUM_ACTIONS - 1)

        q_values = [self.get_q_value(state, a) for a in range(NUM_ACTIONS)]
        max_q = max(q_values)
        # Fixed tie-breaking keeps greedy evaluation reproducible. Exploration
        # remains random when epsilon > 0.
        return q_values.index(max_q)

    def update(self, state, action, reward, next_state, done=False):
        current_q = self.get_q_value(state, action)
        if done:
            future_q = 0.0
        else:
            future_q = max(
                self.get_q_value(next_state, a)
                for a in range(NUM_ACTIONS)
            )
        new_q = current_q + self.lr * (
            reward + self.gamma * future_q - current_q
        )
        self.q_table[(state, action)] = new_q

    def save(self, filename="qtable.pkl"):
        with open(filename, "wb") as f:
            pickle.dump(self.q_table, f)

    def load(self, filename="qtable.pkl"):
        with open(filename, "rb") as f:
            self.q_table = pickle.load(f)
