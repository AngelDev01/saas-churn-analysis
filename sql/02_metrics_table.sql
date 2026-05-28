-- Daily event counts for each event_type
SELECT
  event_timestamp::date as event_date,
  event_type,
  COUNT(*) as n_event
FROM churn_analysis.events
WHERE event_timestamp BETWEEN '2024-01-01' AND '2024-04-01'
GROUP BY 1, 2
ORDER BY 1, 2;


CREATE TABLE "churn_analysis"."metric" (
    account_id INTEGER NOT NULL,
    metric_name VARCHAR(100) NOT NULL,       -- Stores the name directly
    metric_time TIMESTAMP NOT NULL,          -- Timestamp of the measurement
    metric_value FLOAT,                      -- The numeric value of the metric
    user_id INTEGER,                         -- Optional: for multi-user accounts
    
    -- Composite primary key ensures one measurement per account/metric/time
    PRIMARY KEY (account_id, metric_name, metric_time)
);


-- `login_count_28d` -> Baseline engagement
WITH date_vals AS (
  SELECT i::timestamp AS metric_date
  FROM generate_series('2024-02-01', '2024-04-01', '7 day'::interval) i
)
INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  account_id,
  'login_count_28d' AS metric_name,
  metric_date AS metric_time,
  COUNT(*) AS metric_value
FROM churn_analysis.events e
JOIN date_vals d ON e.event_timestamp < d.metric_date 
                AND e.event_timestamp >= d.metric_date - interval '28 day'
WHERE event_type = 'login'
GROUP BY account_id, metric_date;

---
-- `feature_report_run_28d` -> Core feature usage
WITH date_vals AS (
  SELECT i::timestamp AS metric_date
  FROM generate_series('2024-02-01', '2024-04-01', '7 day'::interval) i
)
INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  account_id,
  'feature_report_run_28d' AS metric_name,
  metric_date AS metric_time,
  COUNT(*) AS metric_value
FROM churn_analysis.events e
JOIN date_vals d ON e.event_timestamp < d.metric_date 
                AND e.event_timestamp >= d.metric_date - interval '28 day'
WHERE event_type = 'feature_report_run'
GROUP BY account_id, metric_date;

---
-- `feature_export_28d` -> Power user signal
WITH date_vals AS (
  SELECT i::timestamp AS metric_date
  FROM generate_series('2024-02-01', '2024-04-01', '7 day'::interval) i
)
INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  account_id,
  'feature_export_28d' AS metric_name,
  metric_date AS metric_time,
  COUNT(*) AS metric_value
FROM churn_analysis.events e
JOIN date_vals d ON e.event_timestamp < d.metric_date 
                AND e.event_timestamp >= d.metric_date - interval '28 day'
WHERE event_type = 'feature_export'
GROUP BY account_id, metric_date;

---
-- `feature_team_invite_28d` -> Viral/growth signal
WITH date_vals AS (
  SELECT i::timestamp AS metric_date
  FROM generate_series('2024-02-01', '2024-04-01', '7 day'::interval) i
)
INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  account_id,
  'feature_team_invite_28d' AS metric_name,
  metric_date AS metric_time,
  COUNT(*) AS metric_value
FROM churn_analysis.events e
JOIN date_vals d ON e.event_timestamp < d.metric_date 
                AND e.event_timestamp >= d.metric_date - interval '28 day'
WHERE event_type = 'feature_team_invite'
GROUP BY account_id, metric_date;

---
-- `support_ticket_count_28d` -> Friction indicator
WITH date_vals AS (
  SELECT i::timestamp AS metric_date
  FROM generate_series('2024-02-01', '2024-04-01', '7 day'::interval) i
)
INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  account_id,
  'support_ticket_count_28d' AS metric_name,
  metric_date AS metric_time,
  COUNT(*) AS metric_value
FROM churn_analysis.events e
JOIN date_vals d ON e.event_timestamp < d.metric_date 
                AND e.event_timestamp >= d.metric_date - interval '28 day'
WHERE event_type = 'support_ticket'
GROUP BY account_id, metric_date;

---
-- `avg_session_duration_28d` -> Engagement depth
WITH date_vals AS (
  SELECT i::timestamp AS metric_date
  FROM generate_series('2024-02-01', '2024-04-01', '7 day'::interval) i
)
INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  e.account_id,
  'avg_session_duration_28d' AS metric_name,
  d.metric_date AS metric_time,
  AVG(e.session_duration_sec)::FLOAT AS metric_value
FROM churn_analysis.events e
INNER JOIN date_vals d 
  ON e.event_timestamp < d.metric_date 
 AND e.event_timestamp >= d.metric_date - INTERVAL '28 day'
WHERE e.session_duration_sec IS NOT NULL
GROUP BY e.account_id, d.metric_date;
