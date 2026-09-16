# -*- coding: utf-8 -*-
import datetime
import os
import shutil
import sqlite3
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lsys import db, user_graph_scheduler as ugs  # noqa: E402


class UserGraphSchedulerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="user_graph_sched_")
        self.old_root = db.ROOT
        self.old_scheduler = db.DB_SCHEDULER
        db.ROOT = self.tmp
        db.DB_SCHEDULER = os.path.join(self.tmp, "scheduler.sqlite3")
        self.graph_db = os.path.join(self.tmp, "系统数据", "dual-end", "state", "dual-end.db")
        os.makedirs(os.path.dirname(self.graph_db), exist_ok=True)
        conn = sqlite3.connect(self.graph_db)
        conn.executescript("""
        CREATE TABLE graphs(
          graph_id TEXT PRIMARY KEY, question_key TEXT UNIQUE, question_source TEXT,
          source_id TEXT, center_node_id TEXT, graph_revision INTEGER, created_at TEXT, updated_at TEXT);
        CREATE TABLE nodes(
          node_id TEXT PRIMARY KEY, graph_id TEXT, title TEXT, body_markdown TEXT, deleted_at TEXT);
        INSERT INTO graphs VALUES
          ('g-user-1','user:ug-test-1','USER_AUTHORED','ug-test-1','n-center',1,'2026-09-14','2026-09-14');
        INSERT INTO nodes VALUES
          ('n-center','g-user-1','自拟事务题','事务隔离级别如何取舍？',NULL);
        """)
        conn.close()
        self.t0 = datetime.datetime.fromisoformat("2026-09-14T10:00:00+08:00")

    def tearDown(self):
        db.ROOT = self.old_root
        db.DB_SCHEDULER = self.old_scheduler
        shutil.rmtree(self.tmp)

    def test_high_sequence_register_show_complete(self):
        created = ugs.register("ug-test-1", "高频", now_dt=self.t0,
                               graph_db_path=self.graph_db)
        self.assertEqual(created["frequency"], "HIGH")
        self.assertEqual(created["cadence_days"], [1, 2, 4, 7, 14, 30])
        self.assertEqual(created["next_due_at"], "2026-09-15T10:00:00+08:00")

        self.assertEqual(ugs.list_schedules(True, self.t0, graph_db_path=self.graph_db), [])
        due = ugs.list_schedules(True, self.t0 + datetime.timedelta(days=1),
                                 graph_db_path=self.graph_db)
        self.assertEqual(due[0]["custom_id"], "ug-test-1")

        shown = ugs.mark_shown("ug-test-1", now_dt=self.t0 + datetime.timedelta(days=1))
        self.assertEqual(shown["next_due_at"], created["next_due_at"])
        completed = ugs.complete("ug-test-1", now_dt=self.t0 + datetime.timedelta(days=1))
        self.assertEqual(completed["interval_days"], 2)
        self.assertEqual(completed["next_due_at"], "2026-09-17T10:00:00+08:00")

        conn = sqlite3.connect(db.DB_SCHEDULER)
        event_types = [r[0] for r in conn.execute(
            "SELECT event_type FROM user_graph_review_events ORDER BY occurred_at,event_id")]
        conn.close()
        self.assertCountEqual(event_types, ["REGISTERED", "REVIEW_SHOWN", "REVIEW_COMPLETED"])

    def test_register_idempotent_and_frequency_change_preserves_progress(self):
        first = ugs.register("ug-test-1", "medium", now_dt=self.t0,
                             graph_db_path=self.graph_db)
        again = ugs.register("ug-test-1", "medium", now_dt=self.t0,
                             graph_db_path=self.graph_db)
        self.assertTrue(first["created"])
        self.assertFalse(again["created"])
        ugs.complete("ug-test-1", now_dt=self.t0 + datetime.timedelta(days=3))
        changed = ugs.set_frequency("ug-test-1", "低频",
                                    now_dt=self.t0 + datetime.timedelta(days=3),
                                    graph_db_path=self.graph_db)
        self.assertEqual(changed["frequency"], "LOW")
        self.assertEqual(changed["sequence_index"], 1)
        self.assertEqual(changed["next_due_at"], "2026-10-08T10:00:00+08:00")

    def test_unknown_graph_cannot_be_scheduled(self):
        with self.assertRaisesRegex(ValueError, "找不到自拟问题图"):
            ugs.register("ug-missing", "high", now_dt=self.t0,
                         graph_db_path=self.graph_db)


if __name__ == "__main__":
    unittest.main()
