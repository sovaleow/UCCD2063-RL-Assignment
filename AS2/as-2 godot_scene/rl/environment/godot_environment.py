import asyncio
import json
import websockets


class GodotEnvironment:

    def __init__(
        self,
        host="localhost",
        port=8765
    ):

        self.uri = (
            f"ws://{host}:{port}"
        )

        self.websocket = None


    async def connect(self):

        self.websocket = (
            await websockets.connect(
                self.uri
            )
        )

        print(
            "Connected to Godot"
        )


    async def reset(self):

        await self.websocket.send(
            json.dumps({
                "type": "reset"
            })
        )


        response = (
            await self.websocket.recv()
        )


        data = json.loads(
            response
        )


        return (
            data["state"],
            data["reward"],
            data["done"],
            data["score"]
        )


    async def step(
        self,
        action
    ):

        await self.websocket.send(
            json.dumps({
                "type": "step",
                "action": action
            })
        )


        response = (
            await self.websocket.recv()
        )


        data = json.loads(
            response
        )


        return (
            data["state"],
            data["reward"],
            data["done"],
            data["score"]
        )


    async def close(self):

        if self.websocket is not None:

            await self.websocket.close()