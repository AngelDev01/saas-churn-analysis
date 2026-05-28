-- Flatten Metrics → Churn Dataset
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
    
    COALESCE(SUM(CASE WHEN m.metric_name = 'login_count_28d' THEN m.metric_value END), 0) AS login_count_28d,
    COALESCE(SUM(CASE WHEN m.metric_name = 'feature_report_run_28d' THEN m.metric_value END), 0) AS report_run_28d,
    COALESCE(SUM(CASE WHEN m.metric_name = 'feature_export_28d' THEN m.metric_value END), 0) AS feature_export_28d,
    COALESCE(SUM(CASE WHEN m.metric_name = 'feature_team_invite_28d' THEN m.metric_value END), 0) AS team_invite_28d,
    COALESCE(SUM(CASE WHEN m.metric_name = 'support_ticket_count_28d' THEN m.metric_value END), 0) AS support_ticket_28d,
    COALESCE(SUM(CASE WHEN m.metric_name = 'avg_session_duration_28d' THEN m.metric_value END), 0) AS avg_session_28d,
    COALESCE(SUM(CASE WHEN m.metric_name = 'account_tenure_days' THEN m.metric_value END), 0) AS account_tenure_days,
    COALESCE(SUM(CASE WHEN m.metric_name = 'total_mrr' THEN m.metric_value END), 0) AS total_mrr
    
FROM churn_analysis.observation_dates o
JOIN observation_params p
  ON o.observation_date BETWEEN p.obs_start AND p.obs_end
LEFT JOIN churn_analysis.metric m
  ON o.account_id = m.account_id
  AND m.metric_time > (o.observation_date - p.metric_period)::timestamp
  AND m.metric_time <= o.observation_date::timestamp
GROUP BY o.account_id, o.observation_date, o.is_churn;


-- Current Customers for Segmentation
WITH metric_date AS (
    SELECT MAX(metric_time) AS last_metric_time
    FROM churn_analysis.metric
)
SELECT m.account_id,
       m.metric_time,
       COALESCE(SUM(CASE WHEN m.metric_name = 'login_count_28d' THEN m.metric_value END), 0) AS login_count_28d,
       COALESCE(SUM(CASE WHEN m.metric_name = 'feature_report_run_28d' THEN m.metric_value END), 0) AS report_run_28d,
       COALESCE(SUM(CASE WHEN m.metric_name = 'feature_export_28d' THEN m.metric_value END), 0) AS feature_export_28d,
       COALESCE(SUM(CASE WHEN m.metric_name = 'feature_team_invite_28d' THEN m.metric_value END), 0) AS team_invite_28d,
       COALESCE(SUM(CASE WHEN m.metric_name = 'support_ticket_count_28d' THEN m.metric_value END), 0) AS support_ticket_28d,
       COALESCE(SUM(CASE WHEN m.metric_name = 'avg_session_duration_28d' THEN m.metric_value END), 0) AS avg_session_28d,
       COALESCE(SUM(CASE WHEN m.metric_name = 'account_tenure_days' THEN m.metric_value END), 0) AS account_tenure_days,
       COALESCE(SUM(CASE WHEN m.metric_name = 'total_mrr' THEN m.metric_value END), 0) AS total_mrr
FROM churn_analysis.metric m
JOIN metric_date md ON m.metric_time = md.last_metric_time
JOIN churn_analysis.subscriptions s
  ON m.account_id = s.account_id
  AND s.start_date <= md.last_metric_time
  AND (s.end_date >= md.last_metric_time OR s.end_date IS NULL)
GROUP BY m.account_id, m.metric_time
ORDER BY m.account_id
