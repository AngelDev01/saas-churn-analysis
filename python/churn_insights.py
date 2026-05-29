
# =============================================================================
# INSIGHT EXTRACTION
# =============================================================================

# -----------------------------------------------------------------------------
# 1. RISK TIER SEGMENTATION
# -----------------------------------------------------------------------------

forecast_df["risk_tier"] = pd.cut(
    forecast_df["churn_prob"],
    bins=[0, 0.10, 0.25, 1.0],
    labels=["low", "medium", "high"]
)

current_features = df_current_raw.set_index("account_id")[[
    "total_mrr", "login_count_28d", "days_since_login",
    "report_run_28d", "support_ticket_28d", "account_tenure_days"
]]

segments = forecast_df.join(current_features)

seg_summary = segments.groupby("risk_tier").agg(
    n_accounts        = ("churn_prob",            "count"),
    avg_churn_prob    = ("churn_prob",             "mean"),
    total_mrr         = ("total_mrr",              "sum"),
    avg_mrr           = ("total_mrr",              "mean"),
    avg_logins        = ("login_count_28d",         "mean"),
    avg_days_inactive = ("days_since_login",        "mean"),
    avg_reports       = ("report_run_28d",          "mean"),
    avg_tickets       = ("support_ticket_28d",      "mean"),
    avg_tenure_days   = ("account_tenure_days",     "mean"),
)
seg_summary["pct_of_accounts"] = seg_summary["n_accounts"] / seg_summary["n_accounts"].sum() * 100
seg_summary["pct_of_mrr"]      = seg_summary["total_mrr"]  / seg_summary["total_mrr"].sum()  * 100

print("=== RISK TIER BREAKDOWN ===")
print(seg_summary.round(2).to_string())


# -----------------------------------------------------------------------------
# 2. MRR CONCENTRATION (80/20 CHECK)
# -----------------------------------------------------------------------------

sorted_risk = segments.sort_values("churn_prob", ascending=False).copy()
sorted_risk["cumulative_mrr_pct"] = (
    sorted_risk["total_mrr"].cumsum() / sorted_risk["total_mrr"].sum() * 100
)
sorted_risk["cumulative_accounts_pct"] = (
    np.arange(1, len(sorted_risk) + 1) / len(sorted_risk) * 100
)

# What % of accounts hold 80% of at-risk MRR?
top_accounts_for_80pct = (sorted_risk["cumulative_mrr_pct"] <= 80).sum()
print(f"\n=== MRR CONCENTRATION ===")
print(f"Top {top_accounts_for_80pct} accounts ({top_accounts_for_80pct/len(sorted_risk)*100:.1f}%) "
      f"hold 80% of at-risk MRR")


# -----------------------------------------------------------------------------
# 3. RETENTION IMPACT — EXACT NUMBERS FROM MODEL
# -----------------------------------------------------------------------------

# Already computed in pipeline; just print cleanly
impact_summary = summary[summary["metric"] != "offset"].copy()
impact_summary["label"]     = impact_summary["metric"].map(LABEL_MAP).fillna(impact_summary["metric"])
impact_summary["impact_pp"] = (impact_summary["retain_impact"] * 100).round(2)
impact_summary = impact_summary[["label", "weight", "impact_pp"]].sort_values("impact_pp", ascending=False)

print("\n=== RETENTION IMPACT PER METRIC (percentage points) ===")
print(impact_summary.to_string(index=False))
print(f"\nBaseline retention (average customer): {baseline_retention*100:.1f}%")


# -----------------------------------------------------------------------------
# 4. CHURN THRESHOLD DETECTION (from cohort plots, now as numbers)
# -----------------------------------------------------------------------------

def churn_threshold_table(df, metric, n_buckets=10):
    """Returns exact churn rate per quantile bucket for a metric."""
    df = df.copy()
    df["bucket"] = pd.qcut(df[metric], n_buckets, duplicates="drop")
    return (
        df.groupby("bucket", observed=True)
        .agg(
            n           = ("is_churn", "count"),
            churn_rate  = ("is_churn", "mean"),
            metric_mean = (metric,     "mean"),
        )
        .round(4)
    )

print("\n=== CHURN BY LOGIN BUCKET ===")
print(churn_threshold_table(df, "login_count_28d").to_string())

print("\n=== CHURN BY DAYS SINCE LOGIN BUCKET ===")
print(churn_threshold_table(df, "days_since_login").to_string())

print("\n=== CHURN BY REPORT RUNS BUCKET ===")
print(churn_threshold_table(df, "report_run_28d").to_string())


# -----------------------------------------------------------------------------
# 5. TENURE PATTERN — CHURN RATE BY MONTHS SINCE SIGNUP
# -----------------------------------------------------------------------------

df_tenure = df.copy()
df_tenure["tenure_month"] = (df_tenure["account_tenure_days"] / 30).astype(int).clip(upper=15)

tenure_churn = (
    df_tenure.groupby("tenure_month")
    .agg(n=("is_churn", "count"), churn_rate=("is_churn", "mean"))
    .round(4)
)

print("\n=== CHURN RATE BY TENURE MONTH ===")
print(tenure_churn.to_string())


# -----------------------------------------------------------------------------
# 6. QUICK HEADLINE NUMBERS 
# -----------------------------------------------------------------------------

total_active       = len(forecast_df)
high_risk_n        = (forecast_df["churn_prob"] > 0.25).sum()
high_risk_mrr      = segments.loc[segments["risk_tier"] == "high", "total_mrr"].sum()
total_mrr          = segments["total_mrr"].sum()
avg_churn          = forecast_df["churn_prob"].mean()
total_flv          = clv_df["flv"].sum()
total_var          = clv_df["value_at_risk"].sum()

print("\n=== HEADLINE NUMBERS ===")
print(f"Active accounts:               {total_active}")
print(f"High-risk accounts (>25%):     {high_risk_n}  ({high_risk_n/total_active*100:.1f}%)")
print(f"High-risk MRR:                 ${high_risk_mrr:,.0f}  ({high_risk_mrr/total_mrr*100:.1f}% of total)")
print(f"Average forecast churn prob:   {avg_churn:.1%}")
print(f"Total portfolio FLV:           ${total_flv:,.0f}")
print(f"Total value at risk:           ${total_var:,.0f}")
