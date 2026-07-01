# 🎯 Interview Guide

> Talking points, anticipated questions, and concise answers for presenting this project
> in a technical interview — for a Data Analyst, BI Developer, or Financial Data Engineer role.

---

## 30-Second Pitch

> "I built a SQL Server database that models the analytical infrastructure of an investment
> bank — a star-schema data warehouse fed with real SEC 10-K data, a Basel III credit risk
> engine computing PD/LGD/EAD/Expected Loss, a fraud detection module that scores transactions
> across 8 weighted red flags, ESG scoring, and a governance layer with an automated data
> quality rule engine. It's 5,500+ lines of T-SQL across 13 schemas, 37 tables, and 31 views,
> and I debugged 10 real SQL Server errors during deployment — which I documented rather than
> hid, because that's the more honest and more useful story."

---

## Anticipated Questions

### "Walk me through the architecture."

The database follows a **star schema**: `dw.dim_date`, `dw.dim_company`, `dw.dim_industry`,
and `dw.dim_country` are dimension tables; `fact_income_statement`, `fact_balance_sheet`,
`fact_cash_flow`, and `fact_stock_price` are fact tables joined to those dimensions on
surrogate integer keys. On top of that core, 9 subject-area schemas (`credit`, `forensic`,
`fpa`, `treasury`, `market`, `esg`, `bi`, `governance`, `etl`) each own their own tables and
views, all ultimately joining back to `dw` for company/date context. A single capstone view,
`governance.v_enterprise_company_360`, unions every module into one row per company per year.

### "What's a Slowly Changing Dimension, and where did you use one?"

`dw.dim_company` implements **SCD Type 2**: instead of overwriting a company's attributes
when they change, a new row is inserted with `scd_start_date` set to today, the old row's
`scd_end_date` is closed out, and only the row with `is_current = 1` is considered "current."
This preserves full historical accuracy for point-in-time reporting — for example, if a
company changes its reporting currency, analysts running a report against last year's data
still see last year's correct currency, not today's.

### "Explain how you calculate Expected Loss for credit risk."

Basel III defines Expected Loss as:

```
EL = PD × LGD × EAD
```

I implemented this as a **stored computed column** directly on `credit.loan_facilities`:

```sql
expected_loss_usd AS (
    ISNULL(pd_pct,0)/100.0 * ISNULL(lgd_pct,0)/100.0 *
    (outstanding_balance + 0.75 * (commitment_usd - outstanding_balance))
)
```

The `0.75` is a simplified Credit Conversion Factor applied to the undrawn portion of a
revolving facility — regulators assume 75% of an undrawn revolver will be drawn down before
a default occurs, so it's included in Exposure at Default (EAD) even though it isn't
currently outstanding.

### "How does your fraud detection scoring work?"

`forensic.v_expense_anomalies` assigns a 0–100 composite score per transaction across 8
weighted indicators — round-dollar amounts, amounts clustered just under common approval
thresholds ($5K/$10K/$25K), weekend or period-end postings, and critically, **self-approval**
(`created_by = approved_by`, worth 30 points — the single heaviest weight, since that's a
direct segregation-of-duties control failure). In my seeded test data, this genuinely caught
three invoices from one vendor split into $4,990/$4,985/$4,995 chunks over three consecutive
days — each individually under the $5,000 threshold, exactly the kind of structuring a real
internal audit team looks for.

### "Tell me about a bug you found and how you debugged it."

The most interesting one: seven of my views returned **zero rows with no error message at
all** — the hardest kind of bug because nothing fails loudly. I traced it back to
`dim_company.industry_key` and `country_key` — both nullable foreign keys — being declared
in the table but never populated by the original seed `INSERT`. Every analytical view used an
`INNER JOIN` to the industry and country dimensions (correctly, since every real company has
both), but because the FK columns were `NULL`, the inner join silently dropped every single
row. I fixed it with an idempotent `UPDATE ... CROSS APPLY (VALUES ...)` backfill mapping
each ticker to its correct GICS sector and country code, and made sure to document *why* the
original design was nearly right — it was a missing data-population step, not a flawed join.

### "Why document bugs instead of just fixing them quietly?"

Because a portfolio showing only clean, error-free runs doesn't actually demonstrate
debugging skill — it just demonstrates that I can copy working code. Walking through *why*
`Msg 461` happens (TOP inside a recursive CTE) or *why* `sp_executesql` needs
`SELECT @cnt = COUNT(*)` instead of a bare `SELECT COUNT(*)` shows I understand SQL Server's
actual execution model, not just pattern-matching syntax.

### "What would you do differently at production scale?"

Three things: (1) the `dim_date` population uses a `WHILE` loop, which is fine for ~7,700
rows but I'd switch to a set-based `GENERATE_SERIES`-style numbers-table approach for larger
ranges; (2) the fraud scoring and DQ rules currently run as on-demand views/procedures — at
scale I'd materialize them into indexed tables refreshed on a schedule via SQL Agent; (3) the
credit risk PD/LGD values are static seed data here — in production they'd come from a
model-scoring pipeline feeding the table on a nightly cadence, tracked through the
`etl.pipeline_jobs` / `etl.pipeline_run_log` framework that's already in the schema.

---

## Key Numbers to Have Ready

| Metric | Value |
|---|---|
| Total lines of T-SQL | ~5,558 |
| Schemas | 13 |
| Tables | 37 |
| Views | 31 |
| Stored procedures | 11 |
| Real bugs found & documented | 10 |
| Companies modeled | 10 (AAPL, MSFT, GOOGL, AMZN, JPM, HSBA, EQTY, SCOM, BRK.B, VOD) |
| Data sources | SEC EDGAR, Yahoo Finance, FRED, World Bank, company ESG reports |

---

## If Asked to Live-Code

Good lightweight extensions to demonstrate live, using the existing schema:

```sql
-- Add a new ratio to the financial ratios view: Quick Ratio trend
SELECT ticker_symbol, fiscal_year, current_ratio,
       LAG(current_ratio) OVER (PARTITION BY ticker_symbol ORDER BY fiscal_year) AS prior_yr
FROM mart.v_financial_ratios;

-- Find companies whose ROE declined two years running (a real self-join pattern from Q4)
WITH m AS (SELECT company_key, fiscal_year, roe_pct FROM mart.v_financial_ratios)
SELECT a.company_key, a.fiscal_year, a.roe_pct, b.roe_pct AS next_yr_roe
FROM m a JOIN m b ON a.company_key=b.company_key AND b.fiscal_year=a.fiscal_year+1
WHERE b.roe_pct < a.roe_pct;
```
