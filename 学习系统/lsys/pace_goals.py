# -*- coding: utf-8 -*-
"""步频目标（PaceGoal）服务。

步频记录的是发生过的推进事实，不是待办、倒计时或跨日欠账。
所有写入都经过本服务：`pace_progress_events` 是事实，
`pace_daily_progress` 只是按自然日和时段聚合出的投影。
"""
from __future__ import annotations

import datetime as dt
import json
import sqlite3
import subprocess
from typing import Any, Callable
from zoneinfo import ZoneInfo

from . import db


PACE_TIME_ZONE = ZoneInfo("Asia/Shanghai")
PERIODS = ("MORNING", "AFTERNOON", "EVENING")
SLOTS: dict[str, tuple[int, int, str]] = {
    "MORNING": (9, 0, "早间步频"),
    "AFTERNOON": (13, 0, "午间步频"),
    "EVENING": (19, 0, "晚间步频"),
    "NIGHT": (22, 30, "今日步频总结"),
}


def _local_time(value: dt.datetime | str | None = None) -> dt.datetime:
    if value is None:
        return dt.datetime.now(PACE_TIME_ZONE)
    if isinstance(value, str):
        value = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if value.tzinfo is None:
        return value.replace(tzinfo=PACE_TIME_ZONE)
    return value.astimezone(PACE_TIME_ZONE)


def _iso(value: dt.datetime | str | None = None) -> str:
    return _local_time(value).isoformat(timespec="seconds")


def _date(value: dt.datetime | str | None = None) -> str:
    return _local_time(value).date().isoformat()


def period_for(value: dt.datetime | str | None = None) -> str:
    """所有时刻必须归入一个时段；深夜/清晨归上午，22:30 后归晚上。"""
    hour = _local_time(value).hour
    if hour < 13:
        return "MORNING"
    if hour < 19:
        return "AFTERNOON"
    return "EVENING"


def _positive_int(value: Any, name: str, *, allow_zero: bool = False) -> int:
    if isinstance(value, bool):
        raise ValueError(f"{name} 必须是整数")
    try:
        number = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{name} 必须是整数") from exc
    if number < 0 or (number == 0 and not allow_zero):
        sign = "非负整数" if allow_zero else "正整数"
        raise ValueError(f"{name} 必须是{sign}")
    return number


def _row_dict(row: sqlite3.Row | None) -> dict | None:
    return dict(row) if row is not None else None


class PaceGoalService:
    """根 scheduler.sqlite3 上的 PaceGoal 领域服务。"""

    def __init__(self, scheduler_path: str | None = None):
        self.scheduler_path = scheduler_path or db.DB_SCHEDULER

    def _connect(self) -> sqlite3.Connection:
        # 调用 init=True 会把新增的 pace_schema.sql 以 additive migration 方式应用到旧库。
        return db.connect(self.scheduler_path, init=True)

    @staticmethod
    def _goal_payload(row: sqlite3.Row) -> dict:
        out = dict(row)
        out["daily_target"] = int(out["daily_target"])
        for field in ("morning_target", "afternoon_target", "evening_target", "completed_steps"):
            out[field] = int(out[field])
        if out["total_steps"] is not None:
            out["total_steps"] = int(out["total_steps"])
        return out

    @staticmethod
    def _append_goal_event(conn: sqlite3.Connection, goal_id: str, event_type: str,
                           at: str, payload: dict | None = None) -> None:
        conn.execute(
            """INSERT INTO pace_goal_events(event_id,goal_id,occurred_at,event_type,payload_json)
               VALUES (?,?,?,?,?)""",
            (db.uid("pge"), goal_id, at, event_type,
             json.dumps(payload or {}, ensure_ascii=False, separators=(",", ":"))),
        )

    @staticmethod
    def _normalize_spec(spec: dict) -> dict:
        if not isinstance(spec, dict):
            raise ValueError("步频目标必须是对象")
        title = str(spec.get("title", "")).strip()
        if not title or len(title) > 80:
            raise ValueError("title 不能为空且最多 80 字")
        allocation = spec.get("period_allocation") or {}
        daily = _positive_int(spec.get("daily_target"), "daily_target")
        morning = _positive_int(spec.get("morning_target", allocation.get("morning")), "morning_target", allow_zero=True)
        afternoon = _positive_int(spec.get("afternoon_target", allocation.get("afternoon")), "afternoon_target", allow_zero=True)
        evening = _positive_int(spec.get("evening_target", allocation.get("evening")), "evening_target", allow_zero=True)
        if morning + afternoon + evening != daily:
            raise ValueError("morning_target + afternoon_target + evening_target 必须等于 daily_target")
        source = str(spec.get("progress_source", "MANUAL")).upper()
        if source not in ("AUTO", "MANUAL"):
            raise ValueError("progress_source 必须是 AUTO 或 MANUAL")
        detector = spec.get("detector_type")
        if source == "AUTO":
            detector = str(detector or "").strip()
            if not detector:
                raise ValueError("AUTO 目标必须指定 detector_type")
        else:
            detector = None
        lifecycle = str(spec.get("lifecycle_type", "CONTINUOUS")).upper()
        if lifecycle not in ("CONTINUOUS", "FINITE"):
            raise ValueError("lifecycle_type 必须是 CONTINUOUS 或 FINITE")
        total_steps = spec.get("total_steps")
        if lifecycle == "FINITE":
            total_steps = _positive_int(total_steps, "total_steps")
        else:
            total_steps = None
        description = spec.get("description")
        description = str(description).strip() if description is not None else None
        return {
            "title": title,
            "description": description or None,
            "daily_target": daily,
            "morning_target": morning,
            "afternoon_target": afternoon,
            "evening_target": evening,
            "progress_source": source,
            "detector_type": detector,
            "lifecycle_type": lifecycle,
            "total_steps": total_steps,
        }

    def create(self, spec: dict, now_dt: dt.datetime | str | None = None) -> dict:
        values = self._normalize_spec(spec)
        now = _iso(now_dt)
        goal_id = db.uid("pace")
        conn = self._connect()
        try:
            with conn:
                conn.execute(
                    """INSERT INTO pace_goals(
                        goal_id,title,description,daily_target,morning_target,afternoon_target,evening_target,
                        progress_source,detector_type,lifecycle_type,total_steps,completed_steps,status,
                        created_at,updated_at,completed_at,completed_local_date)
                       VALUES (?,?,?,?,?,?,?,?,?,?,?,0,'ACTIVE',?,?,NULL,NULL)""",
                    (goal_id, values["title"], values["description"], values["daily_target"],
                     values["morning_target"], values["afternoon_target"], values["evening_target"],
                     values["progress_source"], values["detector_type"], values["lifecycle_type"],
                     values["total_steps"], now, now),
                )
                self._append_goal_event(conn, goal_id, "PACE_GOAL_CREATED", now, values)
                row = conn.execute("SELECT * FROM pace_goals WHERE goal_id=?", (goal_id,)).fetchone()
            return self._goal_payload(row)
        finally:
            conn.close()

    def list(self, status: str | None = None) -> list[dict]:
        conn = self._connect()
        try:
            if status:
                status = status.upper()
                rows = conn.execute("SELECT * FROM pace_goals WHERE status=? ORDER BY created_at", (status,)).fetchall()
            else:
                rows = conn.execute("SELECT * FROM pace_goals ORDER BY created_at").fetchall()
            return [self._goal_payload(row) for row in rows]
        finally:
            conn.close()

    def _find_goal(self, conn: sqlite3.Connection, goal_ref: str) -> sqlite3.Row:
        row = conn.execute("SELECT * FROM pace_goals WHERE goal_id=?", (goal_ref,)).fetchone()
        if row:
            return row
        rows = conn.execute("SELECT * FROM pace_goals WHERE title=? ORDER BY created_at DESC", (goal_ref,)).fetchall()
        if not rows:
            raise ValueError("找不到步频目标")
        if len(rows) > 1:
            raise ValueError("同名步频目标不唯一，请使用 goal_id")
        return rows[0]

    def set_status(self, goal_ref: str, status: str, now_dt: dt.datetime | str | None = None) -> dict:
        status = status.upper()
        if status not in ("ACTIVE", "PAUSED"):
            raise ValueError("只可把目标设为 ACTIVE 或 PAUSED")
        now = _iso(now_dt)
        conn = self._connect()
        try:
            with conn:
                goal = self._find_goal(conn, goal_ref)
                if goal["status"] == "COMPLETED":
                    raise ValueError("已完成的有限目标不能恢复或暂停")
                if goal["status"] != status:
                    conn.execute("UPDATE pace_goals SET status=?,updated_at=? WHERE goal_id=?", (status, now, goal["goal_id"]))
                    self._append_goal_event(conn, goal["goal_id"],
                                            "PACE_GOAL_RESUMED" if status == "ACTIVE" else "PACE_GOAL_PAUSED", now)
                row = conn.execute("SELECT * FROM pace_goals WHERE goal_id=?", (goal["goal_id"],)).fetchone()
            return self._goal_payload(row)
        finally:
            conn.close()

    def update(self, goal_ref: str, patch: dict, now_dt: dt.datetime | str | None = None) -> dict:
        """更新可配置项；每日与进度历史绝不回写。"""
        now = _iso(now_dt)
        conn = self._connect()
        try:
            with conn:
                goal = self._find_goal(conn, goal_ref)
                if goal["status"] == "COMPLETED":
                    raise ValueError("已完成的有限目标不可修改")
                if not isinstance(patch, dict):
                    raise ValueError("更新内容必须是对象")
                merged = self._goal_payload(goal)
                merged.update({k: v for k, v in patch.items() if k != "goal_id"})
                values = self._normalize_spec(merged)
                if values["lifecycle_type"] == "FINITE" and int(goal["completed_steps"]) > values["total_steps"]:
                    raise ValueError("total_steps 不能小于已有完成量")
                conn.execute(
                    """UPDATE pace_goals SET title=?,description=?,daily_target=?,morning_target=?,afternoon_target=?,
                       evening_target=?,progress_source=?,detector_type=?,lifecycle_type=?,total_steps=?,updated_at=?
                       WHERE goal_id=?""",
                    (values["title"], values["description"], values["daily_target"], values["morning_target"],
                     values["afternoon_target"], values["evening_target"], values["progress_source"],
                     values["detector_type"], values["lifecycle_type"], values["total_steps"], now, goal["goal_id"]),
                )
                self._append_goal_event(conn, goal["goal_id"], "PACE_GOAL_UPDATED", now, values)
                row = conn.execute("SELECT * FROM pace_goals WHERE goal_id=?", (goal["goal_id"],)).fetchone()
            return self._goal_payload(row)
        finally:
            conn.close()

    @staticmethod
    def _empty_daily(goal_id: str, local_date: str) -> dict:
        return {
            "goal_id": goal_id, "local_date": local_date,
            "morning_completed": 0, "afternoon_completed": 0,
            "evening_completed": 0, "daily_completed": 0,
        }

    def _record(self, conn: sqlite3.Connection, goal: sqlite3.Row, delta: int,
                source: str, occurred_at: dt.datetime | str | None, source_ref: str | None,
                detector_type: str | None, payload: dict | None) -> dict:
        if goal["status"] != "ACTIVE":
            return {"goal_id": goal["goal_id"], "recorded": False, "reason": "GOAL_NOT_ACTIVE"}
        requested = _positive_int(delta, "increment")
        local = _local_time(occurred_at)
        at = _iso(local)
        local_date = local.date().isoformat()
        period = period_for(local)
        applied = requested
        if goal["lifecycle_type"] == "FINITE":
            applied = min(requested, int(goal["total_steps"]) - int(goal["completed_steps"]))
        if applied <= 0:
            return {"goal_id": goal["goal_id"], "recorded": False, "reason": "GOAL_ALREADY_COMPLETED"}
        event_id = db.uid("ppe")
        try:
            conn.execute(
                """INSERT INTO pace_progress_events(
                    event_id,goal_id,occurred_at,local_date,period,delta,progress_source,
                    detector_type,source_ref,payload_json,created_at)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
                (event_id, goal["goal_id"], at, local_date, period, applied, source, detector_type, source_ref,
                 json.dumps(payload or {}, ensure_ascii=False, separators=(",", ":")), at),
            )
        except sqlite3.IntegrityError:
            # AUTO 的 (goal_id, node_id) 唯一约束命中：重复回调不重复计数。
            prior = conn.execute(
                "SELECT event_id,delta,local_date,period FROM pace_progress_events WHERE goal_id=? AND source_ref=?",
                (goal["goal_id"], source_ref),
            ).fetchone()
            if prior:
                return {"goal_id": goal["goal_id"], "recorded": False, "idempotent": True,
                        "event_id": prior["event_id"], "delta": int(prior["delta"]),
                        "local_date": prior["local_date"], "period": prior["period"]}
            raise
        amounts = {"MORNING": (applied, 0, 0), "AFTERNOON": (0, applied, 0), "EVENING": (0, 0, applied)}[period]
        conn.execute(
            """INSERT INTO pace_daily_progress(
                 goal_id,local_date,morning_completed,afternoon_completed,evening_completed,daily_completed,created_at,updated_at)
               VALUES (?,?,?,?,?,?,?,?)
               ON CONFLICT(goal_id,local_date) DO UPDATE SET
                 morning_completed=morning_completed+excluded.morning_completed,
                 afternoon_completed=afternoon_completed+excluded.afternoon_completed,
                 evening_completed=evening_completed+excluded.evening_completed,
                 daily_completed=daily_completed+excluded.daily_completed,
                 updated_at=excluded.updated_at""",
            (goal["goal_id"], local_date, *amounts, applied, at, at),
        )
        completed = int(goal["completed_steps"])
        status = goal["status"]
        if goal["lifecycle_type"] == "FINITE":
            completed += applied
            if completed >= int(goal["total_steps"]):
                status = "COMPLETED"
            conn.execute(
                """UPDATE pace_goals SET completed_steps=?,status=?,updated_at=?,
                   completed_at=CASE WHEN ?='COMPLETED' THEN ? ELSE completed_at END,
                   completed_local_date=CASE WHEN ?='COMPLETED' THEN ? ELSE completed_local_date END
                   WHERE goal_id=?""",
                (completed, status, at, status, at, status, local_date, goal["goal_id"]),
            )
            if status == "COMPLETED":
                self._append_goal_event(conn, goal["goal_id"], "PACE_GOAL_COMPLETED", at,
                                        {"completed_steps": completed, "total_steps": int(goal["total_steps"])})
        else:
            conn.execute("UPDATE pace_goals SET updated_at=? WHERE goal_id=?", (at, goal["goal_id"]))
        daily = conn.execute(
            "SELECT * FROM pace_daily_progress WHERE goal_id=? AND local_date=?", (goal["goal_id"], local_date)
        ).fetchone()
        updated_goal = conn.execute("SELECT * FROM pace_goals WHERE goal_id=?", (goal["goal_id"],)).fetchone()
        return {"goal_id": goal["goal_id"], "recorded": True, "event_id": event_id, "delta": applied,
                "requested_delta": requested, "local_date": local_date, "period": period,
                "daily_progress": dict(daily), "goal": self._goal_payload(updated_goal)}

    def increment_manual(self, goal_ref: str, increment: int = 1,
                         occurred_at: dt.datetime | str | None = None, note: str | None = None) -> dict:
        conn = self._connect()
        try:
            with conn:
                goal = self._find_goal(conn, goal_ref)
                if goal["progress_source"] != "MANUAL":
                    raise ValueError("AUTO 目标由系统事件记录，不能手动累加")
                return self._record(conn, goal, increment, "MANUAL", occurred_at, None, None,
                                    {"note": note} if note else None)
        finally:
            conn.close()

    def record_auto(self, detector_type: str, source_ref: str, increment: int = 1,
                    occurred_at: dt.datetime | str | None = None, payload: dict | None = None) -> list[dict]:
        detector_type = str(detector_type or "").strip()
        source_ref = str(source_ref or "").strip()
        if not detector_type or not source_ref:
            raise ValueError("AUTO 进度必须指定 detector_type 与 source_ref")
        conn = self._connect()
        try:
            with conn:
                goals = conn.execute(
                    """SELECT * FROM pace_goals
                       WHERE status='ACTIVE' AND progress_source='AUTO' AND detector_type=?
                       ORDER BY created_at""", (detector_type,)
                ).fetchall()
                return [self._record(conn, goal, increment, "AUTO", occurred_at, source_ref,
                                     detector_type, payload) for goal in goals]
        finally:
            conn.close()

    def daily(self, goal_ref: str, local_date: str | None = None) -> dict:
        local_date = local_date or _date()
        conn = self._connect()
        try:
            goal = self._find_goal(conn, goal_ref)
            row = conn.execute(
                "SELECT * FROM pace_daily_progress WHERE goal_id=? AND local_date=?", (goal["goal_id"], local_date)
            ).fetchone()
            return dict(row) if row else self._empty_daily(goal["goal_id"], local_date)
        finally:
            conn.close()

    def summary(self, local_date: str | None = None) -> list[dict]:
        local_date = local_date or _date()
        conn = self._connect()
        try:
            rows = conn.execute(
                """SELECT g.*,p.morning_completed,p.afternoon_completed,p.evening_completed,p.daily_completed
                   FROM pace_goals g
                   LEFT JOIN pace_daily_progress p ON p.goal_id=g.goal_id AND p.local_date=?
                   WHERE g.status='ACTIVE' OR g.completed_local_date=?
                   ORDER BY g.created_at""", (local_date, local_date)
            ).fetchall()
            items = []
            for row in rows:
                item = self._goal_payload(row)
                for key in ("morning_completed", "afternoon_completed", "evening_completed", "daily_completed"):
                    item[key] = int(row[key] or 0)
                item["local_date"] = local_date
                items.append(item)
            return items
        finally:
            conn.close()

    def render_notification(self, slot: str, now_dt: dt.datetime | str | None = None) -> dict:
        slot = slot.upper()
        if slot not in SLOTS:
            raise ValueError("slot 必须是 MORNING、AFTERNOON、EVENING 或 NIGHT")
        local = _local_time(now_dt)
        items = self.summary(local.date().isoformat())
        title = SLOTS[slot][2]
        blocks: list[str] = []
        for item in items:
            lines = [item["title"], f"今日 {item['daily_completed']} / {item['daily_target']}"]
            if slot == "MORNING":
                lines.append(f"上午 {item['morning_completed']} / {item['morning_target']}")
            elif slot == "AFTERNOON":
                lines.extend([f"上午 {item['morning_completed']} / {item['morning_target']}",
                              f"下午目标 {item['afternoon_target']}"])
            elif slot == "EVENING":
                lines.extend([f"下午 {item['afternoon_completed']} / {item['afternoon_target']}",
                              f"晚上目标 {item['evening_target']}"])
            else:
                lines.extend([
                    f"上午 {item['morning_completed']} / {item['morning_target']}",
                    f"下午 {item['afternoon_completed']} / {item['afternoon_target']}",
                    f"晚上 {item['evening_completed']} / {item['evening_target']}",
                ])
            if item["lifecycle_type"] == "FINITE":
                lines.append(f"总进度 {item['completed_steps']} / {item['total_steps']}")
            if item["status"] == "COMPLETED":
                lines.append("✓ 目标已完成")
            blocks.append("\n".join(lines))
        return {"local_date": local.date().isoformat(), "slot": slot, "title": title,
                "body_markdown": "\n\n".join(blocks), "items": items}

    @staticmethod
    def _macos_notify(title: str, body: str) -> tuple[bool, str | None]:
        script = 'on run argv\n display notification (item 1 of argv) with title (item 2 of argv)\nend run'
        try:
            run = subprocess.run(["osascript", "-e", script, body, title], text=True,
                                 capture_output=True, check=False, timeout=10)
        except (OSError, subprocess.TimeoutExpired) as exc:
            return False, str(exc)
        if run.returncode != 0:
            return False, (run.stderr or run.stdout or "osascript failed").strip()
        return True, None

    def send_notification(self, slot: str, now_dt: dt.datetime | str | None = None,
                          deliver: Callable[[str, str], tuple[bool, str | None]] | None = None) -> dict:
        rendered = self.render_notification(slot, now_dt)
        if not rendered["items"]:
            return {"sent": False, "reason": "NO_ACTIVE_GOALS", **rendered}
        now = _iso(now_dt)
        conn = self._connect()
        try:
            with conn:
                prior = conn.execute(
                    "SELECT * FROM pace_notification_runs WHERE local_date=? AND slot=?",
                    (rendered["local_date"], rendered["slot"]),
                ).fetchone()
                if prior:
                    return {"sent": False, "idempotent": True, "notification": dict(prior)}
                conn.execute(
                    """INSERT INTO pace_notification_runs(local_date,slot,status,title,body_markdown,created_at)
                       VALUES (?,?,'PENDING',?,?,?)""",
                    (rendered["local_date"], rendered["slot"], rendered["title"], rendered["body_markdown"], now),
                )
            ok, error = (deliver or self._macos_notify)(rendered["title"], rendered["body_markdown"])
            with conn:
                conn.execute(
                    """UPDATE pace_notification_runs SET status=?,sent_at=?,error_text=?
                       WHERE local_date=? AND slot=?""",
                    ("SENT" if ok else "FAILED", now if ok else None, error,
                     rendered["local_date"], rendered["slot"]),
                )
            return {"sent": bool(ok), "error": error, **rendered}
        finally:
            conn.close()

    def due_slot(self, now_dt: dt.datetime | str | None = None) -> str | None:
        now = _local_time(now_dt)
        # 守护进程每 30 秒检查一次；只发送 3 分钟窗口内的“当前”推送，不补发已错过的时段。
        for slot, (hour, minute, _) in SLOTS.items():
            scheduled = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
            if scheduled <= now <= scheduled + dt.timedelta(minutes=3):
                return slot

        return None

    def send_due(self, now_dt: dt.datetime | str | None = None,
                 deliver: Callable[[str, str], tuple[bool, str | None]] | None = None) -> dict:
        now = _local_time(now_dt)
        slot = self.due_slot(now)
        if slot:
            return self.send_notification(slot, now, deliver=deliver)
        return {"sent": False, "reason": "NOT_DUE", "local_date": now.date().isoformat()}
