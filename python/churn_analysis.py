import os
import pickle
import warnings

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from collections import Counter
from scipy.cluster.hierarchy import fcluster, linkage
from scipy.spatial.distance import squareform
from scipy.special import expit
from sklearn.linear_model import LogisticRegression
from sqlalchemy import create_engine

warnings.filterwarnings("ignore")
pd.set_option("display.max_columns", None)

# Output directories — create once at startup
for d in ["plots/cohort", "plots/correlation", "outputs/correlation",
          "outputs/predictions", "models"]:
    os.makedirs(d, exist_ok=True)


# =============================================================================
# DATA LOADING
# =============================================================================

DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL)

df_original = pd.read_sql("SELECT * FROM churn_analysis.churn_dataset", engine)
df_original = df_original.set_index(["account_id", "observation_date"])
df_original["is_churn"] = df_original["is_churn"].astype(float)

METRIC_COLS = [c for c in df_original.columns if c != "is_churn"]


# =============================================================================
# DATA PREPARATION
# =============================================================================

def remove_invalid(df, min_valid=None, max_valid=None):
    """Drop observations that fall outside acceptable metric bounds."""
    clean = df.copy()
    if min_valid:
        for metric, threshold in min_valid.items():
            if metric in clean.columns:
                clean = clean[clean[metric] > threshold]
    if max_valid:
        for metric, threshold in max_valid.items():
            if metric in clean.columns:
                clean = clean[clean[metric] < threshold]
    return clean


def cohort_plot(df, metric, ncohort=10, save_path=None):
    """Plot churn rate across equally-sized quantile cohorts of a single metric."""
    groups = pd.qcut(df[metric], ncohort, duplicates="drop")
    plot_frame = pd.DataFrame({
        metric:       df.groupby(groups)[metric].mean().values,
        "churn_rate": df.groupby(groups)["is_churn"].mean().values,
    })
    plt.figure(figsize=(6, 4))
    plt.plot(metric, "churn_rate", data=plot_frame, marker="o", linewidth=2)
    plt.xlabel(f'Cohort average — "{metric}"')
    plt.ylabel("Cohort churn rate")
    plt.grid()
    plt.gca().set_ylim(bottom=0)
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches="tight")
    plt.close()
    plt.clf()


def dataset_stats(df, metric_cols):
    """
    Descriptive statistics for all metrics.
    Adds skew, 1st/99th percentiles, and non-zero rate (%) to the standard describe() output.
    """
    summary = df[metric_cols + ["is_churn"]].describe().T
    summary["skew"]    = df[metric_cols].skew()
    summary["1%"]      = df[metric_cols].quantile(0.01)
    summary["99%"]     = df[metric_cols].quantile(0.99)
    summary["nonzero"] = df[metric_cols].astype(bool).sum() / len(df) * 100
    summary = summary[["count", "nonzero", "mean", "std", "skew",
                        "min", "1%", "25%", "50%", "75%", "99%", "max"]]
    summary.columns = summary.columns.str.replace("%", "pct")
    return summary.round(3)


def metric_scores(df, metric_cols, stats_df, skew_thresh=4.0):
    """
    Transform and standardise metrics before modelling.

    Transform rules (applied before z-scoring):
      - log1p(x)   → skewed metrics with min >= 0  (e.g. login counts)
      - arcsinh(x) → skewed metrics with min <  0  (e.g. pct-change metrics)

    All metrics are then standardised to z-scores using their own mean and std.
    Returns the scored DataFrame plus lists of which columns received each transform.
    """
    df_scored = df.copy()

    skewed_mask = (stats_df["skew"] > skew_thresh) & (stats_df["min"] >= 0)
    skewed_cols = skewed_mask[skewed_mask].index.intersection(metric_cols)
    for col in skewed_cols:
        df_scored[col] = np.log1p(df_scored[col])

    fattail_mask = (stats_df["skew"] > skew_thresh) & (stats_df["min"] < 0)
    fattail_cols = fattail_mask[fattail_mask].index.intersection(metric_cols)
    for col in fattail_cols:
        df_scored[col] = np.arcsinh(df_scored[col])

    for col in metric_cols:
        mean_val = df_scored[col].mean()
        std_val  = df_scored[col].std()
        if std_val > 0:
            df_scored[col] = (df_scored[col] - mean_val) / std_val

    return df_scored, skewed_cols.tolist(), fattail_cols.tolist()


# =============================================================================
# CORRELATION & METRIC GROUPING
# =============================================================================

def calculate_correlation_matrix(df, metric_cols, save_path=None):
    """Compute and optionally save the Pearson correlation matrix for scored metrics."""
    corr_df = df[metric_cols].corr()
    if save_path:
        corr_df.to_csv(save_path)
    return corr_df


def find_correlation_clusters(corr_matrix, corr_thresh=0.5):
    """
    Assign each metric to a cluster via single-linkage hierarchical clustering.
    Metrics with correlation >= corr_thresh are placed in the same group.
    """
    dissimilarity = 1.0 - corr_matrix.values
    np.fill_diagonal(dissimilarity, 0)
    hierarchy = linkage(squareform(dissimilarity), method="single")
    return fcluster(hierarchy, 1.0 - corr_thresh, criterion="distance")


def relabel_clusters(labels, metric_columns):
    """Re-number cluster labels by descending group size (largest group = 0)."""
    cluster_count = Counter(labels)
    rank_map = {cluster: rank for rank, (cluster, _) in enumerate(cluster_count.most_common())}
    relabeled = [rank_map[l] for l in labels]
    labeled_df = pd.DataFrame({"group": relabeled, "column": metric_columns}).sort_values(
        ["group", "column"]
    )
    return labeled_df, Counter(relabeled)


def make_load_matrix(labeled_column_df, metric_columns, relabeled_count, corr_thresh):
    """
    Build the loading matrix that maps individual metrics to group scores.

    Weight formula (Eq 6.3 in the book):
      - Grouped metric:  1 / (sqrt(corr_thresh) × group_size)
      - Singleton:       1.0

    Metrics are sorted so the largest groups appear first; within a group,
    metrics are sorted alphabetically.
    """
    load_mat = np.zeros((len(metric_columns), len(relabeled_count)))
    for _, row in labeled_column_df.iterrows():
        col_idx   = metric_columns.index(row["column"])
        group_idx = row["group"]
        n         = relabeled_count[group_idx]
        load_mat[col_idx, group_idx] = (
            1.0 if n == 1 else 1.0 / (np.sqrt(corr_thresh) * n)
        )

    is_group  = load_mat.astype(bool).sum(axis=0) > 1
    col_names = [
        f"metric_group_{d + 1}" if is_group[d]
        else labeled_column_df.loc[labeled_column_df["group"] == d, "column"].iloc[0]
        for d in range(load_mat.shape[1])
    ]

    loadmat_df = pd.DataFrame(load_mat, index=metric_columns, columns=col_names)
    loadmat_df["_name"] = loadmat_df.index
    group_cols = [c for c in loadmat_df.columns if c != "_name"]
    loadmat_df = loadmat_df.sort_values(
        group_cols + ["_name"],
        ascending=[False] * len(group_cols) + [True],
    ).drop("_name", axis=1)

    return loadmat_df


def find_metric_groups(df_scored, metric_cols, group_corr_thresh=0.5, save_path=None):
    """
    Orchestrate metric clustering and return the loading matrix.
    Recommended threshold range: 0.4 (fewer, larger groups) to 0.7 (more, smaller groups).
    """
    corr_matrix = df_scored[metric_cols].corr()
    labels = find_correlation_clusters(corr_matrix, group_corr_thresh)
    labeled_df, relabeled_count = relabel_clusters(labels, list(metric_cols))
    loadmat_df = make_load_matrix(labeled_df, list(metric_cols), relabeled_count, group_corr_thresh)
    if save_path:
        loadmat_df.to_csv(save_path)
    return loadmat_df


def apply_metric_groups(df_scored, loadmat_df, save_path=None):
    """
    Apply the loading matrix to scored metrics to produce group-averaged scores.
    Matrix multiply: (N_obs × N_metrics) @ (N_metrics × N_groups) → (N_obs × N_groups).
    """
    data = df_scored.drop(columns=["is_churn"], errors="ignore")
    grouped = np.matmul(data[loadmat_df.index.values].to_numpy(), loadmat_df.to_numpy())
    df_out = pd.DataFrame(grouped, columns=loadmat_df.columns, index=df_scored.index)
    if "is_churn" in df_scored.columns:
        df_out["is_churn"] = df_scored["is_churn"]
    if save_path:
        df_out.to_csv(save_path)
    return df_out


# =============================================================================
# PIPELINE
# =============================================================================

# Filter to paying customers only
df = remove_invalid(df_original, min_valid={"total_mrr": 0})

# Summary statistics (used later to re-score current customers)
stats = dataset_stats(df, METRIC_COLS)

# Score metrics
df_scored, skewed_metrics, fattail_metrics = metric_scores(df, METRIC_COLS, stats)
print(f"log1p  transforms: {skewed_metrics}")
print(f"arcsinh transforms: {fattail_metrics}")

# Cohort plots — raw metrics (confirm expected direction before scoring)
for metric in ["login_count_28d", "avg_session_28d", "report_run_28d", "total_mrr"]:
    cohort_plot(df, metric, save_path=f"plots/cohort/raw_{metric}.png")

# Cohort plots — scored metrics
for metric in ["login_count_28d", "avg_session_28d", "report_run_28d", "total_mrr"]:
    cohort_plot(df_scored, metric, save_path=f"plots/cohort/scored_{metric}.png")

# Correlation matrix
corr_matrix = calculate_correlation_matrix(
    df_scored, METRIC_COLS,
    save_path="outputs/correlation/correlation_matrix.csv",
)

# Correlation heatmap
plt.figure(figsize=(10, 8))
sns.heatmap(corr_matrix, cmap="coolwarm", annot=True, fmt=".2f")
plt.title("Metric Correlation Matrix")
plt.tight_layout()
plt.savefig("plots/correlation/correlation_heatmap.png", dpi=300, bbox_inches="tight")
plt.close()

# Metric groups — threshold 0.5 means r >= 0.5 lands in the same group
loadmat_df = find_metric_groups(
    df_scored, METRIC_COLS,
    group_corr_thresh=0.5,
    save_path="outputs/correlation/loading_matrix.csv",
)

# Ordered correlation matrix — metrics sorted by cluster for visual inspection
ordered_corr = df_scored[loadmat_df.index.values].corr()
ordered_corr.to_csv("outputs/correlation/ordered_correlation_matrix.csv")

# Group scores — replaces raw metrics as model input
df_grouped = apply_metric_groups(
    df_scored, loadmat_df,
    save_path="outputs/grouped_scores.csv",
)

# Cohort plots for group scores (verify groups capture churn signal)
for grp in [c for c in df_grouped.columns if c.startswith("metric_group_")]:
    cohort_plot(df_grouped, grp, save_path=f"plots/cohort/group_{grp}.png")


# =============================================================================
# LOGISTIC REGRESSION MODEL
# =============================================================================

# Plain-English labels for stakeholder-facing charts
LABEL_MAP = {
    "metric_group_1":                    "Core engagement",
    "metric_group_2":                    "Team collaboration",
    "login_count_28d":                   "Logins",
    "report_run_28d":                    "Report runs",
    "feature_export_28d":                "Exports",
    "team_invite_28d":                   "Team invites",
    "support_ticket_28d":                "Support tickets",
    "avg_session_28d":                   "Session duration",
    "account_tenure_days":               "Account tenure",
    "total_mrr":                         "MRR",
    "feature_export_per_login":          "Exports per login",
    "support_ticket_per_login":          "Tickets per login",
    "mrr_per_login":                     "MRR per login",
    "feature_report_run_per_login":      "Reports per login",
    "login_count_28d_pct_change":        "Login trend",
    "feature_report_run_28d_pct_change": "Report trend",
    "days_since_login":                  "Days since login",
    "days_since_feature_export":         "Days since export",
}

y = ~df_grouped["is_churn"].astype(bool)   # True = retained
X = df_grouped.drop(columns=["is_churn"])

model = LogisticRegression(fit_intercept=True, solver="liblinear", penalty="l1")
model.fit(X, y)

# Retention impact: delta in P(retain) when a metric is 1 std-dev above average.
# At average (all scores = 0): P(retain) = sigmoid(intercept).
# At +1 std on metric i:       P(retain) = sigmoid(intercept + coef_i).
baseline_retention = expit(model.intercept_[0])
impacts = expit(model.intercept_[0] + model.coef_[0]) - baseline_retention

summary = pd.DataFrame({
    "metric":        list(X.columns) + ["offset"],
    "weight":        list(model.coef_[0]) + [model.intercept_[0]],
    "retain_impact": list(impacts) + [baseline_retention],
}).sort_values("weight", ascending=False, ignore_index=True)
print(summary.to_string(index=False))

# Calibration check — average predicted churn should be close to observed churn rate
hist_probs = model.predict_proba(X)[:, 0]
print(f"\nDataset churn rate:  {df['is_churn'].mean():.4%}")
print(f"Avg predicted churn: {hist_probs.mean():.4%}")

# Retention impact chart
plot_df = summary[summary["metric"] != "offset"].copy()
plot_df["label"]     = plot_df["metric"].map(LABEL_MAP).fillna(plot_df["metric"])
plot_df["impact_pp"] = plot_df["retain_impact"] * 100
plot_df = plot_df.sort_values("impact_pp")

plt.figure(figsize=(8, len(plot_df) * 0.4))
sns.barplot(
    data=plot_df,
    y="label",
    x="impact_pp",
    hue=np.where(plot_df["impact_pp"] >= 0, "Positive", "Negative"),
    dodge=False,
)
plt.axvline(0, color="black", linewidth=1)
plt.xlabel("Retention impact (percentage points)")
plt.ylabel("")
plt.title("Impact of Customer Behavior on Retention")
plt.tight_layout()
plt.savefig("plots/retention_impact.png", dpi=150, bbox_inches="tight")
plt.close()

with open("models/churn_model.pkl", "wb") as f:
    pickle.dump(model, f)


# =============================================================================
# SCORE CURRENT ACTIVE CUSTOMERS
# =============================================================================

ACTIVE_CUSTOMERS_QUERY = """
WITH metric_date AS (
    SELECT MAX(metric_time) AS last_metric_time FROM churn_analysis.metric
),
active_accounts AS (
    SELECT m.account_id
    FROM churn_analysis.metric m
    JOIN metric_date md ON m.metric_time = md.last_metric_time
    WHERE m.metric_name = 'account_tenure_days' AND m.metric_value >= 14
)
SELECT
    m.account_id, m.metric_time,
    COALESCE(SUM(CASE WHEN m.metric_name = 'login_count_28d'                   THEN m.metric_value END), 0) AS login_count_28d,
    COALESCE(SUM(CASE WHEN m.metric_name = 'feature_report_run_28d'            THEN m.metric_value END), 0) AS report_run_28d,
    COALESCE(SUM(CASE WHEN m.metric_name = 'feature_export_28d'                THEN m.metric_value END), 0) AS feature_export_28d,
    COALESCE(SUM(CASE WHEN m.metric_name = 'feature_team_invite_28d'           THEN m.metric_value END), 0) AS team_invite_28d,
    COALESCE(SUM(CASE WHEN m.metric_name = 'support_ticket_count_28d'          THEN m.metric_value END), 0) AS support_ticket_28d,
    COALESCE(SUM(CASE WHEN m.metric_name = 'avg_session_duration_28d'          THEN m.metric_value END), 0) AS avg_session_28d,
    COALESCE(SUM(CASE WHEN m.metric_name = 'account_tenure_days'               THEN m.metric_value END), 0) AS account_tenure_days,
    COALESCE(SUM(CASE WHEN m.metric_name = 'total_mrr'                         THEN m.metric_value END), 0) AS total_mrr,
    COALESCE(SUM(CASE WHEN m.metric_name = 'feature_export_per_login'          THEN m.metric_value END), 0) AS feature_export_per_login,
    COALESCE(SUM(CASE WHEN m.metric_name = 'support_ticket_per_login'          THEN m.metric_value END), 0) AS support_ticket_per_login,
    COALESCE(SUM(CASE WHEN m.metric_name = 'mrr_per_login'                     THEN m.metric_value END), 0) AS mrr_per_login,
    COALESCE(SUM(CASE WHEN m.metric_name = 'feature_report_run_per_login'      THEN m.metric_value END), 0) AS feature_report_run_per_login,
    COALESCE(SUM(CASE WHEN m.metric_name = 'login_count_28d_pct_change'        THEN m.metric_value END), 0) AS login_count_28d_pct_change,
    COALESCE(SUM(CASE WHEN m.metric_name = 'feature_report_run_28d_pct_change' THEN m.metric_value END), 0) AS feature_report_run_28d_pct_change,
    COALESCE(SUM(CASE WHEN m.metric_name = 'days_since_login'                  THEN m.metric_value END), 0) AS days_since_login,
    COALESCE(SUM(CASE WHEN m.metric_name = 'days_since_feature_export'         THEN m.metric_value END), 0) AS days_since_feature_export
FROM churn_analysis.metric m
JOIN metric_date md ON m.metric_time = md.last_metric_time
JOIN active_accounts aa ON m.account_id = aa.account_id
WHERE EXISTS (
    SELECT 1 FROM churn_analysis.subscriptions s
    WHERE s.account_id = m.account_id
      AND s.start_date <= md.last_metric_time
      AND (s.end_date >= md.last_metric_time OR s.end_date IS NULL)
)
GROUP BY m.account_id, m.metric_time
ORDER BY m.account_id;
"""

df_current_raw = pd.read_sql(ACTIVE_CUSTOMERS_QUERY, engine)

# Re-apply the same transforms used during training.
# Critical: use historical stats — do NOT refit on current data, as that would
# shift the z-score baseline and invalidate model coefficients.
current = df_current_raw.copy()
for col in skewed_metrics:
    if col in current.columns:
        current[col] = np.log1p(current[col])
for col in fattail_metrics:
    if col in current.columns:
        current[col] = np.arcsinh(current[col])

metric_cols_no_churn = [c for c in stats.index if c != "is_churn"]
current = current[metric_cols_no_churn]
scaled = (current - stats.loc[metric_cols_no_churn, "mean"]) / stats.loc[metric_cols_no_churn, "std"]

# Drift check — ratios well above 1.5 or below 0.5 indicate the model needs retraining
comparison = pd.DataFrame({
    "historical_mean": stats.loc[metric_cols_no_churn, "mean"],
    "current_mean":    df_current_raw[metric_cols_no_churn].mean(),
    "ratio":           (df_current_raw[metric_cols_no_churn].mean()
                        / stats.loc[metric_cols_no_churn, "mean"]).round(2),
})
print(comparison)

grouped_arr = (scaled[loadmat_df.index] @ loadmat_df.to_numpy())
df_current_grouped = grouped_arr.copy()


# =============================================================================
# FORECAST & CUSTOMER LIFETIME VALUE
# =============================================================================

probs = model.predict_proba(df_current_grouped)
forecast_df = pd.DataFrame(
    probs,
    columns=["churn_prob", "retain_prob"],
    index=df_current_grouped.index,
).sort_values("churn_prob", ascending=False)

forecast_df["account_id"] = df_current_raw["account_id"].values
forecast_df = forecast_df.sort_values("churn_prob", ascending=False)
forecast_df.to_csv("outputs/predictions/churn_forecast.csv", index=False)

print(f"Average forecast churn:  {forecast_df['churn_prob'].mean():.4%}")
print(f"Accounts at > 20% risk:  {(forecast_df['churn_prob'] > 0.20).sum()}")
print(f"Accounts at > 50% risk:  {(forecast_df['churn_prob'] > 0.50).sum()}")
print("\nTop 10 highest-risk accounts:")
print(forecast_df.head(10).to_string())

# Churn probability distribution
fig, ax = plt.subplots(figsize=(7, 4))
ax.hist(forecast_df["churn_prob"], bins=20, color="steelblue", edgecolor="white")
ax.set_xlabel("Churn probability")
ax.set_ylabel("# of accounts")
ax.set_title("Active Customer Churn Probability Distribution")
ax.grid(alpha=0.3)
plt.tight_layout()
plt.savefig("plots/churn_probability_distribution.png", dpi=150, bbox_inches="tight")
plt.close()

# Future Lifetime Value
# FLV  = margin × MRR × (expected_lifetime - 1)
# VaR  = FLV × churn_prob  (expected revenue at risk this period)
# expected_lifetime = 1 / churn_prob  (in billing periods)
MARGIN = 0.70
mrr        = df_current_raw["total_mrr"].reindex(forecast_df.index)
churn_prob = forecast_df["churn_prob"].clip(lower=0.001)   # guard against division by zero

clv_df = pd.DataFrame({
    "mrr":               mrr,
    "churn_prob":        churn_prob,
    "expected_lifetime": (1 / churn_prob).round(1),
    "flv":               (MARGIN * mrr * (1 / churn_prob - 1)).round(2),
    "value_at_risk":     (MARGIN * mrr * (1 / churn_prob - 1) * churn_prob).round(2),
}).sort_values("value_at_risk", ascending=False)

clv_df["account_id"] = df_current_raw["account_id"].reindex(clv_df.index).values
clv_df.to_csv("outputs/predictions/clv_forecast.csv", index=False)

print(f"\nTotal portfolio FLV:  ${clv_df['flv'].sum():>12,.0f}")
print(f"Median account FLV:   ${clv_df['flv'].median():>12,.0f}")
print("\nTop accounts by value at risk (intervene here first):")
print(clv_df.head(10).to_string())
