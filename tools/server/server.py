"""Crime in Clock Tower — room server (F-003 online foundation).

A deliberately tiny websocket server: one room, players identified by a
client-supplied persistent id (the browser's localStorage id), 12 Hz world
state. Identity rule the game depends on:
  - different browsers  -> different ids  -> different characters
  - same browser, new tab -> same id -> the NEW connection TAKES OVER the
    character and the old connection is demoted to spectator (kicked with
    code 4001).

Run:  python tools/server/server.py        (default port 8765)
      PORT=9000 python tools/server/server.py

Protocol (JSON text frames):
  C->S {"t":"join","id":"<16 hex>","name":"P-abcd"}
  C->S {"t":"state","x":..,"z":..,"ry":..,"moving":bool}     (own avatar)
  S->C {"t":"welcome","you":<id>,"players":[{id,name}..]}
  S->C {"t":"world","players":[{"id","name","x","z","ry","moving"}..]}   (12 Hz)
  S->C {"t":"bye","id":<id>}
"""
import asyncio
import json
import os
import sys
import time

import websockets

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else int(os.environ.get("PORT", 8765))
TICK_HZ = 12

# id -> {"ws", "name", "x", "z", "ry", "moving"}
players: dict = {}


def world_message() -> str:
    return json.dumps({"t": "world", "players": [
        {"id": pid, "name": p["name"], "x": round(p["x"], 3),
         "z": round(p["z"], 3), "ry": round(p["ry"], 3),
         "moving": p["moving"]}
        for pid, p in players.items()]})


async def broadcast(message: str, exclude=None) -> None:
    # Snapshot before awaiting: handle() tasks may join/leave players while
    # an await inside this loop yields control (RuntimeError otherwise).
    dead = []
    for pid, p in list(players.items()):
        if pid == exclude:
            continue
        try:
            await p["ws"].send(message)
        except websockets.ConnectionClosed:
            dead.append(pid)
    for pid in dead:
        players.pop(pid, None)


async def handle(ws) -> None:
    pid = None
    try:
        raw = await ws.recv()
        join = json.loads(raw)
        if join.get("t") != "join":
            await ws.close(code=4000, reason="expected join")
            return
        pid = join["id"][:32]
        name = join.get("name") or ("P-" + pid[:4])
        pid = str(pid)

        # Same-browser second tab: the fresh connection takes over.
        old = players.get(pid)
        if old is not None and old["ws"] is not ws:
            try:
                await old["ws"].close(code=4001, reason="taken over by newer tab")
            except Exception:
                pass
        players[pid] = {"ws": ws, "name": name, "x": 0.0, "z": 3.0,
                        "ry": 0.0, "moving": False}
        print(f"[server] + {name} ({pid[:8]}) — {len(players)} player(s)", flush=True)
        await ws.send(json.dumps({"t": "welcome", "you": pid,
                                  "players": [{"id": q, "name": p["name"]}
                                              for q, p in players.items()]}))
        await broadcast(world_message(), exclude=pid)

        async for raw_msg in ws:
            msg = json.loads(raw_msg)
            if msg.get("t") == "state" and pid in players:
                p = players[pid]
                p["x"] = float(msg.get("x", p["x"]))
                p["z"] = float(msg.get("z", p["z"]))
                p["ry"] = float(msg.get("ry", p["ry"]))
                p["moving"] = bool(msg.get("moving", False))
    except websockets.ConnectionClosed:
        pass
    finally:
        if pid and players.get(pid, {}).get("ws") is ws:
            players.pop(pid, None)
            print(f"[server] - {pid[:8]} — {len(players)} player(s)", flush=True)
            try:
                await broadcast(json.dumps({"t": "bye", "id": pid}))
            except Exception:
                pass


async def ticker() -> None:
    interval = 1.0 / TICK_HZ
    while True:
        await asyncio.sleep(interval)
        if players:
            await broadcast(world_message())


async def main() -> None:
    async with websockets.serve(handle, "0.0.0.0", PORT):
        print(f"[server] crime-in-clock-tower room server on ws://0.0.0.0:{PORT}", flush=True)
        await ticker()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
