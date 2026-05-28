-- Net retention sql
WITH date_range AS (
  SELECT
    '2024-03-01'::date AS start_date, '2024-04-01'::date AS end_date
),

start_accounts AS (
  SELECT
    account_id,
    SUM(mrr) AS total_mrr
  FROM churn_analysis.subscriptions s
  JOIN date_range d
  ON s.start_date <= d.start_date AND
  (s.end_date > d.start_date OR s.end_date IS NULL)
  GROUP BY account_id
),

end_accounts AS (
  SELECT
    account_id,
    SUM(mrr) AS total_mrr
  FROM churn_analysis.subscriptions s
  JOIN date_range d
  ON s.start_date <= d.end_date AND
  (s.end_date > d.end_date OR s.end_date IS NULL)
  GROUP BY account_id
),

retained_accounts AS (
  SELECT
    s.account_id,
    SUM(e.total_mrr) AS total_mrr
  FROM start_accounts s
  JOIN end_accounts e
  USING(account_id)
  GROUP BY s.account_id
),

start_mrr AS (
  SELECT
    SUM(total_mrr) as start_mrr
  FROM start_accounts
),

retain_mrr AS (
  SELECT
    SUM(total_mrr) as retain_mrr
  FROM retained_accounts
)

SELECT
  retain_mrr /start_mrr  AS net_mrr_retention_rate,
  1.0 - retain_mrr /start_mrr AS net_mrr_churn_rate,
  start_mrr,    
  retain_mrr
FROM start_mrr, retain_mrr;



-- Standard (account-based) churn SQL
WITH date_range AS (
  SELECT
    '2024-03-01'::date AS start_date, '2024-04-01'::date AS end_date
),

start_accounts AS (
  SELECT
    DISTINCT account_id
  FROM churn_analysis.subscriptions s
  JOIN date_range d
  ON s.start_date <= d.start_date AND
  (s.end_date > d.start_date OR s.end_date IS NULL)
),

end_accounts AS (
  SELECT
    DISTINCT account_id
  FROM churn_analysis.subscriptions s
  JOIN date_range d
  ON s.start_date <= d.end_date AND
  (s.end_date > d.end_date OR s.end_date IS NULL)
),

churned_accounts AS (
  SELECT
    s.account_id
  FROM start_accounts s
  LEFT JOIN end_accounts e
  USING(account_id)
  WHERE e.account_id IS NULL
),

start_count AS (     
  SELECT
    COUNT(*) AS n_start
  FROM start_accounts
),

churn_count AS (             
  SELECT
    COUNT(*) AS n_churn
  FROM churned_accounts
)

SELECT
  n_churn::float/n_start::float AS churn_rate,
  1.0-n_churn::float/n_start::float AS retention_rate,
  n_start,          
  n_churn           
FROM start_count, churn_count;


-- MRR churn SQL
WITH date_range AS (
  SELECT
    '2024-03-01'::date AS start_date, '2024-04-01'::date AS end_date
),

start_accounts AS (
  SELECT
    account_id,
    SUM(mrr) as total_mrr
  FROM churn_analysis.subscriptions s
  JOIN date_range d
  ON s.start_date <= d.start_date AND
  (s.end_date > d.start_date OR s.end_date IS NULL)
  GROUP BY account_id
),

end_accounts AS (
  SELECT
    account_id,
    SUM(mrr) as total_mrr
  FROM churn_analysis.subscriptions s
  JOIN date_range d
  ON s.start_date <= d.end_date AND
  (s.end_date > d.end_date OR s.end_date IS NULL)
  GROUP BY account_id
),

churned_accounts AS (
  SELECT
    s.account_id,
    SUM(s.total_mrr) as total_mrr
  FROM start_accounts s
  LEFT JOIN end_accounts e
  USING(account_id)
  WHERE e.account_id IS NULL
  GROUP BY account_id
),

downsell_accounts AS (
  SELECT
    s.account_id,
    s.total_mrr-e.total_mrr AS downsell_amount
  FROM start_accounts s
  JOIN end_accounts e
  USING(account_id)
  WHERE e.total_mrr < s.total_mrr
),

start_mrr AS (     
  SELECT
    SUM(total_mrr) as start_mrr
  FROM start_accounts
),

churn_mrr AS (     
  SELECT
    SUM(total_mrr) as churn_mrr
  FROM churned_accounts
),

downsell_mrr AS (       
  SELECT
    coalesce(SUM(downsell_accounts.downsell_amount),0.0)  AS downsell_mrr      
  FROM downsell_accounts
)

SELECT
  (churn_mrr+downsell_mrr) /start_mrr AS mrr_churn_rate,
 start_mrr,            
 churn_mrr, 
 downsell_mrr
FROM start_mrr, churn_mrr, downsell_mrr;



