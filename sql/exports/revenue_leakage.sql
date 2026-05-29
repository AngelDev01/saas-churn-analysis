-- Revenue leakage
SELECT
    status,
    COUNT(*)                        AS n_invoices,
    ROUND(SUM(gross_amount), 2)     AS gross_amount,
    ROUND(SUM(net_revenue), 2)      AS net_revenue
FROM churn_analysis.invoices
GROUP BY status
ORDER BY gross_amount DESC;
