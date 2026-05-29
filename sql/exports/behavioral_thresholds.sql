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

