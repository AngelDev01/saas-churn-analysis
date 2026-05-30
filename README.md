# SaaS Churn Analysis: Revenue Retention & Customer Risk

## Project Background

**Context:**
This project applies a rigorous churn analytics methodology to a synthetic SaaS dataset simulating the full pipeline a Customer Success or Revenue Operations team would run — from raw subscription and event data through behavioral modeling to individual account risk scoring. The analysis covers a 15-month operating window (January 2023 – April 2024) across 3,000 accounts.

**KPIs Investigated:**
- **North Star:** Net MRR Retention Rate
- **Primary Metrics:** Account Churn Rate, MRR Churn Rate, Value at Risk, Future Lifetime Value
- **Supporting Metrics:** Churn by Plan & Billing Period, Acquisition Channel ROI, Behavioral Retention Drivers, Revenue Leakage

Insights and recommendations are provided on the following key areas:

- **Revenue Health** — Net retention, MRR churn, revenue leakage from failed invoices
- **Behavioral Drivers** — Which in-product behaviors predict retention and churn
- **Customer Risk Segmentation** — Current portfolio risk distribution and intervention priorities
- **Acquisition & Monetization** — Channel ROI, plan mix, upgrade and downgrade flow

SQL queries for data preparation and churn metrics: **[GitHub Link — Placeholder]**

Python analysis pipeline: **[GitHub Link — Placeholder]**

[DASHBOARD PLACEHOLDER — add link once built]

---

## Data Structure & Initial Checks

The analysis draws from a normalized schema in the `churn_analysis` schema comprising four tables totaling **[PLACEHOLDER — total record count across all four tables]**:

[ERD / SCHEMA DIAGRAM PLACEHOLDER]

| Table | Rows | Description |
|---|---|---|
| `accounts` | 3,000 | One row per customer — signup date, channel, plan, region, CAC |
| `subscriptions` | [PLACEHOLDER] | Billing periods with plan, MRR, status, and churn dates |
| `events` | [PLACEHOLDER] | Raw product events — logins, report runs, exports, team invites, support tickets |
| `invoices` | 63,342 | Invoice-level revenue with payment status and discounts |

**Data Quality Notes**
- 2% of event timestamps are null by design — excluded from behavioral metric calculations
- Churn is measured at billing cycle end, not calendar month, to reflect actual renewal decisions
- Active subscriptions carry a null `end_date`; treated as ongoing through April 1, 2024
- High-risk threshold defined as >25% forecast churn probability; value at risk reflects expected MRR loss in the current billing period

---

## Executive Summary

### Overview of Findings

The portfolio is fundamentally healthy: net MRR retention is **126%**, meaning expansion revenue from upgrades outpaces all churn and downgrades combined. Account-level churn is low at **2.7% in March 2024**, and the model is well-calibrated with a predicted churn rate of 5.15% against an observed 5.12%. The primary risks are concentrated and addressable: **$195K in permanently lost revenue** from failed and written-off invoices, **135 high-risk accounts** holding $27K in MRR, and a clear behavioral threshold below which churn risk increases sharply.

**Three takeaways for leadership:**

1. **Billing period is the single most controllable retention lever.** Annual subscribers churn at roughly half the rate of monthly subscribers across every plan. Shifting 10% of monthly basic accounts to annual would have measurable MRR impact.

2. **Churn risk is behavioral, not demographic.** Accounts with fewer than 2 logins and fewer than 3 report runs in the first 28 days churn at 4–8x the baseline. Early activation is the clearest intervention point in the data.

3. **Revenue leakage from failed invoices exceeds the MRR held by the entire high-risk segment.** The $195K in failed and written-off invoices is a recoverable operations problem, not a churn problem — and it is larger than the $27K MRR at risk from the 135 highest-churn-probability accounts.

[DASHBOARD OVERVIEW IMAGE PLACEHOLDER]

---

## Insights Deep Dive

### Category 1: Revenue Health

- **Insight 1: Net MRR retention is 126% — the business grows without new customers.**
Existing customers generated $799K in MRR in April 2024 against a $633K starting base in March, a net gain of $166K driven by upgrades outpacing churn. For context, most SaaS businesses consider 100%+ net retention healthy; 120%+ is considered strong. **Business metric:** Net MRR Retention Rate. **Quantified value:** 126.3% — $633K starting MRR → $799K retained MRR.

- **Insight 2: MRR churn is low but downgrades contribute more than pure churn.**
Total MRR churn rate is 1.84% in March 2024, composed of $3,869 lost to full cancellations and $7,764 lost to downgrades. Downgrades represent 2x the direct churn loss. **Business metric:** MRR Churn Rate split by cancellation vs. downgrade. **Quantified value:** 1.84% total — $3,869 churn MRR + $7,764 downsell MRR against $633K base.

- **Insight 3: Revenue leakage from failed invoices exceeds the MRR of the entire high-risk account segment.**
$118K is permanently written off and $77K failed with no recovery, totaling $195K in lost gross revenue. An additional $289K sits past due. This is an accounts receivable operations problem — the money was earned but not collected. **Business metric:** Revenue by invoice status. **Quantified value:** $195K permanently lost (3.7% of $5.2M gross revenue collected); $289K past due and at risk.

<img src="assets/net_mrr_retention.png" 
     alt="net retention kpi" 
     align="right" 
     width="400" />
<img src="assets/value_at_risk.png" 
     alt="value at risk kpi" 
     align="right" 
     width="400" />
<img src="assets/revenue_leakage.png" 
     alt="revenue leakage kpi" 
     align="right" 
     width="400" />


---

### Category 2: Behavioral Drivers

- **Insight 1: Login growth trend is the strongest single predictor of retention.**
Whether engagement is growing or declining over the prior 28 days matters more than absolute login count. A one standard deviation increase in login trend improves predicted retention probability by **+1.46 percentage points** — the highest impact of any metric in the model. **Business metric:** Login count 28-day percentage change. **Quantified value:** +1.46pp retention impact per std-dev; second strongest is session duration at +1.28pp.

- **Insight 2: There is a hard activation threshold at 2 logins and 3 report runs.**
Accounts with 0–1 logins in 28 days churn at **12.0%** — 4.7x the rate of accounts with just 2 logins (2.5%). The relationship is non-linear: the jump happens almost entirely at zero, not gradually across the range. Report runs show the same pattern: 0–1 runs churn at 9.1%, dropping to 1.9% at 3 runs. Above these thresholds churn stabilizes. **Business metric:** Churn rate by login and report run bucket. **Quantified value:** 12.0% churn at 0–1 logins vs. 2.5% at 2 logins; 9.1% churn at 0–1 report runs vs. 1.9% at 3 runs.

- **Insight 3: Days since last export is an earlier churn warning signal than days since last login.**
Export activity dropping off predicts churn with a retention impact of +0.66pp, compared to +0.48pp for days since login. Power users who stop exporting have likely stopped deriving value before they visibly disengage from the product. **Business metric:** Days since last feature export vs. days since last login. **Quantified value:** Export dormancy impact +0.66pp vs. login dormancy +0.48pp.


[BEHAVIORAL COHORT CHARTS PLACEHOLDER]

---

### Category 3: Customer Risk Segmentation

- **Insight 1: Risk is spread across the portfolio — a targeted high-touch strategy alone is insufficient.**
The top 66.8% of accounts by churn probability hold 80% of at-risk MRR. Risk is not concentrated in a small identifiable group. A scalable, automated intervention approach is needed alongside any high-touch program. **Business metric:** MRR concentration by churn probability rank. **Quantified value:** 1,710 of 2,558 active accounts needed to cover 80% of at-risk MRR.

- **Insight 2: The high-risk segment is small but has a distinct behavioral profile.**
135 accounts (5.3% of active base) carry >25% churn probability. They log in 25% less frequently (7.9 vs. 10.5 average logins), run 25% fewer reports (4.95 vs. 6.56), and have been inactive 9% longer (7.57 vs. 8.34 days since last login) than low-risk accounts. MRR is slightly lower ($245 vs. $272 average), suggesting smaller accounts churn at higher rates. **Business metric:** Behavioral metrics by risk tier. **Quantified value:** 135 accounts, $27K MRR (4.6% of total), avg churn probability 36%.

- **Insight 3: Intervening by churn probability alone misses the highest-value accounts at risk.**
The 10 accounts with highest value at risk have churn probabilities between 1.9% and 8.6% — well below the high-risk threshold — but MRR between $2,388 and $2,985. Account 1719 has only a 1.9% churn probability but $2,049 in value at risk this period. Sorting by value at risk rather than churn probability identifies different accounts and should drive the intervention priority list. **Business metric:** Value at risk = margin × MRR × churn probability. **Quantified value:** Total portfolio value at risk $462K; top 10 VaR accounts all have MRR >$2,300 and churn probability <9%.

- **Insight 4: Churn spikes at month 13, suggesting annual contract non-renewal is a distinct risk event.**
Churn rate is stable at 4.5–5.5% through months 0–12, then jumps to 7.1% at month 13 and 8.6% at month 14. The month 13 reading is based on 240 observations and is reliable. This pattern indicates annual customers deciding not to renew, which is a separate behavioral signal from monthly churn and warrants a dedicated retention touchpoint at the 11-month mark. **Business metric:** Churn rate by tenure month. **Quantified value:** Month 0–12 avg ~5.0%; month 13: 7.1% (n=240); month 14: 8.6% (n=58, treat with caution).

[RISK SEGMENTATION CHART PLACEHOLDER]

---

### Category 4: Acquisition & Monetization

- **Insight 1: Annual billing is the most effective retention lever and it is underutilized.**
Annual subscribers churn at roughly half the rate of monthly subscribers on Basic (4.6% vs. 8.3%) and Pro (4.3% vs. 5.8%) plans. Team plan shows minimal difference (4.7% vs. 4.9%), consistent with team accounts being stickier regardless of billing. Promoting annual billing at signup or at the first renewal is the highest-ROI retention intervention available without product changes. **Business metric:** Churn rate by plan and billing period. **Quantified value:** Basic annual 4.6% vs. monthly 8.3% — 44% lower churn; Pro annual 4.3% vs. monthly 5.8% — 26% lower churn.

- **Insight 2: Paid social has the worst acquisition ROI by a wide margin — and organic is both the largest and most efficient channel.**
Organic acquisition costs $50 CAC and generates $69 avg MRR — a 1.39 MRR-to-CAC ratio — and drives 1,169 accounts (39% of total base). Paid social costs $150 CAC for the same $68 avg MRR, a ratio of 0.45, less than a third of organic efficiency. Churn rates are nearly identical across all channels (6.1–6.6%), meaning the entire ROI gap is driven by acquisition cost, not customer quality. The fact that the highest-volume channel also has the best unit economics suggests untapped potential in inbound over outbound. **Business metric:** MRR-to-CAC ratio and account volume by channel. **Quantified value:** Organic 1.39 vs. paid social 0.45 — 3x more capital efficient; organic is largest channel at 39% of accounts; content has lowest churn at 6.1%.

- **Insight 3: The baseline customer is highly likely to stay — churn is a minority event.**
Baseline retention probability for an average active account is **97.4%** per observation period. Average forecast churn across the active portfolio is 6.6% annualized. The business is not in a churn crisis — it has a concentrated risk problem in a small segment and a revenue leakage problem in invoicing. **Business metric:** Baseline retention probability from logistic regression intercept. **Quantified value:** 97.4% baseline retention; 6.6% average forecast churn; 2,092 of 2,558 active accounts (81.8%) are low-risk.

[ACQUISITION & MONETIZATION CHART PLACEHOLDER]

---

## Recommendations

Based on the insights above, I recommend the **Revenue Operations and Product Leadership Team** consider:

- **Observation:** Annual subscribers churn at 44% lower rates than monthly on the Basic plan, and 26% lower on Pro. **Recommendation:** Introduce annual billing prompts at signup and at the 3-month mark for monthly accounts; test a discount offer (current model uses 17% annual discount) targeting the Basic monthly segment specifically, which has the highest churn rate at 8.3%.

- **Observation:** Accounts with <2 logins and <3 report runs in the first 28 days churn at 4–8x the baseline rate. **Recommendation:** Define a formal activation milestone of 2 logins + 3 report runs within 28 days; build an onboarding sequence that drives new accounts to this threshold in the first two weeks; monitor activation rate as a leading indicator of monthly churn.

- **Observation:** $195K in permanently lost revenue from failed and written-off invoices represents 3.7% of gross revenue and exceeds the MRR of the entire high-risk account segment. **Recommendation:** Implement automated payment retry logic for failed invoices; add proactive outreach for past-due accounts before write-off; treat invoice recovery as a revenue initiative separate from churn reduction.

- **Observation:** Churn spikes at month 13, consistent with annual contract non-renewal. **Recommendation:** Introduce a dedicated customer success touchpoint at month 11 for annual subscribers — a usage review, a renewal incentive, or an upgrade conversation — before the renewal decision is made.

- **Observation:** Paid social has a 0.45 MRR-to-CAC ratio versus organic at 1.39, and churn rates are nearly identical across channels. **Recommendation:** Reallocate 20–30% of paid social budget toward content and SEO; the ROI gap is entirely a cost problem, not a quality problem, so reducing paid spend does not sacrifice customer retention.

- **Observation:** The 10 highest value-at-risk accounts have low churn probability but very high MRR ($2,300–$2,985). **Recommendation:** Run a separate high-touch retention program for accounts with MRR >$2,000 regardless of churn probability; value at risk, not churn probability, should drive account management prioritization for enterprise-tier accounts.

---

## Assumptions and Caveats

- **Churn timing:** Churn is measured at billing cycle end, not calendar month. Monthly and annual subscribers are compared on their respective cycles; the rates are not directly equivalent.

- **High-risk definition:** Accounts above 25% forecast churn probability are classified as high-risk. This threshold is analytical, not a product SLA.

- **Value at risk formula:** Value at risk = gross margin (70%) × MRR × churn probability. It reflects expected revenue loss in the current billing period, not total lifetime loss.

- **Month 14 tenure churn:** The 8.6% churn rate at month 14 is based on 58 observations and should be treated as directional, not conclusive. Month 13 (n=240) is more reliable.

- **Synthetic data:** This dataset was generated to match realistic SaaS behavioral patterns including seasonality, cohort drift, engagement decay before churn, and billing-aligned cancellation. Findings are structurally valid but absolute numbers should not be extrapolated to a real portfolio without recalibration on live data.

- **Model drift:** The rescoring drift check shows `feature_report_run_28d_pct_change` at a 0.61 ratio between historical and current means — the lowest in the dataset. Monitor this metric; if it continues diverging, the model should be retrained.
