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
