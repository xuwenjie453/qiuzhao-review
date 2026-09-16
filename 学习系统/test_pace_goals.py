# -*- coding: utf-8 -*-
import datetime as dt
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lsys import db, pace_goals  # noqa: E402


class PaceGoalServiceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="pace_goals_")
        self.old_root = db.ROOT
        self.old_scheduler = db.DB_SCHEDULER
        db.ROOT = self.tmp
        db.DB_SCHEDULER = os.path.join(self.tmp, "scheduler.sqlite3")
        self.service = pace_goals.PaceGoalService()

    def tearDown(self):
        db.ROOT = self.old_root
        db.DB_SCHEDULER = self.old_scheduler
        shutil.rmtree(self.tmp)

    @staticmethod
    def explanation_goal(**patch):
        goal = {
            "title": "新增解释节点",
            "daily_target": 8,
            "period_allocation": {"morning": 3, "afternoon": 3, "evening": 2},
            "progress_source": "AUTO",
            "detector_type": "EXPLANATION_NODE_CREATED",
            "lifecycle_type": "CONTINUOUS",
        }
        goal.update(patch)
        return goal

    def test_auto_progress_is_event_driven_idempotent_and_never_rolls_debt(self):
        goal = self.service.create(self.explanation_goal(), "2026-09-16T08:00:00+08:00")
        first = self.service.record_auto(
            "EXPLANATION_NODE_CREATED", "node-1", occurred_at="2026-09-16T10:00:00+08:00")
        self.assertEqual(len(first), 1)
        self.assertTrue(first[0]["recorded"])
        self.assertEqual(first[0]["period"], "MORNING")

        duplicate = self.service.record_auto(
            "EXPLANATION_NODE_CREATED", "node-1", occurred_at="2026-09-16T10:00:01+08:00")
        self.assertTrue(duplicate[0]["idempotent"])
        self.assertEqual(self.service.daily(goal["goal_id"], "2026-09-16")["daily_completed"], 1)

        # 次日没有历史欠账：目标仍为 8，新的当天投影从 0 开始。
        tomorrow = self.service.daily(goal["goal_id"], "2026-09-17")
        self.assertEqual(tomorrow["daily_completed"], 0)
        self.assertEqual(self.service.list()[0]["daily_target"], 8)

    def test_off_hours_still_count_once_in_a_defined_period(self):
        goal = self.service.create(self.explanation_goal(), "2026-09-16T08:00:00+08:00")
        early = self.service.record_auto("EXPLANATION_NODE_CREATED", "node-before-nine",
                                         occurred_at="2026-09-16T06:30:00+08:00")[0]
        late = self.service.record_auto("EXPLANATION_NODE_CREATED", "node-after-summary",
                                        occurred_at="2026-09-16T23:00:00+08:00")[0]
        self.assertEqual(early["period"], "MORNING")
        self.assertEqual(late["period"], "EVENING")
        daily = self.service.daily(goal["goal_id"], "2026-09-16")
        self.assertEqual((daily["morning_completed"], daily["afternoon_completed"], daily["evening_completed"]), (1, 0, 1))
        self.assertEqual(daily["daily_completed"], 2)

    def test_manual_finite_goal_keeps_daily_and_lifetime_progress_separate(self):
        goal = self.service.create({
            "title": "完成专题", "daily_target": 1,
            "period_allocation": {"morning": 1, "afternoon": 0, "evening": 0},
            "progress_source": "MANUAL", "lifecycle_type": "FINITE", "total_steps": 3,
        }, "2026-09-16T08:00:00+08:00")
        first = self.service.increment_manual(goal["goal_id"], 2, "2026-09-16T15:00:00+08:00")
        self.assertEqual(first["daily_progress"]["afternoon_completed"], 2)
        self.assertEqual(first["goal"]["completed_steps"], 2)
        second = self.service.increment_manual(goal["goal_id"], 2, "2026-09-16T20:00:00+08:00")
        self.assertEqual(second["delta"], 1)  # 有限目标不会超过 total_steps。
        self.assertEqual(second["goal"]["status"], "COMPLETED")
        self.assertEqual(second["goal"]["completed_steps"], 3)
        self.assertEqual(self.service.daily(goal["goal_id"], "2026-09-17")["daily_completed"], 0)

    def test_notification_is_aggregated_neutral_and_idempotent(self):
        first = self.service.create(self.explanation_goal(), "2026-09-16T08:00:00+08:00")
        second = self.service.create({
            "title": "日语单词", "daily_target": 20,
            "period_allocation": {"morning": 8, "afternoon": 6, "evening": 6},
            "progress_source": "MANUAL", "lifecycle_type": "CONTINUOUS",
        }, "2026-09-16T08:00:00+08:00")
        self.service.record_auto("EXPLANATION_NODE_CREATED", "node-for-note", occurred_at="2026-09-16T10:00:00+08:00")
        self.service.increment_manual(second["goal_id"], 5, "2026-09-16T10:30:00+08:00")

        rendered = self.service.render_notification("MORNING", "2026-09-16T09:01:00+08:00")
        self.assertEqual(len(rendered["items"]), 2)
        self.assertIn(first["title"], rendered["body_markdown"])
        self.assertIn(second["title"], rendered["body_markdown"])
        for forbidden in ("欠", "还差", "失败", "必须", "落后"):
            self.assertNotIn(forbidden, rendered["body_markdown"])

        delivered = self.service.send_notification("MORNING", "2026-09-16T09:01:00+08:00",
                                                   deliver=lambda _title, _body: (True, None))
        self.assertTrue(delivered["sent"])
        duplicate = self.service.send_notification("MORNING", "2026-09-16T09:02:00+08:00",
                                                    deliver=lambda _title, _body: (True, None))
        self.assertTrue(duplicate["idempotent"])
        self.assertEqual(self.service.due_slot("2026-09-16T09:03:00+08:00"), "MORNING")
        self.assertIsNone(self.service.due_slot("2026-09-16T09:04:00+08:00"))

    def test_pause_removes_goal_from_active_summary_without_losing_history(self):
        goal = self.service.create(self.explanation_goal(), "2026-09-16T08:00:00+08:00")
        self.service.record_auto("EXPLANATION_NODE_CREATED", "node-pause", occurred_at="2026-09-16T10:00:00+08:00")
        paused = self.service.set_status(goal["goal_id"], "PAUSED", "2026-09-16T11:00:00+08:00")
        self.assertEqual(paused["status"], "PAUSED")
        self.assertEqual(self.service.summary("2026-09-16"), [])
        self.assertEqual(self.service.daily(goal["goal_id"], "2026-09-16")["daily_completed"], 1)


if __name__ == "__main__":
    unittest.main()
