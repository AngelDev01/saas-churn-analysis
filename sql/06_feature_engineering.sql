-- Ratio Metric Calculation.
-- 1) feature_export_per_login
WITH num_metric AS (
  SELECT
    account_id,
    metric_time,
    metric_value AS num_value
  FROM churn_analysis.metric
  WHERE metric_name = 'feature_export_28d'
  AND metric_time BETWEEN '2024-02-01' AND '2024-04-01'
),

den_metric AS (
  SELECT
    account_id,
    metric_time,
    metric_value AS den_value
  FROM churn_analysis.metric
  WHERE metric_name = 'login_count_28d'
  AND metric_time BETWEEN '2024-02-01' AND '2024-04-01'
)

INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  d.account_id,
  'feature_export_per_login' AS metric_name,
  d.metric_time,
  CASE
    WHEN d.den_value > 0 THEN COALESCE(n.num_value, 0.0) / d.den_value
    ELSE 0
  END AS metric_value
FROM den_metric d
LEFT JOIN num_metric n
ON n.account_id = d.account_id
AND n.metric_time = d.metric_time;


-- 2) support_ticket_per_login
WITH num_metric AS (
  SELECT
    account_id,
    metric_time,
    metric_value AS num_value
  FROM churn_analysis.metric
  WHERE metric_name = 'support_ticket_count_28d'
  AND metric_time BETWEEN '2024-02-01' AND '2024-04-01'
),

den_metric AS (
  SELECT
    account_id,
    metric_time,
    metric_value AS den_value
  FROM churn_analysis.metric
  WHERE metric_name = 'login_count_28d'
  AND metric_time BETWEEN '2024-02-01' AND '2024-04-01'
)

INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  d.account_id,
  'support_ticket_per_login' AS metric_name,
  d.metric_time,
  CASE
    WHEN d.den_value > 0 THEN COALESCE(n.num_value, 0.0) / d.den_value
    ELSE 0
  END AS metric_value
FROM den_metric d
LEFT JOIN num_metric n
ON n.account_id = d.account_id
AND n.metric_time = d.metric_time;


-- 3) mrr_per_login
WITH num_metric AS (
  SELECT
    account_id,
    metric_time,
    metric_value AS num_value
  FROM churn_analysis.metric
  WHERE metric_name = 'total_mrr'
  AND metric_time BETWEEN '2024-02-01' AND '2024-04-01'
),

den_metric AS (
  SELECT
    account_id,
    metric_time,
    metric_value AS den_value
  FROM churn_analysis.metric
  WHERE metric_name = 'login_count_28d'
  AND metric_time BETWEEN '2024-02-01' AND '2024-04-01'
)

INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  d.account_id,
  'mrr_per_login' AS metric_name,
  d.metric_time,
  CASE
    WHEN d.den_value > 0 THEN COALESCE(n.num_value, 0.0) / d.den_value
    ELSE 0
  END AS metric_value
FROM den_metric d
LEFT JOIN num_metric n
ON n.account_id = d.account_id
AND n.metric_time = d.metric_time;


-- 4) feature_report_run_per_login
WITH num_metric AS (
  SELECT
    account_id,
    metric_time,
    metric_value AS num_value
  FROM churn_analysis.metric
  WHERE metric_name = 'feature_report_run_28d'
  AND metric_time BETWEEN '2024-02-01' AND '2024-04-01'
),

den_metric AS (
  SELECT
    account_id,
    metric_time,
    metric_value AS den_value
  FROM churn_analysis.metric
  WHERE metric_name = 'login_count_28d'
  AND metric_time BETWEEN '2024-02-01' AND '2024-04-01'
)

INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  d.account_id,
  'feature_report_run_per_login' AS metric_name,
  d.metric_time,
  CASE
    WHEN d.den_value > 0 THEN COALESCE(n.num_value, 0.0) / d.den_value
    ELSE 0
  END AS metric_value
FROM den_metric d
LEFT JOIN num_metric n
ON n.account_id = d.account_id
AND n.metric_time = d.metric_time;


-- Percentage Change in a Metric (rolling percentage change calculation)
-- Percentage change in login_count_28d (rolling 4-week change)
WITH end_metric AS (
  SELECT
    account_id,
    metric_time,
    metric_value AS end_value
  FROM churn_analysis.metric
  WHERE metric_name = 'login_count_28d'
  AND metric_time BETWEEN '2024-02-29' AND '2024-04-01' -- 28 days after first metric date
),

start_metric AS (
  SELECT
    account_id,
    metric_time,
    metric_value AS start_value
  FROM churn_analysis.metric
  WHERE metric_name = 'login_count_28d'
  AND metric_time BETWEEN '2024-02-01' AND '2024-03-04' -- shifted back 28 days
)

INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  s.account_id,
  'login_count_28d_pct_change' AS metric_name,
  s.metric_time + interval '28 days' AS metric_time,
  COALESCE(e.end_value, 0.0) / s.start_value - 1.0 AS metric_value
FROM start_metric s
LEFT JOIN end_metric e
ON s.account_id = e.account_id
AND e.metric_time = s.metric_time + interval '28 days'
WHERE s.start_value > 0;


-- Percentage change in feature_report_run_28d
WITH end_metric AS (
  SELECT
    account_id,
    metric_time,
    metric_value AS end_value
  FROM churn_analysis.metric
  WHERE metric_name = 'feature_report_run_28d'
  AND metric_time BETWEEN '2024-02-29' AND '2024-04-01' -- 28 days after first metric date
),

start_metric AS (
  SELECT
    account_id,
    metric_time,
    metric_value AS start_value
  FROM churn_analysis.metric
  WHERE metric_name = 'feature_report_run_28d'
  AND metric_time BETWEEN '2024-02-01' AND '2024-03-04' -- shifted back 28 days
)

INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  s.account_id,
  'feature_report_run_28d_pct_change' AS metric_name,
  s.metric_time + interval '28 days' AS metric_time,
  COALESCE(e.end_value, 0.0) / s.start_value - 1.0 AS metric_value
FROM start_metric s
LEFT JOIN end_metric e
ON s.account_id = e.account_id
AND e.metric_time = s.metric_time + interval '28 days'
WHERE s.start_value > 0;


-- Time Since Last Event
-- Days since last login
WITH date_vals AS (
  SELECT i::timestamp AS metric_date
  FROM generate_series('2024-02-01', '2024-04-01', '7 day'::interval) i
),

last_event AS (
  SELECT
    e.account_id,
    d.metric_date,
    MAX(e.event_timestamp)::date AS last_date
  FROM churn_analysis.events e
  INNER JOIN date_vals d
  ON e.event_timestamp::date <= d.metric_date::date
  WHERE e.event_type = 'login'
  GROUP BY e.account_id, d.metric_date
)

INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  account_id,
  'days_since_login' AS metric_name,
  metric_date AS metric_time,
  (metric_date::date - last_date)::int AS metric_value
FROM last_event;


-- Days since last feature_export (power-user dormancy signal)
WITH date_vals AS (
  SELECT i::timestamp AS metric_date
  FROM generate_series('2024-02-01', '2024-04-01', '7 day'::interval) i
),

last_event AS (
  SELECT
    e.account_id,
    d.metric_date,
    MAX(e.event_timestamp)::date AS last_date
  FROM churn_analysis.events e
  INNER JOIN date_vals d
  ON e.event_timestamp::date <= d.metric_date::date
  WHERE e.event_type = 'feature_export'
  GROUP BY e.account_id, d.metric_date
)

INSERT INTO churn_analysis.metric (account_id, metric_name, metric_time, metric_value)
SELECT
  account_id,
  'days_since_feature_export' AS metric_name,
  metric_date AS metric_time,
  (metric_date::date - last_date)::int AS metric_value
FROM last_event;



-- Exporting the Dataset with  Metrics
DROP TABLE IF EXISTS churn_analysis.churn_dataset;
CREATE TABLE churn_analysis.churn_dataset AS
WITH observation_params AS (
  SELECT INTERVAL '7 days' AS metric_period,
         '2024-02-01'::timestamp AS obs_start,
         '2024-04-01'::timestamp AS obs_end
)
SELECT
  o.account_id,
  o.observation_date,
  o.is_churn::INT AS is_churn,

  -- Original metrics (unchanged)
  COALESCE(SUM(CASE WHEN m.metric_name = 'login_count_28d' THEN m.metric_value END), 0) AS login_count_28d,
  COALESCE(SUM(CASE WHEN m.metric_name = 'feature_report_run_28d' THEN m.metric_value END), 0) AS report_run_28d,
  COALESCE(SUM(CASE WHEN m.metric_name = 'feature_export_28d' THEN m.metric_value END), 0) AS feature_export_28d,
  COALESCE(SUM(CASE WHEN m.metric_name = 'feature_team_invite_28d' THEN m.metric_value END), 0) AS team_invite_28d,
  COALESCE(SUM(CASE WHEN m.metric_name = 'support_ticket_count_28d' THEN m.metric_value END), 0) AS support_ticket_28d,
  COALESCE(SUM(CASE WHEN m.metric_name = 'avg_session_duration_28d' THEN m.metric_value END), 0) AS avg_session_28d,
  COALESCE(SUM(CASE WHEN m.metric_name = 'account_tenure_days' THEN m.metric_value END), 0) AS account_tenure_days,
  COALESCE(SUM(CASE WHEN m.metric_name = 'total_mrr' THEN m.metric_value END), 0) AS total_mrr,

  -- New Ratio metrics
  COALESCE(SUM(CASE WHEN m.metric_name = 'feature_export_per_login' THEN m.metric_value END), 0) AS feature_export_per_login,
  COALESCE(SUM(CASE WHEN m.metric_name = 'support_ticket_per_login' THEN m.metric_value END), 0) AS support_ticket_per_login,
  COALESCE(SUM(CASE WHEN m.metric_name = 'mrr_per_login' THEN m.metric_value END), 0) AS mrr_per_login,
  COALESCE(SUM(CASE WHEN m.metric_name = 'feature_report_run_per_login' THEN m.metric_value END), 0) AS feature_report_run_per_login,

  -- New Percentage Change metrics
  COALESCE(SUM(CASE WHEN m.metric_name = 'login_count_28d_pct_change' THEN m.metric_value END), 0) AS login_count_28d_pct_change,
  COALESCE(SUM(CASE WHEN m.metric_name = 'feature_report_run_28d_pct_change' THEN m.metric_value END), 0) AS feature_report_run_28d_pct_change,

  -- New Time Since Last Activity metrics
  COALESCE(SUM(CASE WHEN m.metric_name = 'days_since_login' THEN m.metric_value END), 0) AS days_since_login,
  COALESCE(SUM(CASE WHEN m.metric_name = 'days_since_feature_export' THEN m.metric_value END), 0) AS days_since_feature_export

FROM churn_analysis.observation_dates o
JOIN observation_params p
  ON o.observation_date BETWEEN p.obs_start AND p.obs_end
LEFT JOIN churn_analysis.metric m
  ON o.account_id = m.account_id
  AND m.metric_time > (o.observation_date - p.metric_period)::timestamp
  AND m.metric_time <= o.observation_date::timestamp
GROUP BY o.account_id, o.observation_date, o.is_churn;
