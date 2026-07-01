# 📖 Data Dictionary

> Complete column-level reference for the `FinancePortfolio` database.
> Generated from [`sql/business_analytics_portfolio.sql`](../sql/business_analytics_portfolio.sql).

---

## Schema: `dw` — Data Warehouse Core

### `dw.dim_date`
Pre-populated calendar dimension, 2010-01-01 through 2030-12-31 (7,670 rows).

| Column | Type | Description |
|---|---|---|
| `date_key` | `INT` (PK) | Surrogate key in `YYYYMMDD` integer format |
| `full_date` | `DATE` | Actual calendar date |
| `fiscal_year` | `SMALLINT` | Fiscal year (April–March convention) |
| `fiscal_quarter` | `SMALLINT` | Fiscal quarter 1–4 |
| `is_weekend` | `BIT` | 1 if Saturday/Sunday |
| `is_month_end` / `is_quarter_end` / `is_year_end` | `BIT` | Period-end flags |

### `dw.dim_company`
Company master with **SCD Type 2** history tracking.

| Column | Type | Description |
|---|---|---|
| `company_key` | `INT` (PK, IDENTITY) | Surrogate key |
| `company_id` | `VARCHAR(20)` (UNIQUE) | Natural business key, e.g. `AAPL-US` |
| `ticker_symbol` | `VARCHAR(12)` | Exchange ticker |
| `industry_key` | `INT` (FK → `dim_industry`) | GICS sector assignment |
| `country_key` | `INT` (FK → `dim_country`) | Domicile country |
| `is_current` | `BIT` | SCD2 flag — 1 = current version of this company |
| `scd_start_date` / `scd_end_date` | `DATE` | Validity window for this version |

> ⚠️ See [Bug #1](BUG_FIXES.md#bug-1) — `industry_key`/`country_key` require a post-seed
> `UPDATE` backfill; they are nullable FKs that the original seed `INSERT` left unset.

### `dw.fact_income_statement`
Grain: one row per company per fiscal year (annual only in this dataset).

| Column | Type | Description |
|---|---|---|
| `total_revenue` | `DECIMAL(20,4)` | Total revenue, USD millions |
| `gross_profit` | `DECIMAL` (computed) | `= total_revenue - cost_of_revenue` |
| `operating_income` | `DECIMAL(20,4)` | EBIT |
| `depreciation_amortization` | `DECIMAL(20,4)` | D&A — used to derive EBITDA elsewhere |
| `net_income` | `DECIMAL(20,4)` | Bottom-line net income |
| `eps_diluted` | `DECIMAL(12,6)` | Diluted earnings per share |

> 📝 `EBITDA` is **not** a stored column anywhere — it is always computed on-the-fly as
> `operating_income + depreciation_amortization`. See [Bug #6](BUG_FIXES.md#bug-6).

### `dw.fact_balance_sheet`
Grain: one row per company per period-end date.

| Column | Type | Description |
|---|---|---|
| `total_assets` | `DECIMAL(20,4)` | Total assets |
| `total_liabilities` | `DECIMAL(20,4)` | Total liabilities |
| `total_equity` | `DECIMAL(20,4)` | Total shareholders' equity |
| `net_debt` | `DECIMAL` (computed) | `= debt - cash - short_term_investments` |
| `working_capital` | `DECIMAL` (computed) | `= current_assets - current_liabilities` |

> ⚠️ Only seeded for AAPL and MSFT (10 rows). JPMorgan's balance sheet is structurally
> different as a bank and is intentionally excluded from this simplified dataset.

### `dw.fact_cash_flow`

| Column | Type | Description |
|---|---|---|
| `cash_from_operations` | `DECIMAL(20,4)` | Operating cash flow |
| `capital_expenditures` | `DECIMAL(20,4)` | CapEx (stored as a negative number) |
| `free_cash_flow` | `DECIMAL` (computed) | `= cash_from_operations + capital_expenditures` |

### `dw.fact_stock_price`
Grain: one row per company per trading day (year-end snapshots in this dataset).

| Column | Type | Description |
|---|---|---|
| `close_price` | `DECIMAL(14,4)` | Closing price |
| `adj_close_price` | `DECIMAL(14,4)` | Split/dividend-adjusted close |
| `market_cap_m` | `DECIMAL(20,4)` | Market capitalization, USD millions |

---

## Schema: `credit` — Basel III Credit Risk

### `credit.pd_master_scale`
Maps internal letter ratings to a through-the-cycle probability of default.

| `rating` | `pd_midpoint_pct` | `basel_class` |
|---|---|---|
| AAA | 0.0030% | INVESTMENT_GRADE |
| AA | 0.0250% | INVESTMENT_GRADE |
| A | 0.1000% | INVESTMENT_GRADE |
| BBB | 0.3500% | INVESTMENT_GRADE |
| BB | 1.8500% | SUB_INVESTMENT |
| B | 8.0000% | SUB_INVESTMENT |
| CCC | 22.000% | SUB_INVESTMENT |
| D | 100.00% | DEFAULT |

### `credit.loan_facilities`

| Column | Type | Description |
|---|---|---|
| `commitment_usd` | `DECIMAL(20,4)` | Total committed facility amount |
| `outstanding_balance` | `DECIMAL(20,4)` | Currently drawn balance |
| `undrawn_amount` | `DECIMAL` (computed) | `= commitment_usd - outstanding_balance` |
| `pd_pct` | `DECIMAL(10,6)` | Probability of default, % |
| `lgd_pct` | `DECIMAL(10,6)` | Loss given default, % |
| `expected_loss_usd` | `DECIMAL` (computed) | `= pd% × lgd% × (outstanding + 75% × undrawn)` |

> 💡 `commitment_usd` was originally named `commit` in early drafts — `COMMIT` is a T-SQL
> reserved keyword. See [Bug #8](BUG_FIXES.md#bug-8).

---

## Schema: `forensic` — Fraud Detection

### `forensic.transactions`

| Column | Type | Description |
|---|---|---|
| `amount` | `DECIMAL(20,4)` | Transaction amount |
| `created_by` / `approved_by` | `VARCHAR(80)` | Maker/checker control fields |
| `is_system_generated` | `BIT` | Excludes automated postings from fraud scoring |

### Fraud Scoring Logic (`forensic.v_expense_anomalies`)

The composite **fraud score (0–100)** is the sum of 8 weighted indicators:

| Indicator | Points | Logic |
|---|---|---|
| Round-dollar amount | 10 | `amount` is a whole number |
| Just below $5,000 threshold | 20 | `amount` between 4,900–5,000 |
| Just below $10,000 threshold | 15 | `amount` between 9,900–10,000 |
| Just below $25,000 threshold | 15 | `amount` between 24,900–25,000 |
| Weekend posting | 15 | Transaction dated Sat/Sun |
| Period-end posting | 10 | Posted in the final days of a quarter |
| **Self-approval** | **30** | `created_by = approved_by` |
| Missing approval (>$5,000) | 25 | `approved_by IS NULL` on a material transaction |

Score thresholds: **≥60 CRITICAL · ≥40 HIGH · ≥20 MEDIUM · <20 LOW**

---

## Schema: `esg` — Environmental, Social, Governance

### `esg.v_esg_scores`

Composite score weighting: **Environmental 40% · Social 30% · Governance 30%**

| Letter Rating | Composite Score Range |
|---|---|
| AAA | ≥ 85 |
| AA | 70 – 84.9 |
| A | 55 – 69.9 |
| BBB | 40 – 54.9 |
| BB | 25 – 39.9 |
| B | < 25 |

---

## Schema: `governance` — Data Quality & Lineage

### `governance.dq_rules`

10 automated rules, executed via `governance.usp_run_dq_checks`:

| Rule | Category | Severity |
|---|---|---|
| `IS_Revenue_Not_Null` | Completeness | CRITICAL |
| `IS_No_Negative_Revenue` | Accuracy | HIGH |
| `BS_Balance_Sheet_Equation` | Consistency | CRITICAL |
| `SP_No_Zero_Price` | Accuracy | CRITICAL |
| `SP_No_Future_Dates` | Timeliness | HIGH |
| `COMP_Unique_Active_Ticker` | Uniqueness | CRITICAL |
| `CR_PD_In_Range` | Accuracy | HIGH |
| `CR_LGD_In_Range` | Accuracy | HIGH |
| `ESG_Renewable_Pct_Range` | Accuracy | MEDIUM |
| `FPA_Actuals_No_Future` | Timeliness | MEDIUM |

> ⚠️ See [Bug #2](BUG_FIXES.md#bug-2) — the original `rule_sql` text used a bare
> `SELECT COUNT(*)` which is incompatible with the `sp_executesql ... OUTPUT` calling
> convention. Fixed to `SELECT @cnt = COUNT(*) ...`.
