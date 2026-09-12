"""Load test: N players through the CLOUDFLARE tunnel, all speaking at once.

Simulates real game clients: join -> state @12 Hz -> voice 10 chunks/s
(3.2 KB each, 16 kHz PCM). Measures connect time, world-broadcast rate,
voice fan-out rate + latency, drops, and total throughput.

Run:  python tools/server/loadtest_20.py [N] [URL]
      python tools/server/loadtest_20.py 20 wss://<tunnel>.trycloudflare.com
"""
import asyncio
import json
import math
import struct
import sys
import time

import websockets

N = int(sys.argv[1]) if len(sys.argv) > 1 else 20
SPEAKERS = int(sys.argv[3]) if len(sys.argv) > 3 else N
LAYOUT = sys.argv[4] if len(sys.argv) > 4 else "packed"   # packed | groups
URL = sys.argv[2] if len(sys.argv) > 2 else "wss://wishing-others-regulation-home.trycloudflare.com"
STATE_HZ = 12.0
VOICE_HZ = 10.0
DURATION = 15.0          # seconds of simultaneous talking

RATE = 16000
CHUNK = int(RATE * 0.1)

stats = {
    "connected": 0, "failed": 0,
    "world_recv": 0, "voice_recv": 0,
    "voice_bytes_recv": 0, "voice_sent": 0,
    "lat_sum": 0.0, "lat_n": 0, "lat_max": 0.0,
    "errors": [],
}


def tone_chunk(cycle: int) -> bytes:
    """100 ms of 440 Hz int16 PCM with an embedded send-timestamp watermark
    in the first two samples for latency measurement."""
    now = time.time()
    head = struct.pack("<d", now)  # 8 bytes watermark
    body = b"".join(
        struct.pack("<h", int(0.4 * 32767 * math.sin(2 * math.pi * 440 * i / RATE)))
        for i in range(CHUNK - 4))
    return head + body


async def player(idx: int):
    pid = "load%04d%012d" % (idx, int(time.time() * 1000) % 1000000000000)
    name = "Load%02d" % idx
    try:
        t0 = time.time()
        ws = await asyncio.wait_for(websockets.connect(
            URL, max_size=2 ** 22, ping_interval=20), 12)
        stats["connected"] += 1
        connect_ms = (time.time() - t0) * 1000
        if idx == 0:
            print("[load] first connect: %.0f ms" % connect_ms, flush=True)
        await ws.send(json.dumps({"t": "join", "id": pid, "name": name}))
        await ws.recv()  # welcome

        async def talker():
            if idx >= SPEAKERS:
                return
            cycle = 0
            t_end = time.time() + DURATION
            while time.time() < t_end:
                await ws.send(pid.encode()[:16].ljust(16, b"\x00") + tone_chunk(cycle))
                stats["voice_sent"] += 1
                cycle += 1
                await asyncio.sleep(1.0 / VOICE_HZ)

        def pos():
            # packed: everyone inside a 10 m huddle (all hear all).
            # groups: 5 clusters of 4 around the room (breakout discussion).
            if LAYOUT == "groups":
                # 4 corner clusters (>=20 m apart, > VOICE_RANGE) of 5 each
                gx = [-10, 10, -10, 10][idx % 4]
                gz = [-10, -10, 10, 10][idx % 4]
                return gx + (idx // 4 - 2) * 0.9, gz + ((idx // 4) % 2 - 0.5) * 1.5
            return 10 * math.sin(idx), 10 * math.cos(idx)

        async def stater():
            t_end = time.time() + DURATION
            while time.time() < t_end:
                x, z = pos()
                await ws.send(json.dumps({"t": "state", "x": x, "z": z, "ry": 0, "moving": True}))
                await asyncio.sleep(1.0 / STATE_HZ)

        async def reader():
            t_end = time.time() + DURATION + 5
            while time.time() < t_end:
                try:
                    msg = await asyncio.wait_for(ws.recv(), 5)
                except asyncio.TimeoutError:
                    continue
                if isinstance(msg, bytes):
                    stats["voice_recv"] += 1
                    stats["voice_bytes_recv"] += len(msg)
                    sent = struct.unpack_from("<d", msg, 16)[0]
                    lat = (time.time() - sent) * 1000
                    stats["lat_sum"] += lat
                    stats["lat_n"] += 1
                    stats["lat_max"] = max(stats["lat_max"], lat)
                else:
                    stats["world_recv"] += 1

        await asyncio.gather(talker(), stater(), reader())
        await ws.close()
    except Exception as e:
        stats["failed"] += 1
        stats["errors"].append("p%d: %s" % (idx, type(e).__name__))


async def main():
    print("[load] %d players (%d speaking) -> %s, %.0fs" % (N, SPEAKERS, URL, DURATION), flush=True)
    t0 = time.time()
    await asyncio.gather(*(player(i) for i in range(N)))
    dt = time.time() - t0

    print("\n===== RESULTS (%d players, %.0f s) =====" % (N, dt))
    print("connects ok/fail : %d / %d" % (stats["connected"], stats["failed"]))
    if stats["errors"]:
        print("errors           : %s" % stats["errors"][:5])
    print("world frames rcv : %d  (%.1f/s overall)" % (stats["world_recv"], stats["world_recv"] / dt))
    # expected receivers per frame: all others when packed; own group when clustered
    per_frame = (N - 1) if LAYOUT != "groups" else max(0, (N + 3) // 4 - 1)
    exp_voice = stats["voice_sent"] * per_frame
    got = stats["voice_recv"]
    print("voice sent       : %d chunks (%.0f KB/s up total)" % (
        stats["voice_sent"], stats["voice_sent"] * 3216 / 1024 / DURATION))
    print("voice fanout rcv : %d / %d expected (%.1f%% delivered)" % (
        got, exp_voice, 100.0 * got / max(1, exp_voice)))
    print("downlink         : %.2f MB total, %.0f KB/s avg per player" % (
        stats["voice_bytes_recv"] / 1e6, stats["voice_bytes_recv"] / 1024 / DURATION / N))
    if stats["lat_n"]:
        print("latency avg/max  : %.0f ms / %.0f ms" % (
            stats["lat_sum"] / stats["lat_n"], stats["lat_max"]))
    print("[load] DONE", flush=True)


asyncio.run(main())
