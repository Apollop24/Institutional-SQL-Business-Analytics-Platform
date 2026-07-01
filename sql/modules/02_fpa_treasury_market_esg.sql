-- ============================================================
-- SQL PORTFOLIO – PART 2: ADVANCED ANALYTICS MODULES
-- Projects 7-12: FP&A, Treasury, Market Data, ESG,
--                CFO BI Dashboard, Advanced SQL Techniques
-- Engine : SQL Server 2017+ Express / SSMS
-- Run    : After COMPLETE_PORTFOLIO_SQLSERVER.sql
-- ============================================================

USE FinancePortfolio;
GO

-- ============================================================
-- MODULE 1 – FP&A: SAMPLE BUDGET + ACTUALS DATA
-- Enables v_variance_analysis and forecast accuracy views
-- ============================================================

-- Insert sample budget for AAPL FY2023
IF NOT EXISTS (SELECT 1 FROM fpa.budgets WHERE fiscal_year = 2023)
BEGIN
    INSERT INTO fpa.budgets
        (company_key, cost_center_key, account_code, fiscal_year,
         budget_version,
         budget_jan, budget_feb, budget_mar, budget_apr, budget_may, budget_jun,
         budget_jul, budget_aug, budget_sep, budget_oct, budget_nov, budget_dec,
         approved_by)
    SELECT
        c.company_key,
        cc.cost_center_key,
        v.acct,
        2023, 'ORIGINAL',
        v.b1,v.b2,v.b3,v.b4,v.b5,v.b6,
        v.b7,v.b8,v.b9,v.b10,v.b11,v.b12,
        'CFO Office'
    FROM (VALUES
    -- Revenue budget (monthly ~1/12 of annual $383B)
    ('4000', CAST(29500 AS DECIMAL(18,4)),CAST(28000 AS DECIMAL(18,4)),CAST(33000 AS DECIMAL(18,4)),CAST(30000 AS DECIMAL(18,4)),CAST(31000 AS DECIMAL(18,4)),CAST(32000 AS DECIMAL(18,4)),CAST(34000 AS DECIMAL(18,4)),CAST(33500 AS DECIMAL(18,4)),CAST(36000 AS DECIMAL(18,4)),CAST(32500 AS DECIMAL(18,4)),CAST(35000 AS DECIMAL(18,4)),CAST(37000 AS DECIMAL(18,4))),
    -- R&D budget
    ('6010', CAST(2400 AS DECIMAL(18,4)),CAST(2400 AS DECIMAL(18,4)),CAST(2450 AS DECIMAL(18,4)),CAST(2450 AS DECIMAL(18,4)),CAST(2500 AS DECIMAL(18,4)),CAST(2500 AS DECIMAL(18,4)),CAST(2500 AS DECIMAL(18,4)),CAST(2550 AS DECIMAL(18,4)),CAST(2550 AS DECIMAL(18,4)),CAST(2600 AS DECIMAL(18,4)),CAST(2600 AS DECIMAL(18,4)),CAST(2600 AS DECIMAL(18,4))),
    -- SG&A budget
    ('6020', CAST(1980 AS DECIMAL(18,4)),CAST(1980 AS DECIMAL(18,4)),CAST(2050 AS DECIMAL(18,4)),CAST(2050 AS DECIMAL(18,4)),CAST(2080 AS DECIMAL(18,4)),CAST(2080 AS DECIMAL(18,4)),CAST(2100 AS DECIMAL(18,4)),CAST(2100 AS DECIMAL(18,4)),CAST(2120 AS DECIMAL(18,4)),CAST(2120 AS DECIMAL(18,4)),CAST(2150 AS DECIMAL(18,4)),CAST(2150 AS DECIMAL(18,4)))
    ) v(acct,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12)
    CROSS JOIN (SELECT TOP 1 company_key FROM dw.dim_company WHERE ticker_symbol='AAPL' AND is_current=1) c
    CROSS JOIN (SELECT TOP 1 cost_center_key FROM fpa.dim_cost_center WHERE cost_center_code='CC-001') cc;
    PRINT '✓ FP&A budget data seeded (FY2023 AAPL).';
END
GO

-- Insert sample actuals for AAPL FY2023 (monthly)
IF NOT EXISTS (SELECT 1 FROM fpa.actuals WHERE fiscal_year = 2023)
BEGIN
    INSERT INTO fpa.actuals
        (company_key, cost_center_key, account_code, fiscal_year, fiscal_month, actual_amount)
    SELECT
        c.company_key,
        cc.cost_center_key,
        v.acct,
        2023, v.mon, v.amt
    FROM (VALUES
    -- Revenue actuals (slightly above/below budget to show BVA)
    ('4000',1, CAST(28700 AS DECIMAL(20,4))),('4000',2,CAST(27500 AS DECIMAL(20,4))),
    ('4000',3, CAST(34200 AS DECIMAL(20,4))),('4000',4,CAST(31100 AS DECIMAL(20,4))),
    ('4000',5, CAST(30800 AS DECIMAL(20,4))),('4000',6,CAST(33400 AS DECIMAL(20,4))),
    ('4000',7, CAST(35100 AS DECIMAL(20,4))),('4000',8,CAST(32900 AS DECIMAL(20,4))),
    ('4000',9, CAST(34700 AS DECIMAL(20,4))),('4000',10,CAST(33200 AS DECIMAL(20,4))),
    ('4000',11,CAST(34600 AS DECIMAL(20,4))),('4000',12,CAST(37085 AS DECIMAL(20,4))),
    -- R&D actuals
    ('6010',1, CAST(2380 AS DECIMAL(20,4))),('6010',2,CAST(2410 AS DECIMAL(20,4))),
    ('6010',3, CAST(2460 AS DECIMAL(20,4))),('6010',4,CAST(2480 AS DECIMAL(20,4))),
    ('6010',5, CAST(2510 AS DECIMAL(20,4))),('6010',6,CAST(2530 AS DECIMAL(20,4))),
    ('6010',7, CAST(2490 AS DECIMAL(20,4))),('6010',8,CAST(2570 AS DECIMAL(20,4))),
    ('6010',9, CAST(2560 AS DECIMAL(20,4))),('6010',10,CAST(2610 AS DECIMAL(20,4))),
    ('6010',11,CAST(2590 AS DECIMAL(20,4))),('6010',12,CAST(2625 AS DECIMAL(20,4))),
    -- SG&A actuals
    ('6020',1, CAST(1950 AS DECIMAL(20,4))),('6020',2,CAST(1970 AS DECIMAL(20,4))),
    ('6020',3, CAST(2080 AS DECIMAL(20,4))),('6020',4,CAST(2060 AS DECIMAL(20,4))),
    ('6020',5, CAST(2090 AS DECIMAL(20,4))),('6020',6,CAST(2110 AS DECIMAL(20,4))),
    ('6020',7, CAST(2130 AS DECIMAL(20,4))),('6020',8,CAST(2090 AS DECIMAL(20,4))),
    ('6020',9, CAST(2140 AS DECIMAL(20,4))),('6020',10,CAST(2150 AS DECIMAL(20,4))),
    ('6020',11,CAST(2180 AS DECIMAL(20,4))),('6020',12,CAST(2152 AS DECIMAL(20,4)))
    ) v(acct, mon, amt)
    CROSS JOIN (SELECT TOP 1 company_key FROM dw.dim_company WHERE ticker_symbol='AAPL' AND is_current=1) c
    CROSS JOIN (SELECT TOP 1 cost_center_key FROM fpa.dim_cost_center WHERE cost_center_code='CC-001') cc;
    PRINT '✓ FP&A actuals data seeded (FY2023 AAPL, 36 rows).';
END
GO

-- ── FP&A: Monthly P&L KPI View ────────────────────────────────
IF OBJECT_ID('fpa.v_monthly_pnl','V') IS NOT NULL DROP VIEW fpa.v_monthly_pnl;
GO
CREATE VIEW fpa.v_monthly_pnl AS
SELECT
    a.company_key,
    c.ticker_symbol,
    cc.cost_center_name,
    a.fiscal_year,
    a.fiscal_month,
    -- Revenue vs Budget
    SUM(CASE WHEN ac.account_type='REVENUE' THEN a.actual_amount ELSE 0 END) AS actual_revenue,
    SUM(CASE WHEN ac.account_type='REVENUE' THEN ISNULL(b.budget_amount,0) ELSE 0 END) AS budget_revenue,
    -- OpEx vs Budget
    SUM(CASE WHEN ac.account_type='EXPENSE' THEN a.actual_amount ELSE 0 END) AS actual_opex,
    SUM(CASE WHEN ac.account_type='EXPENSE' THEN ISNULL(b.budget_amount,0) ELSE 0 END) AS budget_opex,
    -- Derived
    SUM(CASE WHEN ac.account_type='REVENUE' THEN a.actual_amount ELSE 0 END)
    - SUM(CASE WHEN ac.account_type='EXPENSE' THEN a.actual_amount ELSE 0 END) AS actual_ebit,
    -- YoY Revenue via LAG window function
    LAG(SUM(CASE WHEN ac.account_type='REVENUE' THEN a.actual_amount ELSE 0 END),12)
        OVER (PARTITION BY a.company_key, a.cost_center_key
              ORDER BY a.fiscal_year, a.fiscal_month) AS prior_yr_revenue,
    -- YTD cumulative revenue
    SUM(SUM(CASE WHEN ac.account_type='REVENUE' THEN a.actual_amount ELSE 0 END))
        OVER (PARTITION BY a.company_key, a.cost_center_key, a.fiscal_year
              ORDER BY a.fiscal_month ROWS UNBOUNDED PRECEDING) AS ytd_revenue,
    -- Budget variance
    SUM(CASE WHEN ac.account_type='REVENUE' THEN a.actual_amount - ISNULL(b.budget_amount,0) ELSE 0 END) AS revenue_bva
FROM fpa.actuals a
JOIN dw.dim_company      c  ON a.company_key     = c.company_key
JOIN fpa.dim_cost_center cc ON a.cost_center_key = cc.cost_center_key
JOIN dw.dim_account      ac ON a.account_code    = ac.account_code
LEFT JOIN (
    SELECT company_key, cost_center_key, account_code, fiscal_year, mon, budget_amount
    FROM fpa.budgets
    CROSS APPLY (VALUES
        (1,budget_jan),(2,budget_feb),(3,budget_mar),(4,budget_apr),
        (5,budget_may),(6,budget_jun),(7,budget_jul),(8,budget_aug),
        (9,budget_sep),(10,budget_oct),(11,budget_nov),(12,budget_dec)
    ) m(mon, budget_amount)
    WHERE budget_version='ORIGINAL'
) b ON a.company_key=b.company_key AND a.cost_center_key=b.cost_center_key
    AND a.account_code=b.account_code AND a.fiscal_year=b.fiscal_year
    AND a.fiscal_month=b.mon
GROUP BY a.company_key, c.ticker_symbol, cc.cost_center_name,
         a.fiscal_year, a.fiscal_month, a.cost_center_key;
GO
PRINT '✓ fpa.v_monthly_pnl created.';
GO

-- ── FP&A: Forecast Accuracy KPI View ─────────────────────────
IF OBJECT_ID('fpa.v_forecast_accuracy','V') IS NOT NULL DROP VIEW fpa.v_forecast_accuracy;
GO
CREATE VIEW fpa.v_forecast_accuracy AS
SELECT
    v.company_key,
    v.fiscal_year,
    v.fiscal_month,
    v.actual_revenue,
    v.budget_revenue,
    v.ytd_revenue, 
    v.revenue_bva,
    ROUND(CAST(v.revenue_bva AS FLOAT)/NULLIF(v.budget_revenue,0)*100,1)  AS bva_pct,
    -- Absolute Percentage Error for MAPE
    ROUND(ABS(CAST(v.revenue_bva AS FLOAT)/NULLIF(v.budget_revenue,0))*100,1) AS ape_pct,
    -- Favorability
    CASE WHEN v.revenue_bva >= 0 THEN 'FAVORABLE' ELSE 'UNFAVORABLE' END  AS budget_flag,
    -- Rolling 3-month average APE
    AVG(ABS(CAST(v.revenue_bva AS FLOAT)/NULLIF(v.budget_revenue,0))*100)
        OVER (PARTITION BY v.company_key ORDER BY v.fiscal_year, v.fiscal_month
              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)                    AS rolling_3m_mape,
    -- YTD BVA cumulative
    SUM(v.revenue_bva)
        OVER (PARTITION BY v.company_key, v.fiscal_year
              ORDER BY v.fiscal_month -- <--- ADDED REQUIRED ORDER BY
              ROWS UNBOUNDED PRECEDING)                                    AS ytd_bva
FROM fpa.v_monthly_pnl v;
GO
PRINT '✓ fpa.v_forecast_accuracy created.';
GO
-- ============================================================
-- MODULE 2 – TREASURY ANALYTICS
-- ============================================================
IF OBJECT_ID('treasury.bank_accounts','U') IS NULL
BEGIN
    CREATE TABLE treasury.bank_accounts (
        account_key      INT           IDENTITY(1,1) PRIMARY KEY,
        account_id       VARCHAR(30)   NOT NULL UNIQUE,
        company_key      INT           REFERENCES dw.dim_company(company_key),
        bank_name        NVARCHAR(100) NOT NULL,
        bank_country     CHAR(3),
        account_type     VARCHAR(30)   NOT NULL,
        currency         CHAR(3)       NOT NULL DEFAULT 'USD',
        account_number   VARCHAR(40),
        iban             VARCHAR(34),
        swift_bic        VARCHAR(11),
        credit_limit     DECIMAL(20,4) DEFAULT 0,
        interest_rate_pct DECIMAL(8,4),
        is_active        BIT           DEFAULT 1,
        created_at       DATETIME2     DEFAULT GETDATE()
    );
    INSERT INTO treasury.bank_accounts
        (account_id, company_key, bank_name, bank_country, account_type, currency, account_number, swift_bic)
    SELECT v.aid, c.company_key, v.bank, v.ctry, v.atype, v.ccy, v.acct, v.swift
    FROM (VALUES
    ('ACC-001-USD','AAPL-US','JPMorgan Chase','USA','OPERATING','USD','***4521','CHASUS33'),
    ('ACC-002-EUR','AAPL-US','Deutsche Bank', 'DEU','OPERATING','EUR','***8832','DEUTDEFF'),
    ('ACC-003-GBP','AAPL-US','HSBC',          'GBR','CONCENTRATION','GBP','***1193','MIDLGB22'),
    ('ACC-004-KES','EQTY-KE','Equity Bank',   'KEN','OPERATING','KES','***7761','EQBLKENA'),
    ('ACC-005-USD','MSFT-US','Bank of America','USA','OPERATING','USD','***3309','BOFAUS3N')
    ) v(aid, coid, bank, ctry, atype, ccy, acct, swift)
    JOIN dw.dim_company c ON c.company_id = v.coid AND c.is_current = 1;
    PRINT '✓ treasury.bank_accounts created and seeded (5 rows).';
END
GO

IF OBJECT_ID('treasury.cash_positions','U') IS NULL
BEGIN
    CREATE TABLE treasury.cash_positions (
        position_key         BIGINT        IDENTITY(1,1) PRIMARY KEY,
        account_key          INT           NOT NULL REFERENCES treasury.bank_accounts(account_key),
        date_key             INT           NOT NULL REFERENCES dw.dim_date(date_key),
        opening_balance      DECIMAL(20,4) NOT NULL,
        total_receipts       DECIMAL(20,4) DEFAULT 0,
        total_payments       DECIMAL(20,4) DEFAULT 0,
        closing_balance      DECIMAL(20,4) NOT NULL,
        available_balance    DECIMAL(20,4),
        fx_rate_to_usd       DECIMAL(12,6) DEFAULT 1.0,
        closing_balance_usd  AS (closing_balance * fx_rate_to_usd),
        is_confirmed         BIT           DEFAULT 0,
        data_source          VARCHAR(30)   DEFAULT 'BANK_STATEMENT',
        created_at           DATETIME2     DEFAULT GETDATE(),
        CONSTRAINT UQ_cash_pos UNIQUE (account_key, date_key)
    );
    PRINT '✓ treasury.cash_positions created.';
END
GO

IF OBJECT_ID('treasury.debt_facilities','U') IS NULL
BEGIN
    CREATE TABLE treasury.debt_facilities (
        debt_key              BIGINT        IDENTITY(1,1) PRIMARY KEY,
        facility_id           VARCHAR(30)   NOT NULL UNIQUE,
        company_key           INT           REFERENCES dw.dim_company(company_key),
        facility_name         NVARCHAR(150),
        debt_type             VARCHAR(40)   NOT NULL,
        lender                NVARCHAR(150),
        currency              CHAR(3)       DEFAULT 'USD',
        total_facility_usd    DECIMAL(20,4) NOT NULL,
        drawn_amount_usd      DECIMAL(20,4) DEFAULT 0,
        undrawn_usd           AS (total_facility_usd - drawn_amount_usd),
        interest_rate_pct     DECIMAL(8,4),
        rate_type             VARCHAR(10)   DEFAULT 'FLOATING',
        reference_rate        VARCHAR(20),
        spread_bps            DECIMAL(8,2),
        maturity_date         DATE,
        origination_date      DATE,
        covenant_leverage     DECIMAL(8,2),
        covenant_status       VARCHAR(20)   DEFAULT 'COMPLIANT',
        is_active             BIT           DEFAULT 1,
        created_at            DATETIME2     DEFAULT GETDATE()
    );
    INSERT INTO treasury.debt_facilities
        (facility_id, company_key, facility_name, debt_type, lender,
         currency, total_facility_usd, drawn_amount_usd,
         interest_rate_pct, rate_type, reference_rate, spread_bps,
         maturity_date, origination_date, covenant_leverage, covenant_status)
    SELECT v.fid, c.company_key, v.fname, v.dtype, v.lender,
           v.ccy, v.total, v.drawn,
           v.rate, v.rtype, v.refrate, v.spread,
           CAST(v.mat AS DATE), CAST(v.orig AS DATE), v.cov_lev, v.cov_stat
    FROM (VALUES
    ('DEBT-001','AAPL-US','Apple 5Y Term Loan','TERM_LOAN','JPMorgan Chase','USD',10000000000,5000000000,4.75,'FLOATING','SOFR',50.0,'2028-03-15','2023-03-15',3.0,'COMPLIANT'),
    ('DEBT-002','AAPL-US','Apple Revolving Facility','REVOLVER','Goldman Sachs','USD',20000000000,0,4.50,'FLOATING','SOFR',37.5,'2026-06-30','2021-06-30',3.0,'COMPLIANT'),
    ('DEBT-003','MSFT-US','Microsoft Term Loan','TERM_LOAN','Citibank','USD',5000000000,5000000000,3.95,'FIXED','N/A',0.0,'2030-07-15','2020-07-15',2.5,'COMPLIANT'),
    ('DEBT-004','EQTY-KE','Equity Bank Bilateral','BILATERAL','IFC','USD',200000000,180000000,6.50,'FLOATING','LIBOR',150.0,'2027-12-01','2022-12-01',4.0,'COMPLIANT'),
    ('DEBT-005','AAPL-US','Apple Commercial Paper','CP','Money Markets','USD',3000000000,1500000000,5.25,'FLOATING','SOFR',20.0,'2024-06-30','2024-01-01',0.0,'COMPLIANT')
    ) v(fid,coid,fname,dtype,lender,ccy,total,drawn,rate,rtype,refrate,spread,mat,orig,cov_lev,cov_stat)
    JOIN dw.dim_company c ON c.company_id = v.coid AND c.is_current=1;
    PRINT '✓ treasury.debt_facilities created and seeded (5 rows).';
END
GO

-- ── Treasury: Liquidity Dashboard View ───────────────────────
IF OBJECT_ID('treasury.v_liquidity_dashboard','V') IS NOT NULL DROP VIEW treasury.v_liquidity_dashboard;
GO
CREATE VIEW treasury.v_liquidity_dashboard AS
WITH debt_summary AS (
    SELECT
        company_key,
        SUM(drawn_amount_usd)                                                     AS total_debt_drawn,
        SUM(total_facility_usd)                                                   AS total_facilities,
        SUM(undrawn_usd)                                                          AS total_undrawn,
        SUM(CASE WHEN DATEDIFF(DAY, GETDATE(), maturity_date) <= 365
                 THEN drawn_amount_usd ELSE 0 END)                                AS st_debt,
        SUM(CASE WHEN DATEDIFF(DAY, GETDATE(), maturity_date) > 365
                 THEN drawn_amount_usd ELSE 0 END)                                AS lt_debt,
        MIN(maturity_date)                                                        AS nearest_maturity,
        SUM(CASE WHEN covenant_status <> 'COMPLIANT' THEN 1 ELSE 0 END)          AS covenant_breaches
    FROM treasury.debt_facilities WHERE is_active = 1
    GROUP BY company_key
)
SELECT
    c.ticker_symbol,
    c.company_name,
    ds.total_debt_drawn   / 1e9                                                  AS total_debt_bn,
    ds.total_facilities   / 1e9                                                  AS total_facilities_bn,
    ds.total_undrawn      / 1e9                                                  AS total_undrawn_bn,
    ds.st_debt            / 1e9                                                  AS st_debt_bn,
    ds.lt_debt            / 1e9                                                  AS lt_debt_bn,
    ds.nearest_maturity,
    ds.covenant_breaches,
    -- Cash from balance sheet (most recent annual)
    bs.cash_equivalents   / 1e6                                                  AS cash_m,
    (bs.cash_equivalents + ISNULL(bs.short_term_investments,0)) / 1e6           AS liquid_assets_m,
    -- Net debt (from computed column)
    bs.net_debt           / 1e6                                                  AS net_debt_m,
    -- Liquidity headroom = cash + undrawn revolvers
    (bs.cash_equivalents + ISNULL(bs.short_term_investments,0)
     + ds.total_undrawn) / 1e9                                                   AS liquidity_headroom_bn,
    -- Net debt / EBITDA leverage ratio
    ROUND(CAST(bs.net_debt AS FLOAT)
          / NULLIF(is_.operating_income + ISNULL(is_.depreciation_amortization,0),0), 2) AS net_debt_ebitda,
    -- Cash-to-ST-Debt ratio
    ROUND(CAST(bs.cash_equivalents AS FLOAT) / NULLIF(ds.st_debt,0), 2)         AS cash_to_st_debt,
    -- Status
    CASE
        WHEN ds.covenant_breaches > 0                                            THEN 'COVENANT BREACH'
        WHEN CAST(bs.cash_equivalents AS FLOAT)/NULLIF(ds.st_debt,0) < 0.5      THEN 'CRITICAL'
        WHEN CAST(bs.cash_equivalents AS FLOAT)/NULLIF(ds.st_debt,0) < 1.0      THEN 'TIGHT'
        ELSE 'ADEQUATE'
    END AS liquidity_status
FROM dw.dim_company c
JOIN debt_summary ds ON c.company_key = ds.company_key
JOIN (
    SELECT company_key, cash_equivalents, short_term_investments, net_debt, fiscal_year
    FROM dw.fact_balance_sheet
    WHERE period_type='ANNUAL'
) bs ON c.company_key = bs.company_key
JOIN (
    SELECT company_key, operating_income, depreciation_amortization, fiscal_year
    FROM dw.fact_income_statement WHERE period_type='ANNUAL'
) is_ ON c.company_key = is_.company_key AND is_.fiscal_year = bs.fiscal_year
WHERE c.is_current = 1
  AND bs.fiscal_year = (
      SELECT MAX(fiscal_year) FROM dw.fact_balance_sheet b2
      WHERE b2.company_key = c.company_key AND b2.period_type='ANNUAL'
  );
GO
PRINT '✓ treasury.v_liquidity_dashboard created.';
GO

-- ── Treasury: Working Capital Analytics View ──────────────────
IF OBJECT_ID('treasury.v_working_capital','V') IS NOT NULL DROP VIEW treasury.v_working_capital;
GO
CREATE VIEW treasury.v_working_capital AS
SELECT
    c.ticker_symbol, c.company_name,
    bs.fiscal_year,
    ROUND(bs.accounts_receivable_net/1e6,2)     AS receivables_m,
    ROUND(ISNULL(bs.inventories,0)/1e6,2)        AS inventory_m,
    ROUND(bs.accounts_payable/1e6,2)             AS payables_m,
    ROUND(bs.cash_equivalents/1e6,2)             AS cash_m,
    ROUND(bs.working_capital/1e6,2)              AS net_working_capital_m,
    -- Cash Conversion Cycle components
    ROUND(bs.accounts_receivable_net/NULLIF(CAST(is_.total_revenue AS FLOAT),0)*365,1)  AS dso,
    ROUND(ISNULL(bs.inventories,0)/NULLIF(CAST(is_.cost_of_revenue AS FLOAT),0)*365,1)  AS dio,
    ROUND(bs.accounts_payable/NULLIF(CAST(is_.cost_of_revenue AS FLOAT),0)*365,1)       AS dpo,
    -- Cash Conversion Cycle = DSO + DIO - DPO
    ROUND(
        bs.accounts_receivable_net/NULLIF(CAST(is_.total_revenue AS FLOAT),0)*365
        + ISNULL(bs.inventories,0)/NULLIF(CAST(is_.cost_of_revenue AS FLOAT),0)*365
        - bs.accounts_payable/NULLIF(CAST(is_.cost_of_revenue AS FLOAT),0)*365,
    1)                                                                           AS cash_conversion_cycle,
    -- WC as % of revenue
    ROUND(CAST(bs.working_capital AS FLOAT)/NULLIF(is_.total_revenue,0)*100,1) AS wc_to_revenue_pct,
    -- YoY WC change
    LAG(ROUND(bs.working_capital/1e6,2)) OVER (
        PARTITION BY c.company_key ORDER BY bs.fiscal_year)                     AS prior_yr_wc_m,
    ROUND(bs.working_capital/1e6,2)
        - LAG(ROUND(bs.working_capital/1e6,2)) OVER (
            PARTITION BY c.company_key ORDER BY bs.fiscal_year)                 AS wc_change_yoy_m
FROM dw.dim_company c
JOIN dw.fact_balance_sheet bs ON c.company_key=bs.company_key AND bs.period_type='ANNUAL'
JOIN dw.fact_income_statement is_ ON c.company_key=is_.company_key
    AND is_.period_type='ANNUAL' AND is_.fiscal_year=bs.fiscal_year
WHERE c.is_current=1;
GO
PRINT '✓ treasury.v_working_capital created.';
GO

-- ============================================================
-- MODULE 3 – MARKET DATA ANALYTICS
-- Stock price technical indicators using Window Functions
-- ============================================================
IF OBJECT_ID('market.v_technical_indicators','V') IS NOT NULL DROP VIEW market.v_technical_indicators;
GO
CREATE VIEW market.v_technical_indicators AS
WITH price_base AS (
    SELECT
        sp.company_key, c.ticker_symbol, c.company_name,
        sp.date_key, dd.full_date, dd.year_number, dd.month_number,
        sp.open_price, sp.high_price, sp.low_price,
        sp.close_price, sp.adj_close_price, sp.volume,
        -- Daily return %
        ROUND(
            (CAST(sp.adj_close_price AS FLOAT)
             / NULLIF(LAG(CAST(sp.adj_close_price AS FLOAT))
                 OVER (PARTITION BY sp.company_key ORDER BY sp.date_key), 0) - 1) * 100,
        4) AS daily_return_pct,
        -- Raw price change
        sp.adj_close_price
            - LAG(sp.adj_close_price) OVER (PARTITION BY sp.company_key ORDER BY sp.date_key)
            AS price_change
    FROM dw.fact_stock_price sp
    JOIN dw.dim_company c ON sp.company_key = c.company_key AND c.is_current = 1
    JOIN dw.dim_date   dd ON sp.date_key    = dd.date_key
),
moving_avgs AS (
    SELECT *,
        -- Simple Moving Averages
        ROUND(AVG(CAST(adj_close_price AS FLOAT)) OVER (PARTITION BY company_key ORDER BY date_key ROWS BETWEEN 4   PRECEDING AND CURRENT ROW), 4) AS sma_5d,
        ROUND(AVG(CAST(adj_close_price AS FLOAT)) OVER (PARTITION BY company_key ORDER BY date_key ROWS BETWEEN 19  PRECEDING AND CURRENT ROW), 4) AS sma_20d,
        ROUND(AVG(CAST(adj_close_price AS FLOAT)) OVER (PARTITION BY company_key ORDER BY date_key ROWS BETWEEN 49  PRECEDING AND CURRENT ROW), 4) AS sma_50d,
        ROUND(AVG(CAST(adj_close_price AS FLOAT)) OVER (PARTITION BY company_key ORDER BY date_key ROWS BETWEEN 199 PRECEDING AND CURRENT ROW), 4) AS sma_200d,
        -- Bollinger Band base (20-day)
        AVG(CAST(adj_close_price AS FLOAT)) OVER (PARTITION BY company_key ORDER BY date_key ROWS BETWEEN 19 PRECEDING AND CURRENT ROW)  AS bb_mid,
        STDEV(CAST(adj_close_price AS FLOAT)) OVER (PARTITION BY company_key ORDER BY date_key ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS bb_std,
        -- Rolling 21-day annualised volatility
        ROUND(STDEV(CAST(daily_return_pct AS FLOAT)) OVER (PARTITION BY company_key ORDER BY date_key ROWS BETWEEN 20 PRECEDING AND CURRENT ROW) * SQRT(252), 4) AS vol_21d_ann,
        -- 52-week high/low
        MAX(CAST(adj_close_price AS FLOAT)) OVER (PARTITION BY company_key ORDER BY date_key ROWS BETWEEN 251 PRECEDING AND CURRENT ROW) AS high_52wk,
        MIN(CAST(adj_close_price AS FLOAT)) OVER (PARTITION BY company_key ORDER BY date_key ROWS BETWEEN 251 PRECEDING AND CURRENT ROW) AS low_52wk,
        -- Volume moving average 20d
        AVG(CAST(volume AS FLOAT)) OVER (PARTITION BY company_key ORDER BY date_key ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS vol_sma_20d,
        -- Momentum
        ROUND((CAST(adj_close_price AS FLOAT)/NULLIF(LAG(CAST(adj_close_price AS FLOAT),21)  OVER (PARTITION BY company_key ORDER BY date_key),0)-1)*100,2) AS momentum_1m_pct,
        ROUND((CAST(adj_close_price AS FLOAT)/NULLIF(LAG(CAST(adj_close_price AS FLOAT),63)  OVER (PARTITION BY company_key ORDER BY date_key),0)-1)*100,2) AS momentum_3m_pct,
        ROUND((CAST(adj_close_price AS FLOAT)/NULLIF(LAG(CAST(adj_close_price AS FLOAT),252) OVER (PARTITION BY company_key ORDER BY date_key),0)-1)*100,2) AS momentum_12m_pct,
        -- RSI components
        CASE WHEN price_change > 0 THEN price_change ELSE 0 END AS gain,
        CASE WHEN price_change < 0 THEN ABS(price_change) ELSE 0 END AS loss
    FROM price_base
),
rsi AS (
    SELECT *,
        AVG(CAST(gain AS FLOAT)) OVER (PARTITION BY company_key ORDER BY date_key ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS avg_gain_14d,
        AVG(CAST(loss AS FLOAT)) OVER (PARTITION BY company_key ORDER BY date_key ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS avg_loss_14d
    FROM moving_avgs
)
SELECT
    company_key, ticker_symbol, company_name,
    date_key, full_date, year_number, month_number,
    open_price, high_price, low_price, close_price, adj_close_price, volume,
    daily_return_pct, price_change,
    sma_5d, sma_20d, sma_50d, sma_200d,
    -- Bollinger Bands
    ROUND(bb_mid + 2.0 * ISNULL(bb_std,0), 4)  AS bb_upper,
    ROUND(bb_mid, 4)                             AS bb_middle,
    ROUND(bb_mid - 2.0 * ISNULL(bb_std,0), 4)  AS bb_lower,
    vol_21d_ann, high_52wk, low_52wk,
    -- % of 52-week range (0=at low, 100=at high)
    ROUND(
        (CAST(adj_close_price AS FLOAT) - low_52wk)
        / NULLIF(high_52wk - low_52wk, 0) * 100, 1
    )                                            AS pct_of_52wk_range,
    ROUND(CAST(volume AS FLOAT)/NULLIF(vol_sma_20d,0),2) AS volume_ratio,
    momentum_1m_pct, momentum_3m_pct, momentum_12m_pct,
    -- RSI 14-day
    ROUND(100.0 - (100.0 / (1.0 + NULLIF(avg_gain_14d/NULLIF(avg_loss_14d,0),0))),1) AS rsi_14d,
    -- RSI Signal
    CASE
        WHEN 100.0-(100.0/(1.0+NULLIF(avg_gain_14d/NULLIF(avg_loss_14d,0),0))) > 70 THEN 'OVERBOUGHT'
        WHEN 100.0-(100.0/(1.0+NULLIF(avg_gain_14d/NULLIF(avg_loss_14d,0),0))) < 30 THEN 'OVERSOLD'
        ELSE 'NEUTRAL'
    END                                          AS rsi_signal,
    -- Trend signal
    CASE
        WHEN adj_close_price > sma_20d AND sma_20d > sma_50d AND sma_50d > sma_200d THEN 'STRONG UPTREND'
        WHEN adj_close_price < sma_20d AND sma_20d < sma_50d AND sma_50d < sma_200d THEN 'STRONG DOWNTREND'
        WHEN adj_close_price > sma_50d THEN 'MODERATE UPTREND'
        WHEN adj_close_price < sma_50d THEN 'MODERATE DOWNTREND'
        ELSE 'SIDEWAYS'
    END                                          AS trend_signal,
    -- Bollinger Band signal
    CASE
        WHEN adj_close_price > bb_mid + 2.0*ISNULL(bb_std,0) THEN 'ABOVE UPPER BAND'
        WHEN adj_close_price < bb_mid - 2.0*ISNULL(bb_std,0) THEN 'BELOW LOWER BAND'
        ELSE 'WITHIN BANDS'
    END                                          AS bb_signal
FROM rsi;
GO
PRINT '✓ market.v_technical_indicators created.';
GO

-- ── Market: Pairwise Correlation Function ─────────────────────
IF OBJECT_ID('market.fn_correlation_matrix','IF') IS NOT NULL
    DROP FUNCTION market.fn_correlation_matrix;
GO
CREATE FUNCTION market.fn_correlation_matrix(@from_date DATE, @to_date DATE)
RETURNS TABLE AS RETURN
(
    WITH returns AS (
        SELECT c.ticker_symbol, sp.date_key,
            (CAST(sp.adj_close_price AS FLOAT)
             / NULLIF(LAG(CAST(sp.adj_close_price AS FLOAT))
                 OVER (PARTITION BY sp.company_key ORDER BY sp.date_key),0) - 1) AS daily_return
        FROM dw.fact_stock_price sp
        JOIN dw.dim_company c ON sp.company_key=c.company_key AND c.is_current=1
        JOIN dw.dim_date    d ON sp.date_key=d.date_key
        WHERE d.full_date BETWEEN @from_date AND @to_date
    )
    SELECT
        r1.ticker_symbol AS ticker_a,
        r2.ticker_symbol AS ticker_b,
        ROUND(CAST(
            (COUNT(*)*SUM(r1.daily_return*r2.daily_return)
             - SUM(r1.daily_return)*SUM(r2.daily_return))
            / NULLIF(
                SQRT(
                    (COUNT(*)*SUM(r1.daily_return*r1.daily_return)-POWER(SUM(r1.daily_return),2))*
                    (COUNT(*)*SUM(r2.daily_return*r2.daily_return)-POWER(SUM(r2.daily_return),2))
                ),0) AS FLOAT),4) AS pearson_correlation,
        COUNT(*) AS obs_count
    FROM returns r1
    JOIN returns r2 ON r1.date_key=r2.date_key AND r1.ticker_symbol < r2.ticker_symbol
    WHERE r1.daily_return IS NOT NULL AND r2.daily_return IS NOT NULL
    GROUP BY r1.ticker_symbol, r2.ticker_symbol
    HAVING COUNT(*) >= 20
);
GO
PRINT '✓ market.fn_correlation_matrix created.';
GO

-- ── Market: Recursive Compound Growth Function ────────────────
-- Demonstrates RECURSIVE CTE in SQL Server (OPTION MAXRECURSION)
IF OBJECT_ID('market.usp_compound_growth','P') IS NOT NULL
    DROP PROCEDURE market.usp_compound_growth;
GO
CREATE PROCEDURE market.usp_compound_growth
    @ticker       VARCHAR(12),
    @start_date   DATE,
    @end_date     DATE,
    @initial_inv  DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    WITH daily AS (
        SELECT
            dd.full_date AS trade_date,
            sp.adj_close_price,
            ROUND(
                (CAST(sp.adj_close_price AS FLOAT)
                 / NULLIF(LAG(CAST(sp.adj_close_price AS FLOAT))
                     OVER (PARTITION BY sp.company_key ORDER BY sp.date_key),0) - 1)*100,
            4) AS daily_return_pct,
            ROW_NUMBER() OVER (PARTITION BY sp.company_key ORDER BY sp.date_key) AS rn
        FROM dw.fact_stock_price sp
        JOIN dw.dim_company c ON sp.company_key=c.company_key AND c.ticker_symbol=@ticker AND c.is_current=1
        JOIN dw.dim_date   dd ON sp.date_key=dd.date_key
        WHERE dd.full_date BETWEEN @start_date AND @end_date
    ),
    compounding (trade_date, adj_close_price, daily_return_pct, portfolio_value, rn) AS (
        -- Base case
        SELECT trade_date, adj_close_price,
               CAST(0.0 AS FLOAT), CAST(@initial_inv AS FLOAT), rn
        FROM daily WHERE rn=1

        UNION ALL

        -- Recursive: compound each day
        SELECT d.trade_date, d.adj_close_price,
               CAST(d.daily_return_pct AS FLOAT),
               CAST(c.portfolio_value * (1.0 + ISNULL(d.daily_return_pct,0)/100.0) AS FLOAT),
               d.rn
        FROM daily d
        JOIN compounding c ON d.rn = c.rn + 1
    )
    SELECT
        trade_date,
        adj_close_price,
        ROUND(daily_return_pct,4) AS daily_return_pct,
        ROUND(portfolio_value,2)  AS portfolio_value_usd,
        ROUND((portfolio_value/CAST(@initial_inv AS FLOAT)-1)*100,2) AS cumulative_return_pct
    FROM compounding
    OPTION (MAXRECURSION 500);
END;
GO
PRINT '✓ market.usp_compound_growth created (recursive CTE demo).';
GO

-- ============================================================
-- MODULE 4 – ESG ANALYTICS
-- ============================================================
IF OBJECT_ID('esg.esg_metrics','U') IS NULL
BEGIN
    CREATE TABLE esg.esg_metrics (
        esg_key                 BIGINT       IDENTITY(1,1) PRIMARY KEY,
        company_key             INT          NOT NULL REFERENCES dw.dim_company(company_key),
        report_year             SMALLINT     NOT NULL,
        data_source             VARCHAR(50)  DEFAULT 'COMPANY_REPORT',
        -- Environmental
        scope1_emissions_tco2e  DECIMAL(16,2),
        scope2_emissions_tco2e  DECIMAL(16,2),
        scope3_emissions_tco2e  DECIMAL(16,2),
        total_emissions_tco2e AS (
            ISNULL(scope1_emissions_tco2e,0)
            + ISNULL(scope2_emissions_tco2e,0)
            + ISNULL(scope3_emissions_tco2e,0)
        ),
        energy_consumption_gwh  DECIMAL(14,4),
        renewable_energy_pct    DECIMAL(8,4),
        water_usage_m3          DECIMAL(16,2),
        waste_recycled_pct      DECIMAL(8,4),
        -- Social
        total_employees         INT,
        female_employees_pct    DECIMAL(8,4),
        female_mgmt_pct         DECIMAL(8,4),
        employee_turnover_pct   DECIMAL(8,4),
        lost_time_injury_rate   DECIMAL(10,4),
        training_hours_per_emp  DECIMAL(10,2),
        -- Governance
        board_size              SMALLINT,
        independent_directors_pct DECIMAL(8,4),
        female_board_pct        DECIMAL(8,4),
        ceo_pay_ratio           DECIMAL(10,2),
        has_esg_committee       BIT,
        has_climate_targets     BIT,
        net_zero_target_year    SMALLINT,
        third_party_audit       BIT,
        -- External Ratings
        msci_esg_rating         VARCHAR(5),
        cdp_climate_score       VARCHAR(5),
        created_at              DATETIME2    DEFAULT GETDATE(),
        CONSTRAINT UQ_esg UNIQUE (company_key, report_year, data_source)
    );
    -- Seed ESG data (Apple, Microsoft, JPMorgan) from public sustainability reports
    INSERT INTO esg.esg_metrics
        (company_key, report_year, data_source,
         scope1_emissions_tco2e, scope2_emissions_tco2e, scope3_emissions_tco2e,
         energy_consumption_gwh, renewable_energy_pct, waste_recycled_pct,
         total_employees, female_employees_pct, female_mgmt_pct,
         employee_turnover_pct, training_hours_per_emp,
         board_size, independent_directors_pct, female_board_pct,
         ceo_pay_ratio, has_esg_committee, has_climate_targets,
         net_zero_target_year, third_party_audit, msci_esg_rating, cdp_climate_score)
    SELECT c.company_key, v.yr, 'COMPANY_REPORT',
           v.s1, v.s2, v.s3, v.energy, v.renew, v.recycle,
           v.empl, v.fem_empl, v.fem_mgmt,
           v.turnover, v.training,
           v.board_sz, v.indep_dir, v.fem_board,
           v.ceo_pay, v.esg_comm, v.clim_tgt,
           v.nz_yr, v.audit, v.msci, v.cdp
    FROM (VALUES
    ('AAPL',2023,CAST(55300 AS DECIMAL(16,2)),CAST(330 AS DECIMAL(16,2)),CAST(22050000 AS DECIMAL(16,2)),CAST(3.9 AS DECIMAL(14,4)),CAST(100.0 AS DECIMAL(8,4)),CAST(81.0 AS DECIMAL(8,4)),161000,CAST(35.0 AS DECIMAL(8,4)),CAST(32.0 AS DECIMAL(8,4)),CAST(12.0 AS DECIMAL(8,4)),CAST(67.0 AS DECIMAL(10,2)),CAST(8 AS SMALLINT),CAST(75.0 AS DECIMAL(8,4)),CAST(37.5 AS DECIMAL(8,4)),CAST(1447.0 AS DECIMAL(10,2)),CAST(1 AS BIT),CAST(1 AS BIT),CAST(2030 AS SMALLINT),CAST(1 AS BIT),'AA','A'),
    ('AAPL',2022,CAST(59100 AS DECIMAL(16,2)),CAST(400 AS DECIMAL(16,2)),CAST(22870000 AS DECIMAL(16,2)),CAST(3.7 AS DECIMAL(14,4)),CAST(100.0 AS DECIMAL(8,4)),CAST(75.0 AS DECIMAL(8,4)),164000,CAST(34.0 AS DECIMAL(8,4)),CAST(31.0 AS DECIMAL(8,4)),CAST(12.5 AS DECIMAL(8,4)),CAST(62.0 AS DECIMAL(10,2)),CAST(8 AS SMALLINT),CAST(75.0 AS DECIMAL(8,4)),CAST(37.5 AS DECIMAL(8,4)),CAST(1318.0 AS DECIMAL(10,2)),CAST(1 AS BIT),CAST(1 AS BIT),CAST(2030 AS SMALLINT),CAST(1 AS BIT),'AA','A'),
    ('MSFT',2023,CAST(13900 AS DECIMAL(16,2)),CAST(840 AS DECIMAL(16,2)),CAST(13500000 AS DECIMAL(16,2)),CAST(25.8 AS DECIMAL(14,4)),CAST(100.0 AS DECIMAL(8,4)),CAST(92.0 AS DECIMAL(8,4)),221000,CAST(28.9 AS DECIMAL(8,4)),CAST(29.6 AS DECIMAL(8,4)),CAST(9.0  AS DECIMAL(8,4)),CAST(44.0 AS DECIMAL(10,2)),CAST(12 AS SMALLINT),CAST(83.3 AS DECIMAL(8,4)),CAST(41.7 AS DECIMAL(8,4)),CAST(292.0 AS DECIMAL(10,2)),CAST(1 AS BIT),CAST(1 AS BIT),CAST(2030 AS SMALLINT),CAST(1 AS BIT),'AAA','A'),
    ('MSFT',2022,CAST(15200 AS DECIMAL(16,2)),CAST(1080 AS DECIMAL(16,2)),CAST(14800000 AS DECIMAL(16,2)),CAST(24.1 AS DECIMAL(14,4)),CAST(100.0 AS DECIMAL(8,4)),CAST(89.0 AS DECIMAL(8,4)),211000,CAST(28.5 AS DECIMAL(8,4)),CAST(28.9 AS DECIMAL(8,4)),CAST(9.5  AS DECIMAL(8,4)),CAST(42.0 AS DECIMAL(10,2)),CAST(12 AS SMALLINT),CAST(83.3 AS DECIMAL(8,4)),CAST(41.7 AS DECIMAL(8,4)),CAST(278.0 AS DECIMAL(10,2)),CAST(1 AS BIT),CAST(1 AS BIT),CAST(2030 AS SMALLINT),CAST(1 AS BIT),'AAA','A'),
    ('JPM', 2023,CAST(198000 AS DECIMAL(16,2)),CAST(98000 AS DECIMAL(16,2)),CAST(183000000 AS DECIMAL(16,2)),CAST(8.2 AS DECIMAL(14,4)),CAST(45.0 AS DECIMAL(8,4)),CAST(55.0 AS DECIMAL(8,4)),309926,CAST(47.0 AS DECIMAL(8,4)),CAST(33.0 AS DECIMAL(8,4)),CAST(15.0 AS DECIMAL(8,4)),CAST(40.0 AS DECIMAL(10,2)),CAST(12 AS SMALLINT),CAST(83.0 AS DECIMAL(8,4)),CAST(41.7 AS DECIMAL(8,4)),CAST(471.0 AS DECIMAL(10,2)),CAST(1 AS BIT),CAST(1 AS BIT),CAST(2050 AS SMALLINT),CAST(1 AS BIT),'A', 'B')
    ) v(tkr,yr,s1,s2,s3,energy,renew,recycle,empl,fem_empl,fem_mgmt,turnover,training,board_sz,indep_dir,fem_board,ceo_pay,esg_comm,clim_tgt,nz_yr,audit,msci,cdp)
    JOIN dw.dim_company c ON c.ticker_symbol=v.tkr AND c.is_current=1;
    PRINT '✓ esg.esg_metrics created and seeded (5 rows).';
END
GO

-- ── ESG: Composite Scoring View ───────────────────────────────
IF OBJECT_ID('esg.v_esg_scores','V') IS NOT NULL DROP VIEW esg.v_esg_scores;
GO
CREATE VIEW esg.v_esg_scores AS
WITH base AS (
    SELECT e.*, c.ticker_symbol, c.company_name,
           i.gics_sector_name,
           ISNULL(is_.total_revenue,0) AS revenue
    FROM esg.esg_metrics e
    JOIN dw.dim_company c ON e.company_key=c.company_key AND c.is_current=1
    JOIN dw.dim_industry i ON c.industry_key=i.industry_key
    LEFT JOIN dw.fact_income_statement is_
        ON c.company_key=is_.company_key AND is_.period_type='ANNUAL'
       AND is_.fiscal_year=e.report_year
),
intensity AS (
    SELECT *,
        -- Carbon intensity: tCO2e per $M revenue
        ROUND(CAST(total_emissions_tco2e AS FLOAT)/NULLIF(CAST(revenue AS FLOAT)/1e6,0),2) AS carbon_intensity,
        -- Energy intensity: GWh per $M revenue
        ROUND(CAST(energy_consumption_gwh AS FLOAT)/NULLIF(CAST(revenue AS FLOAT)/1e6,0),4) AS energy_intensity
    FROM base
),
scored AS (
    SELECT *,
        -- Environmental Score (0-100, higher = better)
        ROUND(
            PERCENT_RANK() OVER (PARTITION BY gics_sector_name, report_year ORDER BY renewable_energy_pct) * 40 +
            (1.0-PERCENT_RANK() OVER (PARTITION BY gics_sector_name, report_year ORDER BY carbon_intensity)) * 40 +
            PERCENT_RANK() OVER (PARTITION BY gics_sector_name, report_year ORDER BY waste_recycled_pct) * 20,
        1) AS environmental_score,
        -- Social Score
        ROUND(
            PERCENT_RANK() OVER (PARTITION BY gics_sector_name, report_year ORDER BY female_employees_pct) * 25 +
            PERCENT_RANK() OVER (PARTITION BY gics_sector_name, report_year ORDER BY female_mgmt_pct) * 20 +
            (1.0-PERCENT_RANK() OVER (PARTITION BY gics_sector_name, report_year ORDER BY employee_turnover_pct)) * 30 +
            PERCENT_RANK() OVER (PARTITION BY gics_sector_name, report_year ORDER BY training_hours_per_emp) * 25,
        1) AS social_score,
        -- Governance Score
        ROUND(
            PERCENT_RANK() OVER (PARTITION BY gics_sector_name, report_year ORDER BY independent_directors_pct) * 25 +
            PERCENT_RANK() OVER (PARTITION BY gics_sector_name, report_year ORDER BY female_board_pct) * 25 +
            (1.0-PERCENT_RANK() OVER (PARTITION BY gics_sector_name, report_year ORDER BY ceo_pay_ratio)) * 20 +
            CAST(has_esg_committee AS FLOAT) * 15 +
            CAST(has_climate_targets AS FLOAT) * 15,
        1) AS governance_score
    FROM intensity
)
SELECT *,
    -- Composite (E=40%, S=30%, G=30%)
    ROUND(environmental_score*0.40 + social_score*0.30 + governance_score*0.30,1) AS composite_esg_score,
    -- ESG Letter Rating
    CASE
        WHEN environmental_score*0.40+social_score*0.30+governance_score*0.30 >= 85 THEN 'AAA'
        WHEN environmental_score*0.40+social_score*0.30+governance_score*0.30 >= 70 THEN 'AA'
        WHEN environmental_score*0.40+social_score*0.30+governance_score*0.30 >= 55 THEN 'A'
        WHEN environmental_score*0.40+social_score*0.30+governance_score*0.30 >= 40 THEN 'BBB'
        WHEN environmental_score*0.40+social_score*0.30+governance_score*0.30 >= 25 THEN 'BB'
        ELSE 'B'
    END AS esg_letter_rating,
    -- Sector Rankings
    RANK() OVER (PARTITION BY gics_sector_name, report_year
                 ORDER BY environmental_score*0.40+social_score*0.30+governance_score*0.30 DESC) AS sector_esg_rank,
    RANK() OVER (PARTITION BY report_year
                 ORDER BY environmental_score*0.40+social_score*0.30+governance_score*0.30 DESC) AS overall_esg_rank
FROM scored;
GO
PRINT '✓ esg.v_esg_scores created.';
GO

-- ============================================================
-- MODULE 5 – CFO BI DASHBOARD (Power BI Optimised)
-- Pre-aggregated materialized-style table + live views
-- ============================================================

-- ── Self-Join: 3 consecutive years revenue growth ─────────────
IF OBJECT_ID('bi.v_consistent_growers','V') IS NOT NULL DROP VIEW bi.v_consistent_growers;
GO
CREATE VIEW bi.v_consistent_growers AS
SELECT
    c.ticker_symbol, c.company_name,
    a1.fiscal_year AS y1, a2.fiscal_year AS y2, a3.fiscal_year AS y3,
    ROUND(a1.total_revenue/1e6,2) AS rev_y1_m,
    ROUND(a2.total_revenue/1e6,2) AS rev_y2_m,
    ROUND(a3.total_revenue/1e6,2) AS rev_y3_m,
    ROUND((CAST(a2.total_revenue AS FLOAT)-a1.total_revenue)/NULLIF(ABS(a1.total_revenue),0)*100,1) AS growth_y1_y2_pct,
    ROUND((CAST(a3.total_revenue AS FLOAT)-a2.total_revenue)/NULLIF(ABS(a2.total_revenue),0)*100,1) AS growth_y2_y3_pct
FROM dw.fact_income_statement a1
-- Self-joins: same company, consecutive years
JOIN dw.fact_income_statement a2 ON a1.company_key=a2.company_key AND a2.fiscal_year=a1.fiscal_year+1 AND a2.period_type='ANNUAL'
JOIN dw.fact_income_statement a3 ON a1.company_key=a3.company_key AND a3.fiscal_year=a1.fiscal_year+2 AND a3.period_type='ANNUAL'
JOIN dw.dim_company c ON a1.company_key=c.company_key AND c.is_current=1
WHERE a1.period_type='ANNUAL'
  AND a2.total_revenue > a1.total_revenue   -- grew Y1→Y2
  AND a3.total_revenue > a2.total_revenue;  -- grew Y2→Y3
GO
PRINT '✓ bi.v_consistent_growers created (self-join demo).';
GO

-- ── Cross-Join: Stress Scenario Grid ─────────────────────────
IF OBJECT_ID('bi.v_sensitivity_grid','V') IS NOT NULL DROP VIEW bi.v_sensitivity_grid;
GO
CREATE VIEW bi.v_sensitivity_grid AS
WITH scenarios AS (
    SELECT *
    FROM (VALUES
        ('BASE CASE',        0,    0),
        ('MILD RECESSION',  -500,  50),
        ('SEVERE RECESSION',-1500, 150),
        ('BULL CASE',        300, -25),
        ('STRONG BULL',      800, -75)
    ) s(scenario_name, ebitda_shock_bps, rate_change_bps)
)
SELECT
    c.ticker_symbol,
    c.company_name,
    s.scenario_name,
    s.ebitda_shock_bps,
    s.rate_change_bps,
    is_.fiscal_year,
    ROUND(is_.total_revenue/1e6,2)  AS base_revenue_m,
    ROUND(is_.operating_income/1e6,2) AS base_ebit_m,
    -- EBITDA under scenario
    ROUND(
        (is_.operating_income + ISNULL(is_.depreciation_amortization,0))
        * (1.0 + CAST(s.ebitda_shock_bps AS FLOAT)/10000.0) / 1e6,
    2) AS stressed_ebitda_m,
    -- Net debt / stressed EBITDA
    ROUND(
        CAST(bs.net_debt AS FLOAT)
        / NULLIF(
            (is_.operating_income + ISNULL(is_.depreciation_amortization,0))
            * (1.0 + CAST(s.ebitda_shock_bps AS FLOAT)/10000.0),
        0),
    2) AS stressed_nd_ebitda,
    -- Stressed interest coverage
    ROUND(
        CAST((is_.operating_income + ISNULL(is_.depreciation_amortization,0)) AS FLOAT)
        * (1.0 + CAST(s.ebitda_shock_bps AS FLOAT)/10000.0)
        / NULLIF(ABS(is_.interest_expense) * (1.0 + CAST(s.rate_change_bps AS FLOAT)/10000.0), 0),
    2) AS stressed_interest_coverage
FROM dw.dim_company c
CROSS JOIN scenarios s           -- CROSS JOIN for full scenario matrix
JOIN dw.fact_income_statement is_
    ON c.company_key=is_.company_key AND is_.period_type='ANNUAL' AND is_.fiscal_year=2023
JOIN dw.fact_balance_sheet bs
    ON c.company_key=bs.company_key AND bs.period_type='ANNUAL' AND bs.fiscal_year=2023
WHERE c.is_current=1;
GO
PRINT '✓ bi.v_sensitivity_grid created (CROSS JOIN demo).';
GO

-- ── Power BI: KPI Traffic Light Summary ──────────────────────
IF OBJECT_ID('bi.v_kpi_traffic_lights','V') IS NOT NULL DROP VIEW bi.v_kpi_traffic_lights;
GO
CREATE VIEW bi.v_kpi_traffic_lights AS
SELECT
    ticker_symbol, company_name, gics_sector_name, fiscal_year,
    revenue_usd_m, ebitda_usd_m, fcf_usd_m,
    ebitda_margin_pct, net_margin_pct, roe_pct,
    net_debt_to_ebitda, revenue_yoy_pct,
    -- Individual KPI signals
    revenue_status, margin_status, leverage_status, roe_status, fcf_status,
    -- Green KPI count
    (CASE WHEN revenue_yoy_pct   >= 10  THEN 1 ELSE 0 END +
     CASE WHEN ebitda_margin_pct >= 20  THEN 1 ELSE 0 END +
     CASE WHEN net_debt_to_ebitda<= 2.0 THEN 1 ELSE 0 END +
     CASE WHEN fcf_usd_m         >  0   THEN 1 ELSE 0 END +
     CASE WHEN roe_pct           >= 15  THEN 1 ELSE 0 END) AS green_kpi_count,
    performance_band
FROM bi.v_executive_scorecard;
GO
PRINT '✓ bi.v_kpi_traffic_lights created.';
GO

-- ── Power BI: Waterfall Revenue Bridge ───────────────────────
IF OBJECT_ID('bi.v_revenue_bridge','V') IS NOT NULL DROP VIEW bi.v_revenue_bridge;
GO
CREATE VIEW bi.v_revenue_bridge AS
SELECT
    c.ticker_symbol, c.company_name,
    curr.fiscal_year,
    ROUND(curr.total_revenue/1e6,2)  AS current_revenue_m,
    ROUND(prior.total_revenue/1e6,2) AS prior_revenue_m,
    ROUND((curr.total_revenue-prior.total_revenue)/1e6,2) AS revenue_delta_m,
    ROUND((CAST(curr.total_revenue AS FLOAT)-prior.total_revenue)/NULLIF(ABS(prior.total_revenue),0)*100,1) AS yoy_growth_pct,
    -- Decompose into service vs product
    ROUND(ISNULL(curr.service_revenue,0)/1e6,2)  AS service_revenue_m,
    ROUND(ISNULL(prior.service_revenue,0)/1e6,2) AS prior_service_revenue_m,
    ROUND((ISNULL(curr.service_revenue,0)-ISNULL(prior.service_revenue,0))/1e6,2) AS service_delta_m,
    ROUND(ISNULL(curr.product_revenue,0)/1e6,2)  AS product_revenue_m,
    ROUND(ISNULL(prior.product_revenue,0)/1e6,2) AS prior_product_revenue_m,
    ROUND((ISNULL(curr.product_revenue,0)-ISNULL(prior.product_revenue,0))/1e6,2) AS product_delta_m,
    -- Margin bridges
    ROUND(curr.operating_income/1e6,2)  AS curr_ebit_m,
    ROUND(prior.operating_income/1e6,2) AS prior_ebit_m,
    ROUND((curr.operating_income-prior.operating_income)/1e6,2) AS ebit_delta_m
FROM dw.dim_company c
JOIN dw.fact_income_statement curr  ON c.company_key=curr.company_key  AND curr.period_type='ANNUAL'
JOIN dw.fact_income_statement prior ON c.company_key=prior.company_key AND prior.period_type='ANNUAL'
                                    AND prior.fiscal_year=curr.fiscal_year-1
WHERE c.is_current=1;
GO
PRINT '✓ bi.v_revenue_bridge created.';
GO

-- ── Governance: Full Enterprise 360 View ─────────────────────
IF OBJECT_ID('governance.v_enterprise_360','V') IS NOT NULL DROP VIEW governance.v_enterprise_360;
GO
CREATE VIEW governance.v_enterprise_360 AS
SELECT
    -- Identity
    sc.ticker_symbol, sc.company_name, sc.gics_sector_name, sc.country_name,
    sc.fiscal_year,
    -- Financial Performance
    sc.revenue_usd_m, sc.revenue_yoy_pct,
    sc.ebitda_usd_m, sc.ebitda_margin_pct,
    sc.net_margin_pct, sc.roe_pct, sc.roa_pct,
    sc.fcf_usd_m, sc.fcf_margin_pct,
    -- Balance Sheet
    sc.net_debt_to_ebitda,
    -- ESG
    esg.composite_esg_score, esg.esg_letter_rating,
    esg.carbon_intensity, esg.renewable_energy_pct,
    esg.female_board_pct, esg.governance_score,
    -- Credit Risk
    cr.total_outstanding_m AS credit_outstanding_m,
    cr.total_expected_loss_m,
    cr.avg_pd_pct,
    -- KPI Status
    sc.revenue_status, sc.margin_status, sc.leverage_status,
    sc.roe_status, sc.fcf_status, sc.performance_band
FROM bi.v_executive_scorecard sc
LEFT JOIN esg.v_esg_scores esg
    ON sc.ticker_symbol = esg.ticker_symbol AND esg.report_year = sc.fiscal_year
LEFT JOIN (
    SELECT b.borrower_name,
           ROUND(SUM(lf.outstanding_balance)/1e6,2)    AS total_outstanding_m,
           ROUND(SUM(lf.expected_loss_usd)/1e6,4)      AS total_expected_loss_m,
           ROUND(AVG(lf.pd_pct),4)                     AS avg_pd_pct
    FROM credit.loan_facilities lf
    JOIN credit.borrowers b ON lf.borrower_key=b.borrower_key
    GROUP BY b.borrower_name
) cr ON sc.company_name = cr.borrower_name;
GO
PRINT '✓ governance.v_enterprise_360 created.';
GO

-- ── Governance: Platform Health Check ────────────────────────
IF OBJECT_ID('governance.v_platform_health','V') IS NOT NULL DROP VIEW governance.v_platform_health;
GO
CREATE VIEW governance.v_platform_health AS
SELECT 'Data Warehouse'    AS module, 'fact_income_statement' AS component, COUNT(*) AS records, MAX(created_at) AS last_loaded FROM dw.fact_income_statement UNION ALL
SELECT 'Data Warehouse',            'fact_balance_sheet',                  COUNT(*), MAX(created_at) FROM dw.fact_balance_sheet UNION ALL
SELECT 'Data Warehouse',            'fact_cash_flow',                      COUNT(*), MAX(created_at) FROM dw.fact_cash_flow      UNION ALL
SELECT 'Data Warehouse',            'fact_stock_price',                    COUNT(*), MAX(created_at) FROM dw.fact_stock_price    UNION ALL
SELECT 'Credit Risk',               'loan_facilities',                     COUNT(*), MAX(created_at) FROM credit.loan_facilities UNION ALL
SELECT 'Credit Risk',               'borrowers',                           COUNT(*), MAX(created_at) FROM credit.borrowers       UNION ALL
SELECT 'FP&A',                      'actuals',                             COUNT(*), MAX(created_at) FROM fpa.actuals            UNION ALL
SELECT 'FP&A',                      'budgets',                             COUNT(*), MAX(created_at) FROM fpa.budgets            UNION ALL
SELECT 'Treasury',                  'bank_accounts',                       COUNT(*), MAX(created_at) FROM treasury.bank_accounts UNION ALL
SELECT 'Treasury',                  'debt_facilities',                     COUNT(*), MAX(created_at) FROM treasury.debt_facilities UNION ALL
SELECT 'ESG',                       'esg_metrics',                         COUNT(*), MAX(created_at) FROM esg.esg_metrics        UNION ALL
SELECT 'ETL',                       'pipeline_jobs',                       COUNT(*), MAX(created_at) FROM etl.pipeline_jobs;
GO
PRINT '✓ governance.v_platform_health created.';
GO

-- ============================================================
-- FINAL VERIFICATION – PART 2
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT '  PART 2 VERIFICATION – 8 ADDITIONAL CHECKS';
PRINT '============================================';
GO

PRINT '-- CHECK A: FP&A Variance Analysis';
SELECT company_key, fiscal_year, fiscal_month,
       actual_revenue, budget_revenue,
       ROUND(revenue_bva,2) AS revenue_bva,
       ROUND(ytd_revenue,2) AS ytd_revenue,
       budget_flag
FROM fpa.v_forecast_accuracy
ORDER BY fiscal_year, fiscal_month;
GO

PRINT '-- CHECK B: Treasury Liquidity Dashboard';
SELECT ticker_symbol, company_name,
       total_debt_bn, total_undrawn_bn,
       liquid_assets_m, net_debt_m,
       liquidity_headroom_bn,
       net_debt_ebitda, liquidity_status
FROM treasury.v_liquidity_dashboard;
GO

PRINT '-- CHECK C: Working Capital (DSO/DIO/DPO/CCC)';
SELECT ticker_symbol, fiscal_year,
       receivables_m, inventory_m, payables_m,
       dso, dio, dpo, cash_conversion_cycle, wc_to_revenue_pct
FROM treasury.v_working_capital
ORDER BY ticker_symbol, fiscal_year;
GO

PRINT '-- CHECK D: ESG Scores';
SELECT ticker_symbol, company_name, report_year,
       ROUND(environmental_score,1) AS env_score,
       ROUND(social_score,1)        AS soc_score,
       ROUND(governance_score,1)    AS gov_score,
       ROUND(composite_esg_score,1) AS composite,
       esg_letter_rating, sector_esg_rank, overall_esg_rank,
       carbon_intensity
FROM esg.v_esg_scores
ORDER BY composite_esg_score DESC;
GO

PRINT '-- CHECK E: KPI Traffic Lights (Power BI ready)';
SELECT ticker_symbol, fiscal_year,
       ebitda_margin_pct, roe_pct, revenue_yoy_pct,
       revenue_status, margin_status, leverage_status, roe_status,
       green_kpi_count, performance_band
FROM bi.v_kpi_traffic_lights
ORDER BY ticker_symbol, fiscal_year;
GO

PRINT '-- CHECK F: Revenue Bridge (YoY waterfall)';
SELECT ticker_symbol, fiscal_year,
       prior_revenue_m, current_revenue_m,
       revenue_delta_m, yoy_growth_pct,
       service_delta_m, product_delta_m, ebit_delta_m
FROM bi.v_revenue_bridge
ORDER BY ticker_symbol, fiscal_year;
GO

PRINT '-- CHECK G: 3-Year Consistent Revenue Growers (Self-Join)';
SELECT ticker_symbol, company_name,
       y1, y2, y3,
       rev_y1_m, rev_y2_m, rev_y3_m,
       growth_y1_y2_pct, growth_y2_y3_pct
FROM bi.v_consistent_growers
ORDER BY growth_y2_y3_pct DESC;
GO

PRINT '-- CHECK H: Platform Health (all modules)';
SELECT module, component, records, last_loaded
FROM governance.v_platform_health
ORDER BY module, component;
GO

PRINT '-- CHECK I: Sensitivity Grid (CROSS JOIN – 5 scenarios x 3 companies)';
SELECT ticker_symbol, scenario_name, fiscal_year,
       base_ebit_m, stressed_ebitda_m,
       stressed_nd_ebitda, stressed_interest_coverage
FROM bi.v_sensitivity_grid
ORDER BY ticker_symbol, scenario_name;
GO

PRINT '';
PRINT '============================================';
PRINT '  COMPLETE PORTFOLIO SUMMARY';
PRINT '============================================';
SELECT
    o.type_desc      AS object_type,
    COUNT(*)         AS count
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id=s.schema_id
WHERE o.type IN ('U','V','P','IF','TR')
  AND s.name NOT IN ('sys','INFORMATION_SCHEMA')
GROUP BY o.type_desc
ORDER BY count DESC;
GO

PRINT '';
PRINT '✓ All 12 portfolio projects deployed successfully.';
PRINT '✓ SQL Server Finance Portfolio – FinancePortfolio database ready.';
GO

