-- Pick Observation Dates
WITH RECURSIVE observation_params AS (
    SELECT INTERVAL '1 month' AS obs_interval,
           INTERVAL '7 days' AS lead_time,
           '2024-02-01'::date AS obs_start,
           '2024-04-01'::date AS obs_end
),
observations AS (
    -- ANCHOR: First observation for each active period
    SELECT account_id,
           start_date,
           1 AS obs_count, --increments with recursion
           (start_date + obs_interval - lead_time)::date AS obs_date,
           CASE 
               WHEN churn_date >= (start_date + obs_interval - lead_time)::date
                AND churn_date < (start_date + 2 * obs_interval - lead_time)::date
               THEN TRUE ELSE FALSE 
           END AS is_churn
    FROM churn_analysis.active_period
    JOIN observation_params p
      ON (churn_date > (p.obs_start + obs_interval - lead_time)::date 
          OR churn_date IS NULL)

    UNION

    -- RECURSION: Subsequent observations
    SELECT o.account_id,
           o.start_date,
           o.obs_count + 1,
           (o.start_date + (o.obs_count + 1) * obs_interval - lead_time)::date,
           CASE 
               WHEN ap.churn_date >= (o.start_date + (o.obs_count + 1) * obs_interval - lead_time)::date
                AND ap.churn_date < (o.start_date + (o.obs_count + 2) * obs_interval - lead_time)::date
               THEN TRUE ELSE FALSE 
           END
    FROM observations o
    JOIN observation_params p
      ON (o.start_date + (o.obs_count + 1) * obs_interval - lead_time)::date <= p.obs_end
    JOIN churn_analysis.active_period ap
      ON ap.account_id = o.account_id
     AND (o.start_date + (o.obs_count + 1) * obs_interval - lead_time)::date >= ap.start_date
     AND ((o.start_date + (o.obs_count + 1) * obs_interval - lead_time)::date < ap.churn_date 
          OR ap.churn_date IS NULL)
)
INSERT INTO churn_analysis.observation_dates (account_id, observation_date, is_churn)
SELECT DISTINCT account_id, obs_date, is_churn
FROM observations
JOIN observation_params p
  ON obs_date BETWEEN p.obs_start AND p.obs_end;
