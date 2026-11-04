#!/usr/bin/env python3
"""Unit tests for optional advisory routing (no network or Orca required)."""

import argparse
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import tempfile
import unittest

from route_agent import choose_effort, plan, quota_headroom


NOW = datetime(2026, 11, 5, 0, 0, tzinfo=timezone.utc)


class RoutingTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        base = Path(self.directory.name)
        self.config = base / "agents.json"
        self.usage = base / "usage.json"
        self.config.write_text(json.dumps({"agents": [
            {"id": "agent-a", "provider": "a", "quota_key": "a:main",
             "enabled": True, "strengths": {"backend": 5, "security": 5},
             "efforts": ["low", "medium", "high"]},
            {"id": "agent-b", "provider": "b", "quota_key": "b:main",
             "enabled": True, "strengths": {"backend": 4, "security": 4},
             "efforts": ["low", "medium", "high", "max"]},
            {"id": "agent-disabled", "quota_key": "c:main",
             "enabled": False, "strengths": {"backend": 5},
             "efforts": ["high"]},
        ]}))
        self.write_usage(10, 30)
        self.args = argparse.Namespace(
            difficulty="hard", domain="backend", risk="normal", delegate=False,
            config=self.config, usage=self.usage,
            max_age_minutes=30, reserve_percent=15,
        )

    def write_usage(self, a_used, b_used, observed_at=NOW):
        data = {"observed_at": observed_at.isoformat(), "pools": {
            "a:main": {"status": "available", "windows": [
                {"name": "5h", "used_percent": a_used},
                {"name": "weekly", "used_percent": a_used},
            ]},
            "b:main": {"status": "available", "windows": [
                {"name": "5h", "used_percent": b_used},
                {"name": "weekly", "used_percent": b_used},
            ]},
        }}
        self.usage.write_text(json.dumps(data))

    def test_easy_stays_in_session_without_any_quota_inputs(self):
        self.args.difficulty = "easy"
        self.args.config = None
        self.args.usage = None
        result = plan(self.args, NOW)
        self.assertEqual(result["decision"], "stay_local")
        self.assertEqual(result["effort"], "low")

    def test_moderate_stays_local_unless_delegation_benefits(self):
        self.args.difficulty = "moderate"
        self.assertEqual(plan(self.args, NOW)["decision"], "stay_local")
        self.args.delegate = True
        self.assertEqual(plan(self.args, NOW)["decision"], "delegate")

    def test_capability_wins_when_quota_is_similar(self):
        self.assertEqual(plan(self.args, NOW)["selected"]["agent"], "agent-a")

    def test_healthier_quota_can_change_selection(self):
        self.write_usage(82, 30)
        self.assertEqual(plan(self.args, NOW)["selected"]["agent"], "agent-b")

    def test_reserve_rejects_exhausted_pool(self):
        self.write_usage(99, 90)
        result = plan(self.args, NOW)
        self.assertEqual(result["decision"], "manual_review")
        self.assertTrue(any("reserve" in item["reason"] for item in result["rejected"]))

    def test_missing_or_stale_usage_never_becomes_fake_headroom(self):
        self.assertIsNone(quota_headroom({}, "a:main", NOW, 30)[0])
        self.write_usage(10, 10, NOW - timedelta(hours=1))
        self.assertEqual(plan(self.args, NOW)["decision"], "manual_review")

    def test_missing_pool_does_not_borrow_another_account_quota(self):
        self.write_usage(10, 10)
        data = json.loads(self.usage.read_text())
        del data["pools"]["a:main"]
        self.usage.write_text(json.dumps(data))
        self.assertEqual(plan(self.args, NOW)["selected"]["agent"], "agent-b")

    def test_multi_window_uses_most_constrained_window(self):
        data = json.loads(self.usage.read_text())
        data["pools"]["a:main"]["windows"][1]["used_percent"] = 95
        self.usage.write_text(json.dumps(data))
        self.assertEqual(plan(self.args, NOW)["selected"]["agent"], "agent-b")

    def test_critical_requires_strong_skill_and_independent_review(self):
        self.args.difficulty = "critical"
        result = plan(self.args, NOW)
        self.assertEqual(result["selected"]["agent"], "agent-a")
        self.assertTrue(result["independent_review_required"])

    def test_high_risk_requires_capable_agent_and_review(self):
        self.args.risk = "high"
        result = plan(self.args, NOW)
        self.assertTrue(result["independent_review_required"])

    def test_effort_fallback_does_not_invent_model_names(self):
        self.assertEqual(choose_effort(["low", "high"], "moderate"), "high")
        self.assertEqual(choose_effort(["medium", "high"], "critical"), "high")
        self.assertIsNone(choose_effort([], "hard"))

    def test_unavailable_pool_does_not_count_as_zero_usage(self):
        data = json.loads(self.usage.read_text())
        data["pools"]["a:main"] = {"status": "unavailable", "windows": []}
        self.usage.write_text(json.dumps(data))
        self.assertEqual(plan(self.args, NOW)["selected"]["agent"], "agent-b")

    def test_rejects_example_profiles_and_usage(self):
        data = json.loads(self.config.read_text())
        data["_example_only"] = True
        self.config.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "Example routing"):
            plan(self.args, NOW)

    def test_rejects_naive_timestamps(self):
        self.write_usage(10, 10)
        data = json.loads(self.usage.read_text())
        data["observed_at"] = "2026-11-05T00:00:00"
        self.usage.write_text(json.dumps(data))
        self.assertEqual(plan(self.args, NOW)["decision"], "manual_review")

    def test_expired_reset_forces_refresh(self):
        data = json.loads(self.usage.read_text())
        data["pools"]["a:main"]["windows"][0]["resets_at"] = (NOW - timedelta(minutes=1)).isoformat()
        self.usage.write_text(json.dumps(data))
        self.assertEqual(plan(self.args, NOW)["selected"]["agent"], "agent-b")


if __name__ == "__main__":
    unittest.main()
