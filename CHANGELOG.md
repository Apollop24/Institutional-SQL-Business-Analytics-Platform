# Changelog

All notable changes to this project are documented here.

## [2.0.1] — Final QA Pass

### Fixed
- **`dim_company.industry_key` / `country_key` never populated** — added idempotent backfill
  `UPDATE` after the seed `INSERT`, fixing 7 dependent views that silently returned 0 rows
  with no error (`v_financial_ratios`, `v_executive_scorecard`, `v_esg_scores`,
  `v_ranking_engine`, `v_portfolio_performance`, `v_stock_return_analytics`,
  `v_enterprise_company_360`)
- **`governance.usp_run_dq_checks` reporting ERROR for all 10 rules** — rewrote every
  `rule_sql` string from a bare `SELECT COUNT(*)` to `SELECT @cnt = COUNT(*)` to match the
  `sp_executesql ... OUTPUT` calling convention
- Corrected inaccurate `PRINT` comments claiming "expect 15 rows" for views that correctly
  return 10 rows (JPMorgan has no balance sheet/cash flow data seeded in this dataset)

### Verified (carried over from earlier QA passes, confirmed still correct)
- `NULLS LAST` → replaced with `CASE WHEN ... IS NULL THEN 1 ELSE 0 END` ordering pattern
- Ambiguous `expected_loss_usd` column → resolved with explicit `rd.` alias prefix
- Invalid `income_tax_expense` reference in stress test procedure → removed
- Missing `ebitda` computed expression in interview query Q3 → added
  `ISNULL(operating_income,0) + ISNULL(depreciation_amortization,0)`
- `TOP` inside recursive CTE → hoisted lookup into a `DECLARE` variable before the CTE
- Reserved keyword `COMMIT` used as column alias → renamed to `commitment_usd`
- `DECIMAL` type mismatch in recursive amortisation CTE → explicit `CAST(... AS DECIMAL(18,4))`
  applied to every column in both anchor and recursive members

### Documented
- Balance Sheet equation: 1 genuine $29M variance in Apple's FY2020 10-K filing — confirmed
  as an immaterial real-world rounding difference, not a data-entry error; left unmodified
  and documented in [`docs/BUG_FIXES.md`](docs/BUG_FIXES.md)

## [2.0.0] — Full Six-Module Portfolio

- 13 schemas: `dw`, `mart`, `credit`, `forensic`, `fpa`, `treasury`, `market`, `esg`, `bi`,
  `governance`, `etl`, `audit`, `staging`
- 37 tables, 31 views, 11 stored procedures, 2 inline table-valued functions, 1 trigger
- Real SEC 10-K data for Apple, Microsoft, and JPMorgan Chase (FY2019–FY2023)
- Basel III credit risk engine (PD/LGD/EAD/Expected Loss, IFRS 9 staging)
- Fraud detection module (duplicate payment detection, 8-indicator expense scoring)
- ESG composite scoring across Environmental/Social/Governance dimensions
- CFO-ready BI dashboards with KPI traffic-light status
- Data governance capstone: dynamic DQ rule engine, business glossary, RBAC matrix,
  column-level data lineage, enterprise 360° view

## [1.0.0] — Initial Core Warehouse

- Star-schema data warehouse (`dw` schema) with SCD Type 2 company dimension
- Financial ratio analytics (`mart.v_financial_ratios`)
- Initial credit risk tables
