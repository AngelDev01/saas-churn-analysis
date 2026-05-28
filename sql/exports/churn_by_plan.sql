--churn by plan
SELECT
    plan,
    billing_period,
    COUNT(*) FILTER (WHERE status = 'cancelled') AS churned,
    COUNT(*) AS total,
    ROUND(COUNT(*) FILTER (WHERE status = 'cancelled')::numeric / COUNT(*), 4) AS churn_rate,
    AVG(mrr) AS avg_mrr
FROM churn_analysis.subscriptions
GROUP BY plan, billing_period
ORDER BY plan, billing_period;

-- Acquisition channel ROI
SELECT
    a.acquisition_channel,
    COUNT(DISTINCT a.account_id)                          AS n_accounts,
    ROUND(AVG(a.cac), 2)                                  AS avg_cac,
    ROUND(AVG(s.mrr), 2)                                  AS avg_mrr,
    COUNT(*) FILTER (WHERE s.status = 'cancelled')::float
        / COUNT(*)                                        AS churn_rate,
    ROUND(AVG(s.mrr) / NULLIF(AVG(a.cac), 0), 4)         AS mrr_to_cac_ratio
FROM churn_analysis.accounts a
JOIN churn_analysis.subscriptions s USING (account_id)
GROUP BY a.acquisition_channel
ORDER BY mrr_to_cac_ratio DESC;


-- Revenue leakage
SELECT
    status,
    COUNT(*)                        AS n_invoices,
    ROUND(SUM(gross_amount), 2)     AS gross_amount,
    ROUND(SUM(net_revenue), 2)      AS net_revenue
FROM churn_analysis.invoices
GROUP BY status
ORDER BY gross_amount DESC;

-- Upgrade vs downgrade flow
SELECT
    status,
    plan,
    COUNT(*)        AS n,
    AVG(mrr)        AS avg_mrr
FROM churn_analysis.subscriptions
WHERE status IN ('upgraded', 'downgraded')
GROUP BY status, plan
ORDER BY status, plan;

-- behavioral_thresholds
SELECT *
FROM (VALUES
    ('0-1',  0.1202, 0.0910, 1),
    ('2',    0.0251, 0.0403, 2),
    ('3',    0.0457, 0.0194, 3),
    ('4-5',  0.0247, 0.0220, 4),
    ('6-7',  0.0327, 0.0387, 5),
    ('8-10', 0.0366, 0.0381, 6),
    ('10+',  0.0268, 0.0237, 7)
) AS t(bucket_label, login_churn_rate, report_churn_rate, sort_order);
-- Values come from the insight script output — `CHURN BY LOGIN BUCKET` and `CHURN BY REPORT RUNS BUCKET` tables. The bucket labels are manually simplified from the pandas interval notation (`(-0.001, 1.0]` → `0-1`) for readability in the visual.


-- retention_impact
SELECT *
FROM (VALUES
    ('Login trend',        0.832943,  1.46, 'positive'),
    ('Session duration',   0.685396,  1.28, 'positive'),
    ('Report trend',       0.461689,  0.95, 'positive'),
    ('Tickets per login',  0.392308,  0.83, 'positive'),
    ('Exports per login',  0.378912,  0.81, 'positive'),
    ('Days since export',  0.296600,  0.66, 'positive'),
    ('Days since login',   0.209392,  0.48, 'positive'),
    ('Core engagement',    0.015321,  0.04, 'positive'),
    ('MRR per login',      0.013410,  0.03, 'positive'),
    ('Account tenure',    -0.191817, -0.54, 'negative'),
    ('Reports per login', -0.194472, -0.54, 'negative')
) AS t(metric_label, weight, impact_pp, direction)
ORDER BY impact_pp DESC;
-- Values come directly from the Python console output — the `RETENTION IMPACT PER METRIC` table printed by the insight script. `weight` is the raw model coefficient, `impact_pp` is the percentage point retention impact. it's only strictly needed `metric_label`, `impact_pp`, and `direction` for the visual, but keeping `weight` makes the file useful as a reference document.
