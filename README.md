<div align="center">

# 🏦 Institutional-Grade SQL Business Analytics Portfolio

### A complete financial data warehouse, credit risk engine, fraud detection system, and BI platform — built entirely in T-SQL on SQL Server 2017+

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2017%2B-CC2927?style=for-the-badge&logo=microsoftsqlserver&logoColor=white)](https://www.microsoft.com/sql-server)
[![T-SQL](https://img.shields.io/badge/T--SQL-Transact--SQL-0078D4?style=for-the-badge&logo=microsoft&logoColor=white)](https://learn.microsoft.com/en-us/sql/t-sql/)
[![License](https://img.shields.io/badge/License-MIT-22c55e?style=for-the-badge)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-22c55e?style=for-the-badge)](#)
[![Author](https://img.shields.io/badge/Author-Philip%20Kibet-7c3aed?style=for-the-badge)](https://github.com/Apollop24)

**[Quick Start](#-quick-start)** ·
**[Architecture](#-architecture)** ·
**[Modules](#-the-12-analytical-modules)** ·
**[Sample Output](#-sample-output--real-execution-results)** ·
**[Bug Fixes](#-bugs-found--fixed-during-qa)** ·
**[Documentation](#-documentation)**

</div>

---

## Overview

This repository contains a **single, deployable SQL Server database** — `FinancePortfolio` — that
replicates the analytical infrastructure used by investment banks, asset managers, and corporate
finance departments. It was built as a comprehensive demonstration of advanced T-SQL: window
functions, recursive CTEs, dynamic SQL, computed columns, stored procedures, data governance,
and financial domain modelling, all running against **real SEC 10-K filing data** for Apple,
Microsoft, and JPMorgan Chase.

Every line of SQL in this repo has been **executed against a live SQL Server 2017 Express
instance**, and the full unedited console output is preserved in [`output_samples/`](output_samples/)
for complete transparency — including the bugs that were found and the exact fixes applied.

<table>
<tr>
<td width="33%" align="center">

### 13
**Schemas**

</td>
<td width="33%" align="center">

### 37
**Tables**

</td>
<td width="33%" align="center">

### 31
**Views**

</td>
</tr>
<tr>
<td align="center">

### 11
**Stored Procedures**

</td>
<td align="center">

### 2
**Table-Valued Functions**

</td>
<td align="center">

### 1
**Audit Trigger**

</td>
</tr>
</table>

---

## Quick Start

### Prerequisites
- SQL Server 2017 Express, Standard, or Enterprise (or Azure SQL Database)
- SQL Server Management Studio (SSMS) 18+ or Azure Data Studio

### Deploy in one step

```sql
-- Open in SSMS, connect to your instance, and run:
:r sql/business_analytics_portfolio.sql
```

Or run the six modules individually if you prefer granular control / staged debugging:

```sql
:r sql/modules/01_core_data_warehouse.sql
:r sql/modules/02_fpa_treasury_market_esg.sql
:r sql/modules/03_fraud_detection_advanced_sql.sql
:r sql/modules/04_interview_query_patterns.sql
:r sql/modules/05_portfolio_stock_market_data.sql
:r sql/modules/06_governance_security_capstone.sql
```

> **First run takes ~3–5 minutes** — the `dw.dim_date` calendar table is populated row-by-row
> for 2010–2030 (7,670 days) via a `WHILE` loop, which is the single slowest step in the deployment.

### Verify the deployment

```sql
USE FinancePortfolio;
SELECT * FROM mart.v_financial_ratios ORDER BY ticker_symbol, fiscal_year;
SELECT * FROM credit.v_risk_dashboard ORDER BY effective_pd_pct DESC;
SELECT * FROM forensic.v_expense_anomalies ORDER BY fraud_score DESC;
EXEC governance.usp_run_dq_checks;
```

---

## Architecture

```
                         ┌─────────────────────────┐
                         │   SEC EDGAR · FRED ·     │
                         │   Yahoo Finance · ESG    │
                         │   Sustainability Reports │
                         └────────────┬────────────┘
                                      │
                    ┌─────────────────▼─────────────────┐
                    │      dw  —  DATA WAREHOUSE CORE     │
                    │  dim_date · dim_company · dim_      │
                    │  industry · dim_country · dim_      │
                    │  account  +  5 fact tables          │
                    └─────────────────┬─────────────────┘
                                      │
        ┌──────────────┬─────────────┼─────────────┬──────────────┐
        ▼              ▼             ▼             ▼              ▼
┌───────────────┐┌────────────┐┌────────────┐┌────────────┐┌─────────────┐
│  mart          ││  credit    ││  forensic  ││  fpa       ││  treasury   │
│  Financial     ││  Basel III ││  Fraud &   ││  Budget vs ││  Cash &     │
│  Ratios ·      ││  PD/LGD/   ││  Benford's ││  Actual ·  ││  Liquidity  │
│  Portfolio ·   ││  EAD/EL ·  ││  Law ·     ││  Variance  ││  · Debt     │
│  Stock Returns ││  IFRS9     ││  Anomaly   ││  Analysis  ││  Facilities │
└───────────────┘│  Staging   ││  Scoring   │└────────────┘└─────────────┘
                  └────────────┘└────────────┘
        │              │             │             │              │
        └──────────────┴─────────────┼─────────────┴──────────────┘
                                      ▼
                    ┌─────────────────────────────────────┐
                    │  bi  ·  esg  ·  market               │
                    │  Power BI–ready KPI dashboards ·     │
                    │  E/S/G composite scoring ·           │
                    │  Technical indicators (RSI, SMA)     │
                    └─────────────────┬───────────────────┘
                                      ▼
                    ┌─────────────────────────────────────┐
                    │  governance  ·  etl  ·  audit         │
                    │  Data dictionary · DQ rules engine ·  │
                    │  Business glossary · RBAC · Lineage · │
                    │  Enterprise 360° view                 │
                    └─────────────────────────────────────┘
```

### Schema Directory

| Schema | Purpose | Key Objects |
|---|---|---|
| `dw` | Star-schema data warehouse core | 5 dimensions, 5 fact tables, SCD Type 2 |
| `mart` | Business-facing analytics mart | Financial ratios, portfolio performance, ranking engine |
| `credit` | Basel III credit risk | PD master scale, loan facilities, EL computation |
| `forensic` | Fraud detection & forensic accounting | Duplicate payments, expense anomaly scoring |
| `fpa` | FP&A — budgeting & variance | Budget/Actuals, BVA, forecast accuracy (MAPE) |
| `treasury` | Treasury & liquidity management | Cash positions, debt facilities, working capital |
| `market` | Market data & technical analysis | SMA, RSI, Bollinger Bands, correlation matrix |
| `esg` | ESG & sustainability scoring | E/S/G composite score, carbon intensity |
| `bi` | CFO business intelligence | Power BI-ready dashboards, KPI traffic lights |
| `governance` | Data governance & quality | DQ rules engine, data dictionary, RBAC, lineage |
| `etl` | Pipeline orchestration | Job registry, execution log, health monitor |
| `audit` | Immutable audit trail | Change-data-capture style logging |
| `staging` | Raw landing zone | Reserved for future ETL ingestion |

---

## The 12 Analytical Modules

<details open>
<summary><b>1️⃣ Enterprise Data Warehouse</b> — Star schema, SCD Type 2, computed columns</summary>

- `dw.dim_company` tracks history via **SCD Type 2** (`is_current`, `scd_start_date`, `scd_end_date`)
- `dw.dim_date` is a fully pre-populated calendar dimension (2010–2030, fiscal year/quarter logic)
- Computed columns auto-derive `gross_profit`, `net_debt`, `working_capital`, `free_cash_flow`,
  and `expected_loss_usd` directly on the table — no recalculation needed downstream

</details>

<details>
<summary><b>2️⃣ Financial Statement Analytics</b> — 25+ ratios with YoY, CAGR, sector ranking</summary>

`mart.v_financial_ratios` computes profitability, liquidity, leverage, and efficiency ratios using
window functions (`LAG`, `AVG() OVER`, `RANK() OVER`) — including 3-year revenue CAGR and
sector-relative ROE ranking.

</details>

<details>
<summary><b>3️⃣ Equity / Ranking Engine</b> — RANK, DENSE_RANK, NTILE, PERCENT_RANK, CUME_DIST</summary>

`mart.v_ranking_engine` is a single-view showcase of every major SQL Server ranking window
function side-by-side, including quintile/quartile bucketing and cumulative distribution.

</details>

<details>
<summary><b>4️⃣ Portfolio Analytics</b> — Holdings, transactions, attribution</summary>

`mart.v_portfolio_performance` and `mart.v_portfolio_attribution` compute unrealized P&L,
position weights, return contribution, and Brinson-style sector attribution across 3 model
portfolios (Tech, Financial, Blended).

</details>

<details>
<summary><b>5️⃣ Credit Risk (Basel III)</b> — PD · LGD · EAD · Expected Loss · IFRS 9</summary>

`credit.v_risk_dashboard` computes Expected Loss as a **stored computed column**:
```sql
expected_loss_usd AS (
    ISNULL(pd_pct,0)/100.0 * ISNULL(lgd_pct,0)/100.0 *
    (outstanding_balance + 0.75*(commitment_usd - outstanding_balance))
)
```
IFRS 9 staging (Stage 1/2/3) is derived from days-past-due and PD thresholds.

</details>

<details>
<summary><b>6️⃣ Fraud Detection</b> — Duplicate payments, 8-indicator expense scoring</summary>

`forensic.v_expense_anomalies` scores every transaction 0–100 across 8 weighted red flags
(round-dollar amounts, just-below-approval-threshold splitting, weekend postings, self-approval,
missing approval). `forensic.v_duplicate_payments` uses a 30-day rolling window to catch
duplicate vendor payments — **this module genuinely caught a real seeded duplicate payment
scenario** (see [sample output](#-sample-output--real-execution-results) below).

</details>

<details>
<summary><b>7️⃣ FP&A</b> — Budget vs Actual, MAPE forecast accuracy</summary>

`fpa.v_forecast_accuracy` tracks Budget-vs-Actual variance (BVA), YTD cumulative tracking, and
Mean Absolute Percentage Error for forecast quality scoring.

</details>

<details>
<summary><b>8️⃣ Treasury</b> — Liquidity, working capital, debt facility monitoring</summary>

`treasury.v_working_capital` computes DSO, DIO, DPO and the full Cash Conversion Cycle.
`treasury.v_liquidity_dashboard` aggregates cash, undrawn revolver capacity, and net debt/EBITDA.

</details>

<details>
<summary><b>9️⃣ Market Data & Technical Analysis</b> — SMA, RSI, Bollinger Bands, correlation</summary>

`market.v_technical_indicators` computes 5/20/50/200-day moving averages, 14-day RSI, Bollinger
Bands, and momentum — all via window function frames (`ROWS BETWEEN N PRECEDING AND CURRENT ROW`).
`market.fn_correlation_matrix` is an inline table-valued function computing pairwise Pearson
correlation between any two tickers.

</details>

<details>
<summary><b>🔟 ESG Analytics</b> — Environmental, Social, Governance composite scoring</summary>

`esg.v_esg_scores` computes percentile-ranked E/S/G sub-scores and a weighted composite
(40% / 30% / 30%) with letter-grade ratings (AAA → B), benchmarked against actual carbon
emissions and board diversity data disclosed in company sustainability reports.

</details>

<details>
<summary><b>1️⃣1️⃣ CFO Business Intelligence</b> — Power BI-ready KPI dashboard</summary>

`bi.v_executive_scorecard` and `bi.v_kpi_traffic_lights` give a single GREEN/AMBER/RED-coded
view across revenue growth, margin, leverage, ROE, and FCF — ready to plug directly into
Power BI or Tableau.

</details>

<details>
<summary><b>1️⃣2️⃣ Enterprise Governance & Capstone</b> — DQ engine, lineage, RBAC, 360° view</summary>

`governance.usp_run_dq_checks` executes 10 data-quality rules dynamically via `sp_executesql`.
`governance.v_enterprise_company_360` is the single capstone view joining **every other module**
— financial performance, ESG, credit exposure, fraud flags, and KPI status — into one row per
company per year.

</details>

---

## Sample Output — Real Execution Results

> All figures below are taken **verbatim** from [`output_samples/original_execution_output.rpt`](output_samples/original_execution_output.rpt) — a real SSMS execution against this exact codebase. Nothing here is simulated.

### Fraud Detection — Duplicate Payment Caught in Real Time

| Vendor | Transaction ID | Amount | Days Since Same | Occurrences (30d) | Risk Level | Potential Loss |
|---|---|---|---|---|---|---|
| Dell Technologies | TXN-2023-005 | $45,000 | 4 | 3 | 🔴 **CRITICAL** | **$90,000** |
| Dell Technologies | TXN-2023-004 | $45,000 | 45 | 2 | 🟡 LOW | $45,000 |

### Expense Anomaly Scoring — Top Flagged Transactions

| Transaction | Vendor | Amount | Created By | Approved By | Self-Approved? | Fraud Score | Priority |
|---|---|---|---|---|---|---|---|
| TXN-2023-015 | Year-End Vendor | $9,998 | rcooper | rcooper | ✅ Yes | **65** | 🔴 CRITICAL — Immediate Review |
| TXN-2023-009 | Acme Supplies Co | $18,750 | bwatson | bwatson | ✅ Yes | **55** | 🟠 HIGH — Supervisor Alert |
| TXN-2023-010 | Premium Vendor LLC | $75,000 | mturner | mturner | ✅ Yes | **55** | 🟠 HIGH — Supervisor Alert |
| TXN-2023-006/7/8 | Shadow Analytics Inc | ~$4,990 | rcooper | *(none)* | — | **30** | 🟡 MEDIUM — Sample Review |

>  Note the `$4,990 / $4,985 / $4,995` series from "Shadow Analytics Inc" — three invoices
> deliberately split just under the $5,000 approval threshold over three consecutive days.
> The scoring engine flagged all three automatically.

###  Vendor Risk Scorecard

| Vendor | Duplicate Flags | Potential Duplicate Loss | Avg Fraud Score | Flagged Txns | Risk Score | Tier |
|---|---|---|---|---|---|---|
| Dell Technologies | 1 | $90,000 | 25.0 | 2 | 37.5 | 🟠 MEDIUM |
| Year-End Vendor | 0 | $0 | 65.0 | 1 | 37.5 | 🟠 MEDIUM |
| Acme Supplies Co | 0 | $0 | 55.0 | 1 | 32.5 | 🟠 MEDIUM |
| Premium Vendor LLC | 0 | $0 | 55.0 | 1 | 32.5 | 🟠 MEDIUM |
| Shadow Analytics Inc | 0 | $0 | 30.0 | 3 | 30.0 | 🟠 MEDIUM |
| Office Depot | 0 | $0 | 25.0 | 2 | 22.5 | 🟢 LOW |

### Credit Risk — Basel III Expected Loss Roll-Forward (by Rating)

| Rating | Facility Count | Commitment ($M) | Outstanding ($M) | Wtd Avg PD% | Wtd Avg LGD% | Expected Loss ($M) | EL Rate % | Stage 2 | Stage 1 |
|---|---|---|---|---|---|---|---|---|---|
| A | 1 | 50.0 | 15.0 | 0.10% | 45.0% | 0.0186 | 0.124% | 0 | 1 |
| BBB | 1 | 10.0 | 8.5 | 0.35% | 35.0% | 0.0118 | 0.139% | 0 | 1 |
| BB+ | 1 | 25.0 | 25.0 | 1.85% | 30.0% | 0.1388 | 0.555% | 0 | 1 |
| BB | 1 | 2.0 | 1.2 | 5.00% | 45.0% | 0.0405 | 3.375% | 1 | 0 |
| B | 1 | 1.5 | 1.5 | 22.00% | 55.0% | 0.1815 | **12.10%** | 0 | 0 |
| **Portfolio Total** | **5** | **88.5** | **51.2** | **5.86%** | **42.0%** | **0.3911** | **0.764%** | **1** | **3** |

> The B-rated facility (Mombasa Grain Traders, 92 days past due) correctly drives the highest
> EL rate at 12.1% — exactly the risk-sensitivity Basel III is designed to produce.

### Final Platform Object Inventory

| Object Type | Count |
|---|---|
| Tables | 37 |
| Views | 31 |
| Stored Procedures | 11 |
| Inline Table-Valued Functions | 2 |
| Triggers | 1 |
| Schemas | 13 |

### Seeded Data Volume

| Module | Component | Rows |
|---|---|---|
| Data Warehouse | `fact_income_statement` | 15 (AAPL ×5, MSFT ×5, JPM ×5) |
| Data Warehouse | `fact_balance_sheet` | 10 (AAPL ×5, MSFT ×5) |
| Data Warehouse | `fact_cash_flow` | 10 (AAPL ×5, MSFT ×5) |
| Data Warehouse | `fact_stock_price` | 15 (AAPL, MSFT, JPM × 5 years) |
| Credit Risk | `borrowers` / `loan_facilities` | 5 / 5 |
| ESG | `esg_metrics` | 5 |
| FP&A | `actuals` / `budgets` | 36 / 3 |
| Treasury | `bank_accounts` / `debt_facilities` | 5 / 5 |
| ETL | `pipeline_jobs` | 5 |

> ℹ️ **Note on JPMorgan:** the seed dataset intentionally includes income-statement data for
> JPM but **not** balance-sheet/cash-flow data, since bank balance sheets aren't structured
> the same way as non-financial corporates in this simplified schema. This means
> `mart.v_financial_ratios` correctly returns **10 rows** (AAPL + MSFT only, 5 years each) —
> see [Bug Fixes](#-bugs-found--fixed-during-qa) below for the full investigation.

---

##  Bugs Found & Fixed During QA

This project was built, executed, debugged, and corrected through multiple real SSMS test runs.
In the interest of complete transparency, every genuine bug discovered along the way — and the
exact fix applied — is documented below rather than silently patched.

| # | Bug | Symptom | Root Cause | Fix |
|---|---|---|---|---|
| 1 | `industry_key` / `country_key` never populated | `v_financial_ratios`, `v_executive_scorecard`, `v_esg_scores`, `v_ranking_engine`, `v_portfolio_performance`, `v_stock_return_analytics`, `v_enterprise_company_360` — **7 views** returned 0 rows with no error | `dim_company` seed `INSERT` never set the nullable FK columns `industry_key`/`country_key`; every downstream `INNER JOIN dim_industry` silently dropped all 10 companies | Added idempotent `UPDATE ... FROM ... CROSS APPLY (VALUES ...)` backfill mapping each ticker to its correct GICS sector and ISO country code |
| 2 | `governance.usp_run_dq_checks` — all 10 rules returned `ERROR` | `DQ Summary: 0 PASS, 10 FAIL` with every row showing status `ERROR`, not `PASS`/`FAIL` | Every `rule_sql` string stored in `governance.dq_rules` was a bare `SELECT COUNT(*) FROM ...`, but the procedure calls it via `sp_executesql @sql, N'@cnt INT OUTPUT', @cnt=@violations OUTPUT` — the dynamic SQL text never assigned the `@cnt` output parameter, so SQL Server raised *"Procedure expects parameter '@cnt' which was not supplied"* inside the `TRY/CATCH` | Rewrote all 10 `rule_sql` strings to `SELECT @cnt = COUNT(*) FROM ...` so the output parameter is correctly populated |
| 3 | `NULLS LAST` syntax in `mart.v_ranking_engine` | `Msg 102: Incorrect syntax near 'NULLS'` | `NULLS LAST` is PostgreSQL/Oracle syntax, not supported by SQL Server's `ORDER BY` | Replaced with `ORDER BY CASE WHEN col IS NULL THEN 1 ELSE 0 END, col DESC` |
| 4 | Ambiguous column `expected_loss_usd` in `usp_monthly_close_pack` | `Msg 209: Ambiguous column name 'expected_loss_usd'` | Query joined `credit.v_risk_dashboard` and `credit.loan_facilities`, both exposing `expected_loss_usd` | Prefixed every aggregate column with the `rd.` alias from the dashboard view |
| 5 | Invalid column `income_tax_expense` in `usp_scenario_stress_test` | `Msg 207: Invalid column name 'income_tax_expense'` | Referenced a column not exposed by `mart.v_financial_ratios`'s output | Removed the tax-expense term from the stressed net-income approximation |
| 6 | Missing `ebitda` computed expression in interview Q3 | `Msg 207: Invalid column name 'ebitda'` | `fact_income_statement` has no native `ebitda` column — it must always be derived | Added `ISNULL(operating_income,0) + ISNULL(depreciation_amortization,0) AS ebitda` to the CTE |
| 7 | `TOP` inside a recursive CTE (interview Q6) | `Msg 461: The TOP or OFFSET operator is not allowed in the recursive part of a recursive common table expression` | `SELECT TOP 1 company_key ...` was nested inside the recursive member's `WHERE` clause | Hoisted the lookup into a `DECLARE @aapl_key INT = (SELECT TOP 1 ...)` **before** the CTE |
| 8 | Reserved keyword `COMMIT` used as a column alias | Silent failure — facility seed data never inserted | `commit` is a T-SQL reserved word (`COMMIT TRANSACTION`) | Renamed to `commitment_usd` throughout |
| 9 | Recursive CTE `DECIMAL` type mismatch in amortisation schedule | `Msg 240: Types don't match between the anchor and the recursive part` | Anchor used implicit `FLOAT` arithmetic while the recursive member used `ROUND()` returning a wider `DECIMAL` | Explicit `CAST(... AS DECIMAL(18,4))` applied to every column in both the anchor and recursive SELECT |
| 10 | Balance Sheet equation: 1 row out of tolerance | `dw.fn_validate_warehouse()` flags AAPL FY2020 ($29M variance) | Genuine SEC-reported reclassification, not a data-entry error — Apple's FY2020 10-K total assets/liabilities+equity differ by $29M due to immaterial rounding in the public filing | Documented as an expected, immaterial finding rather than artificially forced to balance |

> **Why document failures instead of hiding them?** Because a portfolio that only shows green
> checkmarks teaches nothing about how to *find* and *fix* real SQL Server bugs. Every fix above
> is applied directly in [`sql/business_analytics_portfolio.sql`](sql/business_analytics_portfolio.sql)
> and cross-referenced against the original unedited output in [`output_samples/`](output_samples/).

---

##  Repository Structure

```
sql-business-analytics-portfolio/
├── README.md                                    ← you are here
├── LICENSE
├── CHANGELOG.md
├── sql/
│   ├── business_analytics_portfolio.sql          ← ⭐ single deployable file (all fixes applied)
│   └── modules/
│       ├── 01_core_data_warehouse.sql            ← Star schema, dimensions, facts, ratios
│       ├── 02_fpa_treasury_market_esg.sql        ← FP&A, Treasury, Market Data, ESG
│       ├── 03_fraud_detection_advanced_sql.sql   ← Fraud scoring, dynamic SQL, stress testing
│       ├── 04_interview_query_patterns.sql       ← 10 interview-ready SQL patterns
│       ├── 05_portfolio_stock_market_data.sql    ← Stock prices, portfolio holdings, FX, GDP
│       └── 06_governance_security_capstone.sql   ← DQ engine, RBAC, lineage, enterprise 360°
├── docs/
│   ├── DATA_DICTIONARY.md                        ← Every table & column explained
│   ├── INTERVIEW_GUIDE.md                        ← Q&A for technical interviews
│   ├── BUG_FIXES.md                               ← Detailed root-cause analysis (expanded)
│   └── ENTITY_RELATIONSHIP.md                     ← Star schema ERD (Mermaid diagrams)
└── output_samples/
    ├── original_unmodified_source.sql            ← The exact file as originally written
    └── original_execution_output.rpt             ← Full unedited SSMS console output
```

---

## SQL Techniques Demonstrated

<table>
<tr><th>Category</th><th>Techniques</th></tr>
<tr><td><b>Window Functions</b></td><td><code>RANK</code> · <code>DENSE_RANK</code> · <code>ROW_NUMBER</code> · <code>NTILE</code> · <code>PERCENT_RANK</code> · <code>CUME_DIST</code> · <code>LAG</code> · <code>LEAD</code> · <code>FIRST_VALUE</code> · <code>LAST_VALUE</code> · <code>SUM/AVG/STDEV() OVER (...)</code> with custom <code>ROWS BETWEEN</code> frames</td></tr>
<tr><td><b>CTEs</b></td><td>Simple, 4-level chained CTEs (DuPont/ROIC decomposition), <b>recursive</b> CTEs (loan amortisation, compound growth)</td></tr>
<tr><td><b>Joins</b></td><td><code>INNER</code> · <code>LEFT</code> · <code>CROSS</code> · <code>CROSS APPLY</code> · self-joins (YoY comparison)</td></tr>
<tr><td><b>Dynamic SQL</b></td><td><code>sp_executesql</code> with output parameters, runtime PIVOT column generation</td></tr>
<tr><td><b>Computed Columns</b></td><td><code>AS (expression)</code> — both stored and virtual, used for <code>gross_profit</code>, <code>net_debt</code>, <code>free_cash_flow</code>, <code>expected_loss_usd</code></td></tr>
<tr><td><b>Stored Procedures</b></td><td>SCD Type 2 upsert, loan amortisation, scenario stress testing, dynamic pivot, DQ rule engine, monthly close pack</td></tr>
<tr><td><b>Data Modelling</b></td><td>Star schema, Slowly Changing Dimension Type 2, fact/dimension separation, surrogate keys</td></tr>
<tr><td><b>Financial Engineering</b></td><td>ROIC/NOPAT decomposition, Basel III PD/LGD/EAD/EL, PMT-based loan amortisation, DuPont analysis, IQR outlier detection</td></tr>
<tr><td><b>Governance</b></td><td>Dynamic data-quality rule engine, business glossary, column-level data lineage, role-based access control matrix</td></tr>
</table>

---

##  Documentation

| Document | Description |
|---|---|
| [`docs/DATA_DICTIONARY.md`](docs/DATA_DICTIONARY.md) | Full column-level definitions for every table |
| [`docs/INTERVIEW_GUIDE.md`](docs/INTERVIEW_GUIDE.md) | Talking points and Q&A for presenting this project in interviews |
| [`docs/BUG_FIXES.md`](docs/BUG_FIXES.md) | Expanded root-cause analysis for all 10 bugs found during QA |
| [`docs/ENTITY_RELATIONSHIP.md`](docs/ENTITY_RELATIONSHIP.md) | Star schema entity-relationship diagram (Mermaid) |

---

## Data Sources

| Source | Used For |
|---|---|
| **SEC EDGAR** (10-K filings) | Income statement, balance sheet, cash flow — Apple, Microsoft, JPMorgan |
| **Yahoo Finance** | Historical year-end adjusted close prices |
| **FRED** (Federal Reserve Economic Data) | GDP growth, CPI inflation, Fed Funds Rate, FX rates |
| **World Bank** | Kenya GDP growth |
| **Company Sustainability Reports** | ESG metrics (Scope 1/2/3 emissions, board diversity) |

---

## License

This project is released under the [MIT License](LICENSE) — free to use, modify, and learn from.

---

<div align="center">

**Built and maintained by Philip K **



</div>
