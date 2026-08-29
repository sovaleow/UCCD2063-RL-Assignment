"""
Godot RL Environment — WebSocket client for the 2D Platform Collector Game.

Communicates with the Godot game via WebSocket.
Discretizes continuous state for Q-learning.
"""
import json
import websocket
from config import RL_HOST, RL_PORT, CONNECT_TIMEOUT, STEP_TIMEOUT, STATE_BINS, MAX_STEPS


class GodotEnv:
    """Environment wrapper that communicates with the running Godot game."""

    def __init__(self, host=RL_HOST, port=RL_PORT, debug=False):
        self.host = host
        self.port = port
        self.ws = None
        self.connected = False
        self.debug = debug
        self.episode_steps = 0

    # ------------------------------------------------------------------
    # Connection
    # ------------------------------------------------------------------
    def connect(self) -> bool:
        """Connect to the Godot RL server. Returns True on success."""
        url = f"ws://{self.host}:{self.port}"
        try:
            self.ws = websocket.create_connection(url, timeout=CONNECT_TIMEOUT)
            self.connected = True
            print(f"Connected to Godot at {url}")
            return True
        except Exception as e:
            print(f"Failed to connect to Godot: {e}")
            print("Make sure the Godot game is running first.")
            self.connected = False
            return False

    def disconnect(self):
        """Close the WebSocket connection."""
        if self.ws:
            try:
                self._send_msg({"type": "close"})
                self.ws.close()
            except Exception:
                pass
            self.ws = None
            self.connected = False

    # ------------------------------------------------------------------
    # RL Interface
    # ------------------------------------------------------------------
    def reset(self):
        """Reset the scene and return initial discrete state."""
        self.episode_steps = 0
        if self.debug:
            print("[PY] reset() sending reset msg")
        self._send_msg({"type": "reset"})
        response = self._recv_msg()
        if response is None:
            raise ConnectionError("No response from Godot on reset")
        if self.debug:
            print("[PY] reset() got response, reward=", response.get("reward"), "done=", response.get("done"))
        raw = response.get("state", {})
        disc = self._discretize(raw)
        if self.debug:
            print("[PY] reset() disc_state=", disc)
        return disc

    def step(self, action: int):
        """Apply action, return (discrete_state, reward, done, info)."""
        if self.debug:
            print("[PY] step() action=", action)
        self._send_msg({"type": "action", "action": action})
        response = self._recv_msg()
        if response is None:
            raise ConnectionError("No response from Godot on step")
        if self.debug:
            print("[PY] step() got response, reward=", response.get("reward"), "done=", response.get("done"))
        raw_state = response.get("state", {})
        reward = response.get("reward", 0.0)
        done = response.get("done", False)
        info = response.get("info", {})
        self.episode_steps += 1
        if self.episode_steps >= MAX_STEPS and not done:
            done = True
            info["max_steps_reached"] = True
        discrete_state = self._discretize(raw_state)
        if self.debug:
            print("[PY] step() disc_state=", discrete_state)
        return discrete_state, reward, done, info

    # ------------------------------------------------------------------
    # State discretization
    # ------------------------------------------------------------------
    def _discretize(self, raw: dict) -> tuple:
        """Convert raw Godot state into a discrete tuple for Q-learning.

        State features (in tuple order):
          px, py, on_ground, apple_dir_x, apple_dir_y,
          apple_dist, enemy_timing, apples_collected, near_gap

        Total state space: 8*5*2*3*3*2*11*2*2 = 63,360
        """
        if not raw:
            return tuple(0 for _ in STATE_BINS)

        bins = STATE_BINS

        # px: 0.0-1.0 -> 0..(bins-1)  (8 bins, 160px each)
        px = min(int(raw.get("px", 0.0) * bins["px"]), bins["px"] - 1)

        # py: 0.0-1.0 -> 0..(bins-1)  (5 bins, 144px each - separates the 3 platform levels)
        py = min(int(raw.get("py", 0.0) * bins["py"]), bins["py"] - 1)

        # on_ground: 0 or 1
        on_ground = int(raw.get("on_ground", 0))

        # apple_dir_x: -1,0,1 -> 0,1,2
        adx = raw.get("apple_dir_x", 0) + 1

        # apple_dir_y: -1,0,1 -> 0,1,2  (vertical direction to nearest apple)
        ady = raw.get("apple_dir_y", 0) + 1

        # apple_dist: 0.0-1.0 -> 0 near (<375px), 1 far
        apple_dist = 0 if raw.get("apple_dist", 0.0) < 0.25 else 1

        # enemy_timing: 0 far; 1..10 encode five relative-x zones and
        # the snail's left/right movement direction.
        enemy_timing = min(max(int(raw.get("enemy_timing", 0)), 0), 10)

        # apples_collected: 0 or 1 (2 = episode already over, no decision needed)
        apples_collected = min(int(raw.get("apples_collected", 0)), 1)

        # near_gap: 0 or 1 (physics-based gap detection ahead of player)
        near_gap = int(raw.get("near_gap", 0))

        return (px, py, on_ground, adx, ady, apple_dist,
                enemy_timing, apples_collected, near_gap)

    # ------------------------------------------------------------------
    # Messaging
    # ------------------------------------------------------------------
    def _send_msg(self, data: dict):
        """Send JSON message to Godot."""
        if not self.ws:
            raise ConnectionError("Not connected to Godot")
        msg = json.dumps(data)
        if self.debug:
            print(f"[PY] send: {msg}")
        self.ws.send(msg)

    def _recv_msg(self) -> dict:
        """Receive JSON message from Godot."""
        if not self.ws:
            return None
        try:
            self.ws.settimeout(STEP_TIMEOUT)
            raw = self.ws.recv()
            if raw is None:
                print("[PY] recv: connection closed (None)")
                self.connected = False
                return None
            if isinstance(raw, bytes):
                raw = raw.decode("utf-8")
            if self.debug:
                print(f"[PY] recv: {raw[:200]}")
            return json.loads(raw)
        except websocket.WebSocketTimeoutException:
            print("Timeout waiting for Godot response")
            return None
        except (ConnectionError, ConnectionResetError, BrokenPipeError) as e:
            print(f"Connection lost: {e}")
            self.connected = False
            return None
        except Exception as e:
            print(f"Error receiving from Godot: {type(e).__name__}: {e}")
            self.connected = False
            return None
