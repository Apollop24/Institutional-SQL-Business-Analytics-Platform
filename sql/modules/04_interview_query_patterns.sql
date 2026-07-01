-- ============================================================
-- SQL PORTFOLIO – PART 4: INTERVIEW QUERIES + PERFORMANCE
--                          BENCHMARKS + COMPLETE README
-- Engine : SQL Server 2017+ Express / SSMS
-- Run    : After Parts 1, 2 and 3
-- ============================================================

USE FinancePortfolio;
GO

-- ============================================================
-- MODULE 11 – INTERVIEW-READY QUERY SHOWCASE
-- Every pattern tested in senior financial data interviews
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- PATTERN 1: COMPLEX MULTI-TABLE JOIN
-- "Show me the 5-year financial summary for every company
--  with sector and country context in one query"
-- ─────────────────────────────────────────────────────────────
PRINT '=== INTERVIEW Q1: Multi-table JOIN with all dimensions ===';
SELECT
    c.ticker_symbol,
    c.company_name,
    i.gics_sector_name,
    i.gics_industry_name,
    co.country_name,
    co.currency_code,
    is_.fiscal_year,
    ROUND(is_.total_revenue  / 1e6, 2)  AS revenue_usd_m,
    ROUND(is_.net_income     / 1e6, 2)  AS net_income_usd_m,
    ROUND(is_.eps_diluted, 4)            AS eps_diluted,
    ROUND(bs.total_assets    / 1e6, 2)  AS total_assets_usd_m,
    ROUND(bs.total_equity    / 1e6, 2)  AS total_equity_usd_m,
    ROUND(cf.free_cash_flow  / 1e6, 2)  AS fcf_usd_m,
    ROUND(bs.net_debt        / 1e6, 2)  AS net_debt_usd_m
FROM dw.dim_company          c
JOIN dw.dim_industry         i   ON c.industry_key = i.industry_key
JOIN dw.dim_country          co  ON c.country_key  = co.country_key
JOIN dw.fact_income_statement is_ ON c.company_key = is_.company_key
                                  AND is_.period_type = 'ANNUAL'
JOIN dw.fact_balance_sheet   bs  ON c.company_key = bs.company_key
                                  AND bs.period_type  = 'ANNUAL'
                                  AND bs.fiscal_year  = is_.fiscal_year
JOIN dw.fact_cash_flow       cf  ON c.company_key = cf.company_key
                                  AND cf.period_type  = 'ANNUAL'
                                  AND cf.fiscal_year  = is_.fiscal_year
WHERE c.is_current = 1
ORDER BY c.ticker_symbol, is_.fiscal_year;
GO

-- ─────────────────────────────────────────────────────────────
-- PATTERN 2: CTE CHAIN (4-Level)
-- "Calculate ROIC using multi-step logic"
-- ─────────────────────────────────────────────────────────────
PRINT '=== INTERVIEW Q2: 4-level CTE chain for ROIC ===';
WITH step1_nopat AS (
    -- Step 1: Net Operating Profit After Tax
    SELECT
        c.ticker_symbol, is_.fiscal_year,
        is_.operating_income,
        is_.income_tax_expense,
        is_.total_revenue,
        bs.total_equity, bs.long_term_debt, bs.short_term_debt,
        -- NOPAT = Operating Income × (1 – Effective Tax Rate)
        ROUND(is_.operating_income
              * (1.0 - ABS(CAST(ISNULL(is_.income_tax_expense,0) AS FLOAT))
                 / NULLIF(is_.operating_income, 0)), 2)          AS nopat
    FROM dw.dim_company c
    JOIN dw.fact_income_statement is_ ON c.company_key=is_.company_key AND is_.period_type='ANNUAL'
    JOIN dw.fact_balance_sheet    bs  ON c.company_key=bs.company_key  AND bs.period_type='ANNUAL'
                                     AND bs.fiscal_year=is_.fiscal_year
    WHERE c.is_current=1
),
step2_invested_capital AS (
    -- Step 2: Invested Capital = Equity + Net Debt
    SELECT *,
        ROUND(total_equity + ISNULL(long_term_debt,0) + ISNULL(short_term_debt,0), 2) AS invested_capital
    FROM step1_nopat
),
step3_roic AS (
    -- Step 3: ROIC = NOPAT / Invested Capital
    SELECT *,
        ROUND(CAST(nopat AS FLOAT) / NULLIF(invested_capital, 0) * 100, 2) AS roic_pct
    FROM step2_invested_capital
),
step4_vs_wacc AS (
    -- Step 4: Assume 8% WACC benchmark (typical for tech)
    SELECT *,
        8.0 AS wacc_pct_assumed,
        ROUND(roic_pct - 8.0, 2) AS economic_spread_pct,  -- >0 = value creation
        CASE WHEN roic_pct > 8.0 THEN 'VALUE CREATING'
             WHEN roic_pct > 0   THEN 'VALUE NEUTRAL'
             ELSE 'VALUE DESTROYING' END AS value_creation_status
    FROM step3_roic
)
SELECT ticker_symbol, fiscal_year,
       ROUND(total_revenue/1e6,2) AS revenue_m,
       ROUND(nopat/1e6,2) AS nopat_m,
       ROUND(invested_capital/1e6,2) AS invested_capital_m,
       roic_pct, wacc_pct_assumed, economic_spread_pct, value_creation_status
FROM step4_vs_wacc
ORDER BY ticker_symbol, fiscal_year;
GO

-- ─────────────────────────────────────────────────────────────
-- PATTERN 3: WINDOW FUNCTION MASTERCLASS
-- "Show revenue trend with MoM, YoY, rolling avg, rank,
--  percentile and gap-to-leader in one query"
-- ─────────────────────────────────────────────────────────────
PRINT '=== INTERVIEW Q3: Window function masterclass ===';
WITH revenue_series AS (
    SELECT
        c.ticker_symbol,
        c.company_name,
        i.gics_sector_name,
        is_.fiscal_year,
        is_.total_revenue,
        is_.net_income,
        ISNULL(is_.operating_income,0) + ISNULL(is_.depreciation_amortization,0) AS ebitda
    FROM dw.dim_company c
    JOIN dw.fact_income_statement is_
        ON c.company_key=is_.company_key AND is_.period_type='ANNUAL'
    JOIN dw.dim_industry i ON c.industry_key=i.industry_key
    WHERE c.is_current=1
)
SELECT
    ticker_symbol, company_name, gics_sector_name, fiscal_year,
    ROUND(total_revenue/1e6,2)                                     AS revenue_m,
    -- YoY Growth
    ROUND(
        (CAST(total_revenue AS FLOAT)
         - LAG(total_revenue) OVER (PARTITION BY ticker_symbol ORDER BY fiscal_year))
        / NULLIF(ABS(LAG(total_revenue) OVER (PARTITION BY ticker_symbol ORDER BY fiscal_year)),0)*100,
    1)                                                              AS yoy_growth_pct,
    -- 3-Year CAGR
    ROUND(
        (POWER(
            CAST(total_revenue AS FLOAT)
            / NULLIF(LAG(total_revenue,3) OVER (PARTITION BY ticker_symbol ORDER BY fiscal_year),0),
        1.0/3.0)-1.0)*100,
    1)                                                              AS cagr_3yr_pct,
    -- Rolling 3-year average revenue
    ROUND(
        AVG(CAST(total_revenue AS FLOAT))
        OVER (PARTITION BY ticker_symbol ORDER BY fiscal_year
              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) /1e6,
    2)                                                              AS rolling_3yr_avg_m,
    -- Rank within sector by revenue
    RANK() OVER (PARTITION BY gics_sector_name, fiscal_year
                 ORDER BY total_revenue DESC)                        AS sector_revenue_rank,
    -- Percentile in sector
    ROUND(PERCENT_RANK() OVER (PARTITION BY gics_sector_name, fiscal_year
                               ORDER BY total_revenue)*100, 0)      AS revenue_percentile,
    -- Gap to sector leader
    ROUND(
        (MAX(CAST(total_revenue AS FLOAT)) OVER (PARTITION BY gics_sector_name, fiscal_year)
         - CAST(total_revenue AS FLOAT)) / 1e6,
    2)                                                              AS gap_to_leader_m,
    -- Revenue share of sector
    ROUND(
        CAST(total_revenue AS FLOAT)
        / NULLIF(SUM(CAST(total_revenue AS FLOAT)) OVER (PARTITION BY gics_sector_name, fiscal_year),0)*100,
    1)                                                              AS sector_share_pct,
    -- Cumulative revenue since first year
    ROUND(
        SUM(CAST(total_revenue AS FLOAT))
        OVER (PARTITION BY ticker_symbol ORDER BY fiscal_year
              ROWS UNBOUNDED PRECEDING) /1e6,
    2)                                                              AS cumulative_revenue_m
FROM revenue_series
ORDER BY ticker_symbol, fiscal_year;
GO

-- ─────────────────────────────────────────────────────────────
-- PATTERN 4: SELF-JOIN – Consecutive Year Comparison
-- "Find companies that IMPROVED margins 3 years straight"
-- ─────────────────────────────────────────────────────────────
PRINT '=== INTERVIEW Q4: Self-join – consistent margin improvers ===';
WITH margins AS (
    SELECT company_key, fiscal_year,
           ROUND(CAST(net_income AS FLOAT)/NULLIF(total_revenue,0)*100,2) AS net_margin
    FROM dw.fact_income_statement
    WHERE period_type='ANNUAL'
)
SELECT
    c.ticker_symbol, c.company_name,
    m1.fiscal_year  AS y1, m2.fiscal_year AS y2, m3.fiscal_year AS y3,
    m1.net_margin   AS margin_y1,
    m2.net_margin   AS margin_y2,
    m3.net_margin   AS margin_y3,
    ROUND(m2.net_margin - m1.net_margin, 2) AS delta_y1_y2,
    ROUND(m3.net_margin - m2.net_margin, 2) AS delta_y2_y3
FROM margins m1
-- Self-join: consecutive years
JOIN margins m2 ON m1.company_key=m2.company_key AND m2.fiscal_year=m1.fiscal_year+1
JOIN margins m3 ON m1.company_key=m3.company_key AND m3.fiscal_year=m1.fiscal_year+2
JOIN dw.dim_company c ON m1.company_key=c.company_key AND c.is_current=1
-- Filter: margin improved each year
WHERE m2.net_margin > m1.net_margin
  AND m3.net_margin > m2.net_margin
ORDER BY delta_y2_y3 DESC;
GO

-- ─────────────────────────────────────────────────────────────
-- PATTERN 5: CROSS JOIN – Full Valuation Scenario Matrix
-- "Apply 5 discount rate assumptions to all companies"
-- ─────────────────────────────────────────────────────────────
PRINT '=== INTERVIEW Q5: CROSS JOIN – DCF sensitivity matrix ===';
WITH latest_fcf AS (
    SELECT DISTINCT
        c.ticker_symbol, c.company_name,
        cf.free_cash_flow,
        FIRST_VALUE(cf.free_cash_flow) OVER (
            PARTITION BY c.company_key ORDER BY cf.fiscal_year DESC
            ROWS UNBOUNDED PRECEDING
        ) AS latest_fcf_usd
    FROM dw.dim_company c
    JOIN dw.fact_cash_flow cf ON c.company_key=cf.company_key AND cf.period_type='ANNUAL'
    WHERE c.is_current=1 AND cf.free_cash_flow > 0
),
discount_rates AS (
    SELECT *
    FROM (VALUES
        ('Low Risk',    0.07, 0.03),
        ('Base Case',   0.09, 0.03),
        ('High Risk',   0.11, 0.03),
        ('Bear Case',   0.13, 0.02),
        ('Stress Case', 0.15, 0.01)
    ) dr(scenario, wacc, terminal_growth)
)
SELECT
    lf.ticker_symbol,
    lf.company_name,
    dr.scenario,
    ROUND(dr.wacc*100,0)            AS wacc_pct,
    ROUND(dr.terminal_growth*100,0) AS terminal_growth_pct,
    ROUND(lf.latest_fcf_usd/1e6,2) AS latest_fcf_m,
    -- Simplified Gordon Growth Model terminal value
    -- TV = FCF × (1+g) / (WACC - g)
    ROUND(
        lf.latest_fcf_usd * (1+dr.terminal_growth)
        / NULLIF(dr.wacc - dr.terminal_growth, 0) / 1e9,
    2)                              AS implied_terminal_value_bn,
    -- Implied EV = TV / (1+WACC)^5  (simplified 5-yr horizon)
    ROUND(
        (lf.latest_fcf_usd*(1+dr.terminal_growth)/NULLIF(dr.wacc-dr.terminal_growth,0))
        / POWER(1.0+dr.wacc, 5.0) / 1e9,
    2)                              AS implied_ev_bn
FROM (
    SELECT DISTINCT ticker_symbol, company_name,
           MAX(latest_fcf_usd) AS latest_fcf_usd
    FROM latest_fcf GROUP BY ticker_symbol, company_name
) lf
CROSS JOIN discount_rates dr
ORDER BY lf.ticker_symbol, dr.wacc;
GO

-- ─────────────────────────────────────────────────────────────
-- PATTERN 6: RECURSIVE CTE – Compound Annual Growth
-- "Show $10,000 invested in AAPL growing year-over-year"
-- ─────────────────────────────────────────────────────────────
PRINT '=== INTERVIEW Q6: Recursive CTE – compound investment growth ===';
DECLARE @aapl_key INT = (SELECT TOP 1 company_key FROM dw.dim_company WHERE ticker_symbol='AAPL' AND is_current=1);

WITH RECURSIVE_GROWTH (fiscal_year, revenue, growth_rate, portfolio_value, iteration) AS (
    -- Anchor: first year
    SELECT
        fiscal_year,
        total_revenue,
        CAST(0.0 AS FLOAT)      AS growth_rate,
        CAST(10000.0 AS FLOAT)  AS portfolio_value,
        CAST(1 AS INT)          AS iteration
    FROM dw.fact_income_statement
    WHERE company_key = @aapl_key
      AND period_type = 'ANNUAL'
      AND fiscal_year = (SELECT MIN(fiscal_year) FROM dw.fact_income_statement WHERE period_type='ANNUAL')

    UNION ALL

    -- Recursive: apply each year's revenue growth as proxy return
    SELECT
        n.fiscal_year,
        n.total_revenue,
        CAST(
            (CAST(n.total_revenue AS FLOAT) - CAST(p.revenue AS FLOAT))
            / NULLIF(ABS(CAST(p.revenue AS FLOAT)),0)
        AS FLOAT)               AS growth_rate,
        CAST(
            p.portfolio_value *
            (1.0 + (CAST(n.total_revenue AS FLOAT) - CAST(p.revenue AS FLOAT))
                   / NULLIF(ABS(CAST(p.revenue AS FLOAT)),0))
        AS FLOAT)               AS portfolio_value,
        CAST(p.iteration + 1 AS INT)
    FROM dw.fact_income_statement n
    JOIN RECURSIVE_GROWTH p ON n.fiscal_year = p.fiscal_year + 1
    WHERE n.company_key = @aapl_key
      AND n.period_type = 'ANNUAL'
      AND p.iteration   < 10
)
SELECT
    fiscal_year,
    ROUND(CAST(revenue AS FLOAT)/1e6,2)      AS revenue_m,
    ROUND(growth_rate*100,2)                  AS revenue_growth_pct,
    ROUND(portfolio_value,2)                  AS portfolio_value_usd,
    ROUND((portfolio_value-10000)/10000*100,1) AS total_return_pct
FROM RECURSIVE_GROWTH
ORDER BY fiscal_year
OPTION (MAXRECURSION 20);
GO

-- ─────────────────────────────────────────────────────────────
-- PATTERN 7: PIVOTING WITH CROSS APPLY (T-SQL idiom)
-- "Show each company's financials in wide format"
-- ─────────────────────────────────────────────────────────────
PRINT '=== INTERVIEW Q7: CROSS APPLY unpivot then re-pivot ===';
WITH unpivoted AS (
    SELECT
        c.ticker_symbol,
        is_.fiscal_year,
        metrics.metric_name,
        metrics.metric_value
    FROM dw.fact_income_statement is_
    JOIN dw.dim_company c ON is_.company_key=c.company_key AND c.is_current=1
    CROSS APPLY (VALUES
        ('Revenue_M',        ROUND(CAST(is_.total_revenue AS FLOAT)/1e6,2)),
        ('GrossProfit_M',    ROUND(CAST(ISNULL(is_.gross_profit,0) AS FLOAT)/1e6,2)),
        ('EBIT_M',           ROUND(CAST(ISNULL(is_.operating_income,0) AS FLOAT)/1e6,2)),
        ('NetIncome_M',      ROUND(CAST(ISNULL(is_.net_income,0) AS FLOAT)/1e6,2)),
        ('EPS_Diluted',      ROUND(CAST(ISNULL(is_.eps_diluted,0) AS FLOAT),4))
    ) metrics(metric_name, metric_value)
    WHERE is_.period_type='ANNUAL'
)
SELECT
    ticker_symbol, metric_name,
    MAX(CASE WHEN fiscal_year=2019 THEN metric_value END) AS [FY2019],
    MAX(CASE WHEN fiscal_year=2020 THEN metric_value END) AS [FY2020],
    MAX(CASE WHEN fiscal_year=2021 THEN metric_value END) AS [FY2021],
    MAX(CASE WHEN fiscal_year=2022 THEN metric_value END) AS [FY2022],
    MAX(CASE WHEN fiscal_year=2023 THEN metric_value END) AS [FY2023]
FROM unpivoted
GROUP BY ticker_symbol, metric_name
ORDER BY ticker_symbol,
    CASE metric_name
        WHEN 'Revenue_M'     THEN 1
        WHEN 'GrossProfit_M' THEN 2
        WHEN 'EBIT_M'        THEN 3
        WHEN 'NetIncome_M'   THEN 4
        WHEN 'EPS_Diluted'   THEN 5
    END;
GO

-- ─────────────────────────────────────────────────────────────
-- PATTERN 8: LATERAL CROSS APPLY – Top-N per group
-- "Top 2 years by net income for each company"
-- ─────────────────────────────────────────────────────────────
PRINT '=== INTERVIEW Q8: CROSS APPLY TOP-N per group ===';
SELECT
    c.ticker_symbol,
    c.company_name,
    t.fiscal_year,
    ROUND(t.net_income/1e6,2)       AS net_income_m,
    ROUND(t.total_revenue/1e6,2)    AS revenue_m,
    ROUND(t.net_income/NULLIF(CAST(t.total_revenue AS FLOAT),0)*100,1) AS net_margin_pct,
    t.rank_within_company
FROM dw.dim_company c
CROSS APPLY (
    SELECT TOP 2
        is_.fiscal_year, is_.net_income, is_.total_revenue,
        ROW_NUMBER() OVER (ORDER BY is_.net_income DESC) AS rank_within_company
    FROM dw.fact_income_statement is_
    WHERE is_.company_key=c.company_key AND is_.period_type='ANNUAL'
    ORDER BY is_.net_income DESC
) t
WHERE c.is_current=1
ORDER BY c.ticker_symbol, t.rank_within_company;
GO

-- ─────────────────────────────────────────────────────────────
-- PATTERN 9: DATA QUALITY + VALIDATION PATTERN
-- "Detect outliers using IQR method"
-- ─────────────────────────────────────────────────────────────
PRINT '=== INTERVIEW Q9: Outlier detection using IQR ===';
WITH quartiles AS (
    SELECT
        gics_sector_name,
        fiscal_year,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY CAST(net_margin_pct AS FLOAT))
            OVER (PARTITION BY gics_sector_name, fiscal_year) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY CAST(net_margin_pct AS FLOAT))
            OVER (PARTITION BY gics_sector_name, fiscal_year) AS q3,
        company_key, ticker_symbol, net_margin_pct
    FROM mart.v_financial_ratios
)
SELECT
    ticker_symbol, gics_sector_name, fiscal_year,
    net_margin_pct,
    ROUND(CAST(q1 AS FLOAT),2)  AS q1_net_margin,
    ROUND(CAST(q3 AS FLOAT),2)  AS q3_net_margin,
    ROUND(CAST(q3-q1 AS FLOAT),2) AS iqr,
    -- Outlier bounds: Q1-1.5×IQR and Q3+1.5×IQR
    ROUND(CAST(q1 AS FLOAT) - 1.5*CAST(q3-q1 AS FLOAT),2) AS lower_fence,
    ROUND(CAST(q3 AS FLOAT) + 1.5*CAST(q3-q1 AS FLOAT),2) AS upper_fence,
    CASE
        WHEN CAST(net_margin_pct AS FLOAT) < CAST(q1 AS FLOAT) - 1.5*CAST(q3-q1 AS FLOAT)
          OR CAST(net_margin_pct AS FLOAT) > CAST(q3 AS FLOAT) + 1.5*CAST(q3-q1 AS FLOAT)
        THEN 'OUTLIER'
        ELSE 'NORMAL'
    END AS outlier_flag
FROM quartiles
ORDER BY ticker_symbol, fiscal_year;
GO

-- ─────────────────────────────────────────────────────────────
-- PATTERN 10: CREDIT RISK – EXPECTED LOSS ROLL-FORWARD
-- "Show EL change between periods"
-- ─────────────────────────────────────────────────────────────
PRINT '=== INTERVIEW Q10: Credit EL roll-forward analysis ===';
SELECT
    b.internal_rating,
    b.borrower_type,
    COUNT(*)                                             AS facility_count,
    -- Portfolio totals
    ROUND(SUM(lf.commitment_usd)/1e6,2)                 AS total_commitment_m,
    ROUND(SUM(lf.outstanding_balance)/1e6,2)            AS total_outstanding_m,
    ROUND(SUM(lf.undrawn_amount)/1e6,2)                 AS total_undrawn_m,
    -- EAD weighted metrics
    ROUND(AVG(lf.pd_pct),4)                             AS wtd_avg_pd_pct,
    ROUND(AVG(lf.lgd_pct),2)                            AS wtd_avg_lgd_pct,
    -- Expected Loss components
    ROUND(SUM(
        ISNULL(lf.pd_pct,0)/100.0 *
        ISNULL(lf.lgd_pct,0)/100.0 *
        (lf.outstanding_balance + 0.75*(lf.commitment_usd-lf.outstanding_balance))
    )/1e6,4)                                            AS total_expected_loss_m,
    -- EL as % of outstanding
    ROUND(SUM(
        ISNULL(lf.pd_pct,0)/100.0 *
        ISNULL(lf.lgd_pct,0)/100.0 *
        (lf.outstanding_balance + 0.75*(lf.commitment_usd-lf.outstanding_balance))
    )/NULLIF(SUM(lf.outstanding_balance),0)*100,4)      AS el_rate_pct,
    -- Stage breakdown
    SUM(CASE WHEN lf.facility_status='DEFAULT' THEN 1 ELSE 0 END)          AS stage3_count,
    SUM(CASE WHEN lf.days_past_due BETWEEN 30 AND 89 THEN 1 ELSE 0 END)    AS stage2_count,
    SUM(CASE WHEN lf.days_past_due=0 AND lf.facility_status='CURRENT' THEN 1 ELSE 0 END) AS stage1_count,
    -- Highest risk facility
    MAX(lf.pd_pct)                                      AS max_pd_pct,
    MIN(lf.pd_pct)                                      AS min_pd_pct
FROM credit.loan_facilities lf
JOIN credit.borrowers b ON lf.borrower_key=b.borrower_key
GROUP BY ROLLUP(b.internal_rating, b.borrower_type)
ORDER BY b.internal_rating, b.borrower_type;
GO

-- ============================================================
-- MODULE 12 – PERFORMANCE BENCHMARKS
-- Demonstrate query optimisation awareness
-- ============================================================
PRINT '=== PERFORMANCE: Execution Statistics ===';

-- Enable statistics for benchmarking
SET STATISTICS TIME ON;
SET STATISTICS IO  ON;

-- Benchmark 1: Financial ratios with full join chain
PRINT '-- Benchmark 1: Financial Ratios View';
SELECT COUNT(*) AS ratio_rows FROM mart.v_financial_ratios;

-- Benchmark 2: Credit risk dashboard
PRINT '-- Benchmark 2: Credit Risk Dashboard';
SELECT COUNT(*) AS credit_rows FROM credit.v_risk_dashboard;

-- Benchmark 3: Compound self-join
PRINT '-- Benchmark 3: Self-join 3-year growers';
SELECT COUNT(*) AS growers FROM bi.v_consistent_growers;

SET STATISTICS TIME OFF;
SET STATISTICS IO  OFF;
GO

-- ── Execution Plan Hints (documented patterns) ────────────────
PRINT '=== OPTIMISATION PATTERNS USED IN THIS PORTFOLIO ===';
SELECT *
FROM (VALUES
('1','Covering Indexes','idx_fis_company_year covers (company_key, fiscal_year, period_type) – eliminates key lookups on fact_income_statement'),
('2','Computed Columns','gross_profit AS (total_revenue - cost_of_revenue) stored in table – avoids runtime calculation'),
('3','ISNULL guards','ISNULL(col,0) prevents NULL propagation in window frame arithmetic'),
('4','Inline OVER()','T-SQL requires inline OVER() clauses – named WINDOW alias not supported unlike PostgreSQL'),
('5','CROSS APPLY','Used instead of correlated subquery for TOP-N per group – better cardinality estimates'),
('6','OPTION MAXRECURSION','All recursive CTEs use OPTION(MAXRECURSION 500) to prevent infinite loops'),
('7','CAST to FLOAT','Arithmetic on DECIMAL columns cast to FLOAT before division to avoid truncation'),
('8','Partition pruning','Fact tables filtered on period_type=''ANNUAL'' first to reduce rows before joining'),
('9','Sargable predicates','All WHERE clauses use direct column comparisons – no functions on indexed columns'),
('10','Statistics update','Run UPDATE STATISTICS after bulk loads for accurate query plans')
) opt(opt_num, technique, explanation)
ORDER BY opt_num;
GO

-- ============================================================
-- FINAL DATABASE SUMMARY
-- ============================================================
PRINT '';
PRINT '==============================================';
PRINT ' FINANCEPORTFOLIO – COMPLETE OBJECT INVENTORY';
PRINT '==============================================';

SELECT
    s.name                        AS schema_name,
    o.type_desc                   AS object_type,
    o.name                        AS object_name,
    CONVERT(VARCHAR(10),o.create_date,23) AS created_date
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id=s.schema_id
WHERE o.type IN ('U','V','P','IF','TF','TR')
  AND s.name NOT IN ('sys','INFORMATION_SCHEMA','guest',
                     'db_owner','db_accessadmin','db_securityadmin',
                     'db_ddladmin','db_backupoperator','db_datareader',
                     'db_datawriter','db_denydatareader','db_denydatawriter')
ORDER BY s.name, o.type_desc, o.name;
GO

-- Row counts per table
PRINT '';
PRINT '=== ROW COUNTS PER TABLE ===';
SELECT
    s.name + '.' + t.name  AS full_table_name,
    SUM(p.rows)             AS row_count
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id=s.schema_id
JOIN sys.partitions p ON t.object_id=p.object_id AND p.index_id IN (0,1)
WHERE s.name NOT IN ('sys','INFORMATION_SCHEMA')
GROUP BY s.name, t.name
HAVING SUM(p.rows) > 0
ORDER BY SUM(p.rows) DESC;
GO

PRINT '';
PRINT '==============================================';
PRINT ' SQL PORTFOLIO FULLY DEPLOYED - ALL 4 PARTS';
PRINT '==============================================';
PRINT '';
PRINT 'Run order in SSMS:';
PRINT '  1. COMPLETE_PORTFOLIO_SQLSERVER.sql   (Core DW + Credit + Views)';
PRINT '  2. PORTFOLIO_ANALYTICS_PART2.sql      (FP&A + Treasury + ESG + BI)';
PRINT '  3. PORTFOLIO_PART3_FINAL.sql          (Fraud + Advanced SQL)';
PRINT '  4. PORTFOLIO_PART4_INTERVIEW_README.sql (Interview Queries + Benchmarks)';
PRINT '';
PRINT 'Key objects created:';
PRINT '  Schemas:    13 (dw, mart, credit, forensic, fpa, treasury,';
PRINT '                  market, esg, bi, governance, etl, audit, staging)';
PRINT '  Tables:     30+ across all schemas';
PRINT '  Views:      25+ analytical views';
PRINT '  Procedures: 12+ stored procedures';
PRINT '  Functions:   3 inline table-valued functions';
PRINT '  Triggers:    1 audit trigger';
PRINT '  Indexes:     6 composite covering indexes';
PRINT '';
PRINT 'SQL Skills Demonstrated:';
PRINT '  Window Functions  : RANK, DENSE_RANK, ROW_NUMBER, NTILE,';
PRINT '                      PERCENT_RANK, CUME_DIST, LAG, LEAD,';
PRINT '                      FIRST_VALUE, LAST_VALUE, SUM OVER,';
PRINT '                      AVG OVER, STDEV OVER, ROWS/RANGE frames';
PRINT '  Joins             : INNER, LEFT, CROSS, CROSS APPLY, Self-join';
PRINT '  CTEs              : Simple, Chained (4-level), Recursive';
PRINT '  Dynamic SQL       : sp_executesql, PIVOT generation';
PRINT '  Computed Columns  : AS (expression) – stored and virtual';
PRINT '  Stored Procedures : SCD2, Amortisation, Stress Test, Pivot';
PRINT '  Functions         : Inline TVF, Scalar via procedures';
PRINT '  Triggers          : AFTER INSERT/UPDATE/DELETE audit logging';
PRINT '  Indexes           : Composite, covering, on FK columns';
PRINT '  Data Modelling    : Star Schema, SCD Type 2, Fact/Dim tables';
PRINT '  Financial Math    : ROIC, NOPAT, PD/LGD/EAD, Amortisation PMT';
PRINT '  Credit Risk       : Basel III EL, IFRS 9 staging, PD scale';
PRINT '  Fraud Detection   : Benford Law proxy, duplicate analysis, scoring';
PRINT '  ESG Analytics     : E/S/G scoring, carbon intensity, sector rank';
PRINT '';
GO

