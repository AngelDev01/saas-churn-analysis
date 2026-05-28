-- Active Periods Currently Ongoing
WITH RECURSIVE active_period_params AS (
  SELECT INTERVAL '14 days' AS allowed_gap,
  '2024-04-01'::date AS calc_date
),

active AS (
  -- ANCHOR: Find currently active subscriptions
  SELECT DISTINCT account_id, MIN(start_date) AS start_date
  FROM churn_analysis.subscriptions
  JOIN active_period_params p
  ON start_date <= p.calc_date
  AND (end_date > p.calc_date OR end_date IS NULL)
  GROUP BY account_id
  UNION
  
  -- RECURSION: Walk backward to find earlier contiguous subscriptions
  SELECT s.account_id, s.start_date
  FROM churn_analysis.subscriptions s
  CROSS JOIN active_period_params p
  JOIN active a
  ON s.account_id = a.account_id
  AND s.start_date < a.start_date
  AND s.end_date >= (a.start_date - p.allowed_gap)::date
)
INSERT INTO churn_analysis.active_period (account_id, start_date, churn_date)
SELECT account_id, MIN(start_date), NULL::date
FROM active
GROUP BY account_id;


-- Active Periods Ending in Churn
WITH RECURSIVE active_period_params AS (
    SELECT INTERVAL '14 days' AS allowed_gap,
           '2024-04-01'::date AS observe_end,
           '2023-01-01'::date AS observe_start
),
end_dates AS (
    -- All subscription end dates within analysis window
    SELECT DISTINCT account_id, start_date, end_date,
           (end_date + allowed_gap)::date AS extension_max
    FROM churn_analysis.subscriptions
    JOIN active_period_params p
      ON end_date BETWEEN p.observe_start AND p.observe_end
),
extensions AS (
    -- Subscriptions that extend an end date
    SELECT DISTINCT e.account_id, e.end_date
    FROM end_dates e
    JOIN churn_analysis.subscriptions s
      ON e.account_id = s.account_id
     AND s.start_date <= e.extension_max
     AND (s.end_date > e.end_date OR s.end_date IS NULL) -- an user can have add-ons
),
churns AS (
    -- ANCHOR: End dates with NO extension = true churns
    SELECT e.account_id, e.start_date, e.end_date AS churn_date
    FROM end_dates e
    LEFT JOIN extensions x
      ON e.account_id = x.account_id AND e.end_date = x.end_date
    WHERE x.end_date IS NULL

    UNION

    -- RECURSION: Find earlier contiguous start dates
    SELECT s.account_id, s.start_date, c.churn_date
    FROM churn_analysis.subscriptions s
    CROSS JOIN active_period_params p
    JOIN churns c
      ON s.account_id = c.account_id
     AND s.start_date < c.start_date
     AND s.end_date >= (c.start_date - p.allowed_gap)::date
)
INSERT INTO churn_analysis.active_period (account_id, start_date, churn_date)
SELECT account_id, MIN(start_date), churn_date
FROM churns
GROUP BY account_id, churn_date;
