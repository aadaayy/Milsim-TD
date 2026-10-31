"""Write the rounds of a level into its JSON file.

Rounds are made from a few dials below rather than typed out one by one, so
the whole curve can be retuned at once. Every number still lands in the
level's JSON, which is what the game reads.

Run from the repository root:  python3 Tools/make_waves.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEVEL = ROOT / "LastPerimeter" / "Data" / "level_01.json"

ROUNDS = 50
# Round each type first shows up, and how much of the round's threat it takes once it has.
TYPES = {
    #           first round, threat per zombie (in Walkers), share of the round
    "walker":   (1,    1.0,  1.0),
    "runner":   (3,    1.0,  0.6),
    "crawler":  (6,    1.6,  0.5),
    "screamer": (12,   2.2,  0.25),
    "bloater":  (16,   3.0,  0.35),
    "armored":  (21,   3.2,  0.5),
}
# Boss rounds: every tenth round brings Brutes; the halfway and final rounds bring the Behemoth.
BOSSES = {10: [("brute", 1)], 20: [("brute", 2)], 25: [("behemoth", 1)], 30: [("brute", 3)],
          40: [("brute", 4)], 45: [("brute", 3)], 50: [("behemoth", 1), ("brute", 4)]}
# From this round on, ordinary rounds can bring a Brute too.
BRUTES_FROM = 33


def threat(r):
    """How much horde a round holds, in Walkers."""
    return 8 + 1.6 * (r - 1) + 0.01 * (r - 1) ** 2


def health_scale(r):
    """Zombies get tougher every round."""
    return round(1 + 0.05 * (r - 1) + 0.0018 * (r - 1) ** 2, 3)


def boss_health_scale(r):
    """Bosses are already huge, so they toughen more slowly."""
    return round(health_scale(r) ** 0.5, 3)


def reward_scale(r):
    """Later zombies come in bigger numbers, so each pays a little less."""
    return round(1 / (1 + 0.2 * (r - 1)), 3)


def bonus(r):
    return 15 + 2 * r


def group(zombie, count, interval, delay, health, reward):
    spec = {"zombie": zombie, "count": count, "interval": interval, "delay": delay}
    if health != 1:
        spec["healthScale"] = health
    if reward != 1:
        spec["rewardScale"] = reward
    return spec


def round_spec(r):
    unlocked = {t: v for t, v in TYPES.items() if r >= v[0]}
    # The newest type gets a little extra share the round it arrives, so it's noticed.
    shares = {t: v[2] * (1.6 if r - v[0] < 2 else 1) for t, v in unlocked.items()}
    total_share = sum(shares.values())
    budget = threat(r)
    groups = []
    duration = min(18 + r * 0.5, 40)
    for i, (t, share) in enumerate(shares.items()):
        cost = unlocked[t][1]
        count = max(1, round(budget * share / total_share / cost))
        delay = round(i * 3.0, 1)
        interval = round(max(0.25, duration / count), 2)
        groups.append(group(t, count, interval, delay, health_scale(r), reward_scale(r)))
    if r >= BRUTES_FROM and r not in BOSSES:
        groups.append(group("brute", 1 + (r - BRUTES_FROM) // 6, 6, 10, boss_health_scale(r), reward_scale(r)))
    for t, n in BOSSES.get(r, []):
        groups.append(group(t, n, 5, round(duration * 0.5, 1), boss_health_scale(r), reward_scale(r)))
    spec = {"bonus": bonus(r), "groups": groups}
    if r in BOSSES:
        spec["boss"] = True
    return spec


def main():
    level = json.loads(LEVEL.read_text())
    level["waves"] = [round_spec(r) for r in range(1, ROUNDS + 1)]
    level["commandPostHealth"] = 20
    level["breakSeconds"] = 8
    LEVEL.write_text(json.dumps(level, indent=2) + "\n")
    print(f"{len(level['waves'])} rounds written to {LEVEL.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
