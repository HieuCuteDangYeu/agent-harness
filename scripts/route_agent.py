#!/usr/bin/env python3
"""Advisory, agent-neutral routing. Orca remains the execution control plane."""

import argparse
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import sys

DIFFICULTIES = ("trivial", "easy", "moderate", "hard", "critical")
EFFORT_ORDER = ("low", "medium", "high", "max")
EFFORT_TARGET = {
    "trivial": "low",
    "easy": "low",
    "moderate": "medium",
    "hard": "high",
    "critical": "max",
}


def read_json(path):
    with open(path, encoding="utf-8") as stream:
        return json.load(stream)


def parse_timestamp(value):
    if not isinstance(value, str):
        raise ValueError("timestamp must be an ISO-8601 string")
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError("timestamp must include UTC offset")
    return parsed.astimezone(timezone.utc)


def choose_effort(supported, difficulty):
    if not isinstance(supported, list) or not supported:
        return None
    ranks = {value: index for index, value in enumerate(EFFORT_ORDER)}
    supported = [value for value in supported if value in ranks]
    if not supported:
        return None
    desired = ranks[EFFORT_TARGET[difficulty]]
    higher = [value for value in supported if ranks[value] >= desired]
    return min(higher, key=lambda value: ranks[value]) if higher else max(
        supported, key=lambda value: ranks[value]
    )


def quota_headroom(usage, quota_key, now, max_age_minutes):
    if not isinstance(usage, dict):
        return None, "usage snapshot missing"
    try:
        observed_at = parse_timestamp(usage.get("observed_at"))
    except (TypeError, ValueError):
        return None, "usage timestamp missing or invalid"
    age = now - observed_at
    if age < -timedelta(minutes=2) or age > timedelta(minutes=max_age_minutes):
        return None, "usage snapshot is stale or future-dated"
    pools = usage.get("pools")
    if not isinstance(pools, dict):
        return None, "quota pools unavailable"
    entry = pools.get(quota_key)
    if not isinstance(entry, dict):
        return None, "quota pool not reported"
    if entry.get("status") != "available":
        return None, "quota pool unavailable or status unknown"
    windows = entry.get("windows")
    if not isinstance(windows, list) or not windows:
        return None, "quota windows unavailable"
    remaining = []
    for window in windows:
        used = window.get("used_percent") if isinstance(window, dict) else None
        if isinstance(used, bool) or not isinstance(used, (int, float)) or not 0 <= used <= 100:
            return None, "invalid or unknown usage percentage"
        if window.get("resets_at"):
            try:
                if parse_timestamp(window["resets_at"]) <= now:
                    return None, "quota window reset; refresh usage snapshot"
            except (TypeError, ValueError):
                return None, "invalid quota reset time"
        remaining.append(100 - used)
    return min(remaining), None


def plan(args, now=None):
    now = now or datetime.now(timezone.utc)
    domain_names = [part.strip().lower() for part in args.domain.split(",") if part.strip()]
    if not domain_names:
        raise ValueError("at least one task domain is required")
    requires_review = args.risk == "high" or args.difficulty == "critical"

    # Stay in the current session unless an actual ownership/capability boundary
    # justifies a worker. Never create a worker solely to reduce reasoning effort.
    if args.difficulty in ("trivial", "easy") or (
        args.difficulty == "moderate" and not args.delegate
    ):
        return {
            "decision": "stay_local",
            "effort": EFFORT_TARGET[args.difficulty],
            "independent_review_required": requires_review,
            "reason": "Task is bounded; use the current agent/session and targeted checks.",
        }

    if not args.config or not args.usage:
        return {
            "decision": "manual_review",
            "reason": "Delegation requires agent profiles and a fresh Orca usage snapshot; no live quota API is assumed.",
            "independent_review_required": requires_review,
        }

    config = read_json(args.config)
    usage = read_json(args.usage)
    if config.get("_example_only") or usage.get("_example_only"):
        raise ValueError("Example routing profiles/usage are not verified data; edit copies first")
    agents = config.get("agents")
    if not isinstance(agents, list):
        raise ValueError("agent configuration must contain an agents array")

    minimum_skill = 4 if args.difficulty == "critical" or args.risk == "high" else (
        3 if args.difficulty == "hard" else 2
    )
    eligible = []
    rejected = []
    for agent in agents:
        if not isinstance(agent, dict) or not isinstance(agent.get("id"), str):
            raise ValueError("each agent profile must have a string id")
        agent_id = agent["id"]
        if agent.get("enabled") is not True:
            rejected.append({"agent": agent_id, "reason": "disabled"})
            continue
        strengths = agent.get("strengths") or {}
        values = [strengths.get(domain, 0) for domain in domain_names]
        if any(isinstance(v, bool) or not isinstance(v, (int, float)) or not 0 <= v <= 5 for v in values):
            raise ValueError("strengths must be numeric scores between 0 and 5")
        if min(values) < minimum_skill:
            rejected.append({"agent": agent_id, "reason": "insufficient task-specific capability"})
            continue
        pool = agent.get("quota_key")
        if not isinstance(pool, str) or not pool:
            rejected.append({"agent": agent_id, "reason": "quota_key not configured"})
            continue
        remaining, error = quota_headroom(usage, pool, now, args.max_age_minutes)
        if error:
            rejected.append({"agent": agent_id, "reason": error})
            continue
        if remaining <= args.reserve_percent:
            rejected.append({"agent": agent_id, "reason": "quota headroom below reserve"})
            continue
        effort = choose_effort(agent.get("efforts"), args.difficulty)
        if effort is None:
            rejected.append({"agent": agent_id, "reason": "reasoning effort support not configured"})
            continue
        strength = sum(values) / len(values)
        # Capability dominates, but a substantially healthier quota pool can
        # break ties; approaching 80% usage is intentionally discouraged.
        score = 20 * strength + 0.35 * remaining - (10 if remaining <= 20 else 0)
        eligible.append({
            "agent": agent_id,
            "provider": agent.get("provider", agent_id),
            "quota_key": pool,
            "effort": effort,
            "model": (agent.get("models") or {}).get(effort),
            "strength": round(strength, 2),
            "remaining_percent": round(remaining, 2),
            "score": round(score, 2),
        })

    eligible.sort(key=lambda row: (-row["score"], -row["remaining_percent"], row["agent"]))
    if not eligible:
        return {
            "decision": "manual_review",
            "reason": "No qualified agent has verified fresh quota headroom; refresh Orca Usage or stay local.",
            "independent_review_required": requires_review,
            "rejected": rejected,
        }
    return {
        "decision": "delegate",
        "selected": eligible[0],
        "alternatives": eligible[1:4],
        "independent_review_required": requires_review,
        "reason": "Advisory selection using task capability, supported effort, and the tightest reported quota window. Launch through Orca's live orchestration guide.",
        "usage_observed_at": usage["observed_at"],
        "rejected": rejected,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--difficulty", choices=DIFFICULTIES, required=True)
    parser.add_argument("--domain", required=True, help="Comma-separated task domains from agent profiles")
    parser.add_argument("--risk", choices=("normal", "high"), default="normal")
    parser.add_argument("--delegate", action="store_true", help="Request a worker for a moderate task")
    parser.add_argument("--config", type=Path, help="Agent profiles JSON (not the example)")
    parser.add_argument("--usage", type=Path, help="Fresh Orca Usage snapshot JSON")
    parser.add_argument("--max-age-minutes", type=int, default=30)
    parser.add_argument("--reserve-percent", type=float, default=15)
    args = parser.parse_args(argv)
    if args.max_age_minutes <= 0 or not 0 <= args.reserve_percent < 100:
        parser.error("invalid age or quota reserve")
    try:
        decision = plan(args)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"decision": "error", "reason": str(error)}))
        return 2
    print(json.dumps(decision, indent=2, sort_keys=True))
    return 0 if decision["decision"] != "manual_review" else 3


if __name__ == "__main__":
    sys.exit(main())
