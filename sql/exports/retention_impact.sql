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
