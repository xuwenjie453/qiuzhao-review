-- PaceGoal V1：每日步频是独立于学习 Goal / Review schedule 的事实记录。
-- 它不保存跨日欠账；每天都从同一个目标开始，历史只用于回顾。

CREATE TABLE IF NOT EXISTS pace_goals (
    goal_id           TEXT PRIMARY KEY,
    title             TEXT NOT NULL,
    description       TEXT,
    daily_target      INTEGER NOT NULL CHECK(daily_target > 0),
    morning_target    INTEGER NOT NULL CHECK(morning_target >= 0),
    afternoon_target  INTEGER NOT NULL CHECK(afternoon_target >= 0),
    evening_target    INTEGER NOT NULL CHECK(evening_target >= 0),
    progress_source   TEXT NOT NULL CHECK(progress_source IN ('AUTO','MANUAL')),
    detector_type     TEXT,
    lifecycle_type    TEXT NOT NULL CHECK(lifecycle_type IN ('CONTINUOUS','FINITE')),
    total_steps       INTEGER,
    completed_steps   INTEGER NOT NULL DEFAULT 0 CHECK(completed_steps >= 0),
    status            TEXT NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','PAUSED','COMPLETED')),
    created_at        TEXT NOT NULL,
    updated_at        TEXT NOT NULL,
    completed_at      TEXT,
    completed_local_date TEXT,
    CHECK(morning_target + afternoon_target + evening_target = daily_target),
    CHECK((progress_source='AUTO' AND detector_type IS NOT NULL AND length(detector_type) > 0)
       OR (progress_source='MANUAL' AND detector_type IS NULL)),
    CHECK((lifecycle_type='FINITE' AND total_steps IS NOT NULL AND total_steps > 0)
       OR (lifecycle_type='CONTINUOUS' AND total_steps IS NULL)),
    CHECK(total_steps IS NULL OR completed_steps <= total_steps),
    CHECK(status <> 'COMPLETED' OR lifecycle_type='FINITE')
);
CREATE INDEX IF NOT EXISTS idx_pace_goals_status ON pace_goals(status);
CREATE INDEX IF NOT EXISTS idx_pace_goals_detector ON pace_goals(status, progress_source, detector_type);

-- 每个自然日的事实投影。没有跨日迁移、也没有“欠账”字段。
CREATE TABLE IF NOT EXISTS pace_daily_progress (
    goal_id             TEXT NOT NULL REFERENCES pace_goals(goal_id),
    local_date          TEXT NOT NULL,
    morning_completed   INTEGER NOT NULL DEFAULT 0 CHECK(morning_completed >= 0),
    afternoon_completed INTEGER NOT NULL DEFAULT 0 CHECK(afternoon_completed >= 0),
    evening_completed   INTEGER NOT NULL DEFAULT 0 CHECK(evening_completed >= 0),
    daily_completed     INTEGER NOT NULL DEFAULT 0 CHECK(daily_completed >= 0),
    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL,
    PRIMARY KEY(goal_id, local_date),
    CHECK(daily_completed = morning_completed + afternoon_completed + evening_completed)
);
CREATE INDEX IF NOT EXISTS idx_pace_daily_date ON pace_daily_progress(local_date);

-- 不可变进度事实。AUTO 使用 goal_id + source_ref 去重，确保同一解释节点只计一次。
CREATE TABLE IF NOT EXISTS pace_progress_events (
    event_id            TEXT PRIMARY KEY,
    goal_id             TEXT NOT NULL REFERENCES pace_goals(goal_id),
    occurred_at         TEXT NOT NULL,
    local_date          TEXT NOT NULL,
    period              TEXT NOT NULL CHECK(period IN ('MORNING','AFTERNOON','EVENING')),
    delta               INTEGER NOT NULL CHECK(delta > 0),
    progress_source     TEXT NOT NULL CHECK(progress_source IN ('AUTO','MANUAL')),
    detector_type       TEXT,
    source_ref          TEXT,
    payload_json        TEXT,
    created_at          TEXT NOT NULL,
    UNIQUE(goal_id, source_ref)
);
CREATE INDEX IF NOT EXISTS idx_pace_events_goal_time ON pace_progress_events(goal_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_pace_events_date ON pace_progress_events(local_date);

-- 目标配置/状态变化的审计事实；不改写过去的每日进度。
CREATE TABLE IF NOT EXISTS pace_goal_events (
    event_id            TEXT PRIMARY KEY,
    goal_id             TEXT NOT NULL REFERENCES pace_goals(goal_id),
    occurred_at         TEXT NOT NULL,
    event_type          TEXT NOT NULL CHECK(event_type IN
                          ('PACE_GOAL_CREATED','PACE_GOAL_UPDATED','PACE_GOAL_PAUSED',
                           'PACE_GOAL_RESUMED','PACE_GOAL_COMPLETED')),
    payload_json        TEXT
);
CREATE INDEX IF NOT EXISTS idx_pace_goal_events_goal_time ON pace_goal_events(goal_id, occurred_at);

-- 一天每个时段最多一条聚合推送；避免重启守护进程后重复通知。
CREATE TABLE IF NOT EXISTS pace_notification_runs (
    local_date          TEXT NOT NULL,
    slot                TEXT NOT NULL CHECK(slot IN ('MORNING','AFTERNOON','EVENING','NIGHT')),
    status              TEXT NOT NULL CHECK(status IN ('PENDING','SENT','FAILED')),
    title               TEXT NOT NULL,
    body_markdown       TEXT NOT NULL,
    created_at          TEXT NOT NULL,
    sent_at             TEXT,
    error_text          TEXT,
    PRIMARY KEY(local_date, slot)
);
