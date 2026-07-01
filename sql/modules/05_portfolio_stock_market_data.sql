-- ============================================================
-- SQL PORTFOLIO – PART 5: STOCK PRICE DATA + MARKET VIEWS
--                          PORTFOLIO ANALYTICS + FINAL TESTS
-- Engine : SQL Server 2017+ Express / SSMS
-- Run    : After Parts 1-4
-- ============================================================

USE FinancePortfolio;
GO

-- ============================================================
-- MODULE 1 – SEED STOCK PRICE DATA
-- Historical adjusted prices (simplified – 5 years AAPL & MSFT)
-- Source: Yahoo Finance public historical data
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM dw.fact_stock_price)
BEGIN
    -- Insert annual year-end closing prices as representative data points
    -- In production, this table would have daily rows from a market data feed
    INSERT INTO dw.fact_stock_price
        (company_key, date_key, open_price, high_price, low_price,
         close_price, adj_close_price, volume, market_cap_m,
         shares_outstanding_m, data_source)
    SELECT c.company_key, d.date_key,
           v.opn, v.hi, v.lo, v.cls, v.adj, v.vol, v.mktcap, v.shr, 'YAHOO_FINANCE'
    FROM (VALUES
    -- AAPL annual year-end prices (USD)
    ('AAPL',20191231, CAST(289.19 AS DECIMAL(14,4)),CAST(293.97 AS DECIMAL(14,4)),CAST(288.09 AS DECIMAL(14,4)),CAST(293.65 AS DECIMAL(14,4)),CAST(291.35 AS DECIMAL(14,4)),CAST(36580100 AS BIGINT),CAST(1304000 AS DECIMAL(20,4)),CAST(4443.2 AS DECIMAL(16,4))),
    ('AAPL',20201231, CAST(133.99 AS DECIMAL(14,4)),CAST(134.74 AS DECIMAL(14,4)),CAST(131.72 AS DECIMAL(14,4)),CAST(132.69 AS DECIMAL(14,4)),CAST(131.48 AS DECIMAL(14,4)),CAST(99116600 AS BIGINT),CAST(2255000 AS DECIMAL(20,4)),CAST(4500.9 AS DECIMAL(16,4))),
    ('AAPL',20211231, CAST(177.09 AS DECIMAL(14,4)),CAST(182.13 AS DECIMAL(14,4)),CAST(177.09 AS DECIMAL(14,4)),CAST(177.57 AS DECIMAL(14,4)),CAST(176.89 AS DECIMAL(14,4)),CAST(64062300 AS BIGINT),CAST(2913000 AS DECIMAL(20,4)),CAST(4400.0 AS DECIMAL(16,4))),
    ('AAPL',20221230, CAST(129.61 AS DECIMAL(14,4)),CAST(130.29 AS DECIMAL(14,4)),CAST(124.89 AS DECIMAL(14,4)),CAST(129.93 AS DECIMAL(14,4)),CAST(129.93 AS DECIMAL(14,4)),CAST(75703700 AS BIGINT),CAST(2066000 AS DECIMAL(20,4)),CAST(4383.3 AS DECIMAL(16,4))),
    ('AAPL',20231229, CAST(192.11 AS DECIMAL(14,4)),CAST(194.48 AS DECIMAL(14,4)),CAST(191.94 AS DECIMAL(14,4)),CAST(192.53 AS DECIMAL(14,4)),CAST(192.53 AS DECIMAL(14,4)),CAST(48783900 AS BIGINT),CAST(2994000 AS DECIMAL(20,4)),CAST(4383.3 AS DECIMAL(16,4))),
    -- MSFT annual year-end prices (USD)
    ('MSFT',20191231, CAST(157.60 AS DECIMAL(14,4)),CAST(158.96 AS DECIMAL(14,4)),CAST(157.31 AS DECIMAL(14,4)),CAST(157.70 AS DECIMAL(14,4)),CAST(157.00 AS DECIMAL(14,4)),CAST(21118100 AS BIGINT),CAST(1203000 AS DECIMAL(20,4)),CAST(7629.0 AS DECIMAL(16,4))),
    ('MSFT',20201231, CAST(222.16 AS DECIMAL(14,4)),CAST(224.10 AS DECIMAL(14,4)),CAST(220.70 AS DECIMAL(14,4)),CAST(222.42 AS DECIMAL(14,4)),CAST(221.57 AS DECIMAL(14,4)),CAST(18066200 AS BIGINT),CAST(1681000 AS DECIMAL(20,4)),CAST(7558.5 AS DECIMAL(16,4))),
    ('MSFT',20211231, CAST(330.16 AS DECIMAL(14,4)),CAST(330.54 AS DECIMAL(14,4)),CAST(326.33 AS DECIMAL(14,4)),CAST(336.32 AS DECIMAL(14,4)),CAST(335.44 AS DECIMAL(14,4)),CAST(20577100 AS BIGINT),CAST(2525000 AS DECIMAL(20,4)),CAST(7518.9 AS DECIMAL(16,4))),
    ('MSFT',20221230, CAST(239.23 AS DECIMAL(14,4)),CAST(241.87 AS DECIMAL(14,4)),CAST(237.33 AS DECIMAL(14,4)),CAST(239.82 AS DECIMAL(14,4)),CAST(239.82 AS DECIMAL(14,4)),CAST(19921300 AS BIGINT),CAST(1787000 AS DECIMAL(20,4)),CAST(7455.5 AS DECIMAL(16,4))),
    ('MSFT',20231229, CAST(373.84 AS DECIMAL(14,4)),CAST(376.00 AS DECIMAL(14,4)),CAST(372.67 AS DECIMAL(14,4)),CAST(374.51 AS DECIMAL(14,4)),CAST(374.51 AS DECIMAL(14,4)),CAST(16780800 AS BIGINT),CAST(2789000 AS DECIMAL(20,4)),CAST(7432.5 AS DECIMAL(16,4))),
    -- JPM annual year-end prices (USD)
    ('JPM',20191231, CAST(139.40 AS DECIMAL(14,4)),CAST(140.08 AS DECIMAL(14,4)),CAST(138.93 AS DECIMAL(14,4)),CAST(139.40 AS DECIMAL(14,4)),CAST(135.33 AS DECIMAL(14,4)),CAST(12009400 AS BIGINT),CAST(433000  AS DECIMAL(20,4)),CAST(3105.7 AS DECIMAL(16,4))),
    ('JPM',20201231, CAST(126.68 AS DECIMAL(14,4)),CAST(127.93 AS DECIMAL(14,4)),CAST(126.31 AS DECIMAL(14,4)),CAST(127.07 AS DECIMAL(14,4)),CAST(123.22 AS DECIMAL(14,4)),CAST(12991200 AS BIGINT),CAST(381000  AS DECIMAL(20,4)),CAST(3058.0 AS DECIMAL(16,4))),
    ('JPM',20211231, CAST(165.75 AS DECIMAL(14,4)),CAST(166.13 AS DECIMAL(14,4)),CAST(163.86 AS DECIMAL(14,4)),CAST(166.46 AS DECIMAL(14,4)),CAST(164.11 AS DECIMAL(14,4)),CAST(11379200 AS BIGINT),CAST(484000  AS DECIMAL(20,4)),CAST(2908.8 AS DECIMAL(16,4))),
    ('JPM',20221230, CAST(133.48 AS DECIMAL(14,4)),CAST(135.00 AS DECIMAL(14,4)),CAST(132.65 AS DECIMAL(14,4)),CAST(134.10 AS DECIMAL(14,4)),CAST(134.10 AS DECIMAL(14,4)),CAST(10723900 AS BIGINT),CAST(387000  AS DECIMAL(20,4)),CAST(2888.5 AS DECIMAL(16,4))),
    ('JPM',20231229, CAST(168.33 AS DECIMAL(14,4)),CAST(170.32 AS DECIMAL(14,4)),CAST(168.28 AS DECIMAL(14,4)),CAST(170.10 AS DECIMAL(14,4)),CAST(170.10 AS DECIMAL(14,4)),CAST(8872100  AS BIGINT),CAST(491000  AS DECIMAL(20,4)),CAST(2888.5 AS DECIMAL(16,4)))
    ) v(tkr, dk, opn, hi, lo, cls, adj, vol, mktcap, shr)
    JOIN dw.dim_company c ON c.ticker_symbol=v.tkr AND c.is_current=1
    JOIN dw.dim_date    d ON d.date_key=v.dk;
    PRINT '✓ Stock price data seeded (15 rows – 3 companies × 5 years).';
END
GO

-- ============================================================
-- MODULE 2 – PORTFOLIO ANALYTICS TABLES + VIEWS
-- ============================================================

-- ── Portfolio Master ──────────────────────────────────────────
IF OBJECT_ID('mart.portfolios','U') IS NULL
BEGIN
    CREATE TABLE mart.portfolios (
        portfolio_key      INT           IDENTITY(1,1) PRIMARY KEY,
        portfolio_id       VARCHAR(30)   NOT NULL UNIQUE,
        portfolio_name     NVARCHAR(150) NOT NULL,
        portfolio_type     VARCHAR(40),
        manager_name       NVARCHAR(100),
        benchmark_ticker   VARCHAR(20),
        inception_date     DATE          NOT NULL,
        base_currency      CHAR(3)       DEFAULT 'USD',
        aum_usd_m          DECIMAL(20,4),
        is_active          BIT           DEFAULT 1,
        created_at         DATETIME2     DEFAULT GETDATE()
    );
    INSERT INTO mart.portfolios
        (portfolio_id, portfolio_name, portfolio_type, manager_name,
         benchmark_ticker, inception_date, base_currency, aum_usd_m)
    VALUES
    ('PORT-TECH','Technology Growth Fund','EQUITY','Portfolio Manager A','QQQ','2019-01-01','USD',500.00),
    ('PORT-FIN', 'Financial Sector Fund', 'EQUITY','Portfolio Manager B','XLF','2019-01-01','USD',200.00),
    ('PORT-BLEND','Blended Multi-Cap Fund','BALANCED','Portfolio Manager C','SPY','2019-01-01','USD',350.00);
    PRINT '✓ mart.portfolios created and seeded (3 portfolios).';
END
GO

-- ── Portfolio Holdings ────────────────────────────────────────
IF OBJECT_ID('mart.portfolio_holdings','U') IS NULL
BEGIN
    CREATE TABLE mart.portfolio_holdings (
        holding_key          BIGINT        IDENTITY(1,1) PRIMARY KEY,
        portfolio_key        INT           NOT NULL REFERENCES mart.portfolios(portfolio_key),
        company_key          INT           NOT NULL REFERENCES dw.dim_company(company_key),
        date_key             INT           NOT NULL REFERENCES dw.dim_date(date_key),
        shares_held          DECIMAL(18,6) NOT NULL,
        avg_cost_basis       DECIMAL(14,4) NOT NULL,
        market_price         DECIMAL(14,4) NOT NULL,
        market_value_usd     AS (shares_held * market_price),
        cost_value_usd       AS (shares_held * avg_cost_basis),
        unrealized_pnl       AS (shares_held * (market_price - avg_cost_basis)),
        portfolio_weight_pct DECIMAL(8,4),
        asset_class          VARCHAR(30)   DEFAULT 'EQUITY',
        currency             CHAR(3)       DEFAULT 'USD',
        created_at           DATETIME2     DEFAULT GETDATE(),
        CONSTRAINT UQ_holding UNIQUE (portfolio_key, company_key, date_key)
    );
    -- Seed holdings for each portfolio at year-end 2023
    INSERT INTO mart.portfolio_holdings
        (portfolio_key, company_key, date_key,
         shares_held, avg_cost_basis, market_price, portfolio_weight_pct)
    SELECT p.portfolio_key, c.company_key,
           d.date_key,
           v.shares, v.cost, v.price, v.wt
    FROM (VALUES
    -- PORT-TECH holdings (AAPL + MSFT)
    ('PORT-TECH','AAPL',20231229, CAST(500000 AS DECIMAL(18,6)),CAST(155.00 AS DECIMAL(14,4)),CAST(192.53 AS DECIMAL(14,4)),CAST(60.5 AS DECIMAL(8,4))),
    ('PORT-TECH','MSFT',20231229, CAST(200000 AS DECIMAL(18,6)),CAST(280.00 AS DECIMAL(14,4)),CAST(374.51 AS DECIMAL(14,4)),CAST(39.5 AS DECIMAL(8,4))),
    -- PORT-FIN holdings (JPM)
    ('PORT-FIN', 'JPM', 20231229, CAST(600000 AS DECIMAL(18,6)),CAST(130.00 AS DECIMAL(14,4)),CAST(170.10 AS DECIMAL(14,4)),CAST(100.0 AS DECIMAL(8,4))),
    -- PORT-BLEND holdings (all three)
    ('PORT-BLEND','AAPL',20231229, CAST(300000 AS DECIMAL(18,6)),CAST(155.00 AS DECIMAL(14,4)),CAST(192.53 AS DECIMAL(14,4)),CAST(40.0 AS DECIMAL(8,4))),
    ('PORT-BLEND','MSFT',20231229, CAST(150000 AS DECIMAL(18,6)),CAST(280.00 AS DECIMAL(14,4)),CAST(374.51 AS DECIMAL(14,4)),CAST(38.7 AS DECIMAL(8,4))),
    ('PORT-BLEND','JPM', 20231229, CAST(200000 AS DECIMAL(18,6)),CAST(130.00 AS DECIMAL(14,4)),CAST(170.10 AS DECIMAL(14,4)),CAST(21.3 AS DECIMAL(8,4)))
    ) v(pid, tkr, dk, shares, cost, price, wt)
    JOIN mart.portfolios  p ON p.portfolio_id   = v.pid
    JOIN dw.dim_company   c ON c.ticker_symbol  = v.tkr AND c.is_current=1
    JOIN dw.dim_date      d ON d.date_key       = v.dk;
    PRINT '✓ mart.portfolio_holdings seeded (6 positions).';
END
GO

-- ── Portfolio Transactions ────────────────────────────────────
IF OBJECT_ID('mart.portfolio_transactions','U') IS NULL
BEGIN
    CREATE TABLE mart.portfolio_transactions (
        transaction_key   BIGINT        IDENTITY(1,1) PRIMARY KEY,
        portfolio_key     INT           NOT NULL REFERENCES mart.portfolios(portfolio_key),
        company_key       INT           REFERENCES dw.dim_company(company_key),
        transaction_date  DATE          NOT NULL,
        transaction_type  VARCHAR(20)   NOT NULL,
        shares            DECIMAL(18,6),
        price_per_share   DECIMAL(14,4),
        gross_amount      DECIMAL(20,4),
        commission        DECIMAL(12,4) DEFAULT 0,
        net_amount        AS (gross_amount - commission),
        currency          CHAR(3)       DEFAULT 'USD',
        settlement_date   DATE,
        broker            NVARCHAR(80),
        created_at        DATETIME2     DEFAULT GETDATE()
    );
    INSERT INTO mart.portfolio_transactions
        (portfolio_key, company_key, transaction_date, transaction_type,
         shares, price_per_share, gross_amount, commission, settlement_date, broker)
    SELECT p.portfolio_key, c.company_key,
           CAST(v.txdate AS DATE), v.txtype,
           v.shares, v.price, v.amt, v.comm,
           CAST(DATEADD(DAY,2,v.txdate) AS DATE), v.broker
    FROM (VALUES
    ('PORT-TECH','AAPL','2019-01-15','BUY', CAST(500000 AS DECIMAL(18,6)),CAST(150.25 AS DECIMAL(14,4)),CAST(75125000 AS DECIMAL(20,4)),CAST(750 AS DECIMAL(12,4)),'Morgan Stanley'),
    ('PORT-TECH','MSFT','2019-01-15','BUY', CAST(200000 AS DECIMAL(18,6)),CAST(101.57 AS DECIMAL(14,4)),CAST(20314000 AS DECIMAL(20,4)),CAST(200 AS DECIMAL(12,4)),'Morgan Stanley'),
    ('PORT-FIN', 'JPM', '2019-01-15','BUY', CAST(600000 AS DECIMAL(18,6)),CAST(96.50  AS DECIMAL(14,4)),CAST(57900000 AS DECIMAL(20,4)),CAST(600 AS DECIMAL(12,4)),'Goldman Sachs'),
    ('PORT-BLEND','AAPL','2019-01-15','BUY', CAST(300000 AS DECIMAL(18,6)),CAST(150.25 AS DECIMAL(14,4)),CAST(45075000 AS DECIMAL(20,4)),CAST(450 AS DECIMAL(12,4)),'JPMorgan'),
    ('PORT-BLEND','MSFT','2019-01-15','BUY', CAST(150000 AS DECIMAL(18,6)),CAST(101.57 AS DECIMAL(14,4)),CAST(15235500 AS DECIMAL(20,4)),CAST(150 AS DECIMAL(12,4)),'JPMorgan'),
    ('PORT-BLEND','JPM', '2019-01-15','BUY', CAST(200000 AS DECIMAL(18,6)),CAST(96.50  AS DECIMAL(14,4)),CAST(19300000 AS DECIMAL(20,4)),CAST(200 AS DECIMAL(12,4)),'JPMorgan')
    ) v(pid, tkr, txdate, txtype, shares, price, amt, comm, broker)
    JOIN mart.portfolios p ON p.portfolio_id  = v.pid
    JOIN dw.dim_company  c ON c.ticker_symbol = v.tkr AND c.is_current=1;
    PRINT '✓ mart.portfolio_transactions seeded (6 buy transactions).';
END
GO

-- ── Portfolio Performance View ────────────────────────────────
IF OBJECT_ID('mart.v_portfolio_performance','V') IS NOT NULL DROP VIEW mart.v_portfolio_performance;
GO
CREATE VIEW mart.v_portfolio_performance AS
WITH position_detail AS (
    SELECT
        p.portfolio_id, p.portfolio_name, p.portfolio_type,
        p.benchmark_ticker, p.inception_date,
        c.ticker_symbol, c.company_name,
        i.gics_sector_name,
        h.date_key, dd.full_date, dd.year_number,
        h.shares_held,
        h.avg_cost_basis,
        h.market_price,
        h.market_value_usd,
        h.cost_value_usd,
        h.unrealized_pnl,
        h.portfolio_weight_pct,
        -- Unrealized return %
        ROUND(
            CAST(h.market_price - h.avg_cost_basis AS FLOAT)
            / NULLIF(CAST(h.avg_cost_basis AS FLOAT),0) * 100, 2
        )                                                        AS position_return_pct,
        -- Contribution to portfolio (weight × position return)
        ROUND(
            h.portfolio_weight_pct / 100.0
            * (CAST(h.market_price - h.avg_cost_basis AS FLOAT)
               / NULLIF(CAST(h.avg_cost_basis AS FLOAT),0) * 100),
        2)                                                       AS contribution_to_return_pct
    FROM mart.portfolios p
    JOIN mart.portfolio_holdings h ON p.portfolio_key=h.portfolio_key
    JOIN dw.dim_company  c  ON h.company_key=c.company_key
    JOIN dw.dim_industry i  ON c.industry_key=i.industry_key
    JOIN dw.dim_date     dd ON h.date_key=dd.date_key
),
portfolio_totals AS (
    SELECT
        portfolio_id, portfolio_name, date_key,
        SUM(market_value_usd)                                    AS total_market_value,
        SUM(cost_value_usd)                                      AS total_cost_value,
        SUM(unrealized_pnl)                                      AS total_unrealized_pnl,
        SUM(contribution_to_return_pct)                          AS portfolio_return_pct
    FROM position_detail
    GROUP BY portfolio_id, portfolio_name, date_key
)
SELECT
    pd.portfolio_id, pd.portfolio_name, pd.portfolio_type,
    pd.benchmark_ticker, pd.inception_date,
    pd.ticker_symbol, pd.company_name, pd.gics_sector_name,
    pd.date_key, pd.full_date, pd.year_number,
    pd.shares_held,
    ROUND(pd.avg_cost_basis,4)                                   AS avg_cost_basis,
    ROUND(pd.market_price,4)                                     AS market_price,
    ROUND(pd.market_value_usd/1e6,4)                             AS market_value_m,
    ROUND(pd.cost_value_usd/1e6,4)                               AS cost_value_m,
    ROUND(pd.unrealized_pnl/1e6,4)                               AS unrealized_pnl_m,
    pd.portfolio_weight_pct,
    ROUND(pd.position_return_pct,2)                              AS position_return_pct,
    ROUND(pd.contribution_to_return_pct,2)                       AS contribution_to_return_pct,
    -- Portfolio-level totals
    ROUND(pt.total_market_value/1e6,2)                           AS portfolio_total_value_m,
    ROUND(pt.total_cost_value/1e6,2)                             AS portfolio_total_cost_m,
    ROUND(pt.total_unrealized_pnl/1e6,2)                         AS portfolio_total_pnl_m,
    ROUND(pt.portfolio_return_pct,2)                             AS portfolio_total_return_pct,
    -- Risk signals
    CASE
        WHEN pd.position_return_pct >= 20  THEN 'STRONG GAIN'
        WHEN pd.position_return_pct >= 0   THEN 'GAIN'
        WHEN pd.position_return_pct >= -10 THEN 'MODERATE LOSS'
        ELSE 'SIGNIFICANT LOSS'
    END                                                          AS position_status
FROM position_detail pd
JOIN portfolio_totals pt ON pd.portfolio_id=pt.portfolio_id AND pd.date_key=pt.date_key;
GO
PRINT '✓ mart.v_portfolio_performance created.';
GO

-- ── Portfolio Risk Attribution View ──────────────────────────
IF OBJECT_ID('mart.v_portfolio_attribution','V') IS NOT NULL DROP VIEW mart.v_portfolio_attribution;
GO
CREATE VIEW mart.v_portfolio_attribution AS
WITH sector_weights AS (
    SELECT
        p.portfolio_id, p.portfolio_name,
        i.gics_sector_name,
        h.date_key,
        SUM(h.market_value_usd)                                  AS sector_market_value,
        SUM(SUM(h.market_value_usd)) OVER (
            PARTITION BY p.portfolio_id, h.date_key)             AS total_portfolio_value,
        -- Weighted average position return per sector
        SUM(
            (CAST(h.market_price - h.avg_cost_basis AS FLOAT)
             / NULLIF(CAST(h.avg_cost_basis AS FLOAT),0)) * h.market_value_usd
        ) / NULLIF(SUM(h.market_value_usd),0) * 100              AS sector_return_pct
    FROM mart.portfolios p
    JOIN mart.portfolio_holdings h ON p.portfolio_key=h.portfolio_key
    JOIN dw.dim_company  c ON h.company_key=c.company_key
    JOIN dw.dim_industry i ON c.industry_key=i.industry_key
    GROUP BY p.portfolio_id, p.portfolio_name, i.gics_sector_name, h.date_key
)
SELECT
    portfolio_id, portfolio_name, gics_sector_name, date_key,
    ROUND(sector_market_value/1e6,2)                             AS sector_value_m,
    ROUND(total_portfolio_value/1e6,2)                           AS total_value_m,
    ROUND(CAST(sector_market_value AS FLOAT)
          /NULLIF(total_portfolio_value,0)*100,2)                 AS sector_weight_pct,
    ROUND(sector_return_pct,2)                                   AS sector_return_pct,
    -- Contribution = weight × sector return
    ROUND(
        CAST(sector_market_value AS FLOAT)/NULLIF(total_portfolio_value,0)
        * sector_return_pct,
    2)                                                           AS sector_contribution_pct,
    -- Rank sectors by contribution
    RANK() OVER (
        PARTITION BY portfolio_id, date_key
        ORDER BY
            CAST(sector_market_value AS FLOAT)/NULLIF(total_portfolio_value,0)
            * sector_return_pct DESC
    )                                                            AS contribution_rank
FROM sector_weights;
GO
PRINT '✓ mart.v_portfolio_attribution created.';
GO

-- ── Stock Return Analytics View ───────────────────────────────
IF OBJECT_ID('mart.v_stock_return_analytics','V') IS NOT NULL DROP VIEW mart.v_stock_return_analytics;
GO
CREATE VIEW mart.v_stock_return_analytics AS
WITH price_series AS (
    SELECT
        c.ticker_symbol, c.company_name,
        i.gics_sector_name,
        sp.date_key, dd.full_date, dd.year_number,
        sp.adj_close_price,
        sp.market_cap_m,
        LAG(sp.adj_close_price) OVER (
            PARTITION BY sp.company_key ORDER BY sp.date_key) AS prior_price,
        FIRST_VALUE(sp.adj_close_price) OVER (
            PARTITION BY sp.company_key ORDER BY sp.date_key
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS inception_price,
        MIN(sp.adj_close_price) OVER (
            PARTITION BY sp.company_key) AS all_time_low,
        MAX(sp.adj_close_price) OVER (
            PARTITION BY sp.company_key) AS all_time_high
    FROM dw.fact_stock_price sp
    JOIN dw.dim_company  c  ON sp.company_key=c.company_key AND c.is_current=1
    JOIN dw.dim_industry i  ON c.industry_key=i.industry_key
    JOIN dw.dim_date     dd ON sp.date_key=dd.date_key
)
SELECT
    ticker_symbol, company_name, gics_sector_name,
    date_key, full_date, year_number,
    adj_close_price,
    ROUND(CAST(market_cap_m AS FLOAT)/1000,2)                    AS market_cap_bn,
    -- Annual return
    ROUND(
        (CAST(adj_close_price AS FLOAT) - CAST(prior_price AS FLOAT))
        / NULLIF(CAST(prior_price AS FLOAT),0) * 100, 2)         AS annual_return_pct,
    -- Cumulative return from first data point
    ROUND(
        (CAST(adj_close_price AS FLOAT) - CAST(inception_price AS FLOAT))
        / NULLIF(CAST(inception_price AS FLOAT),0) * 100, 1)     AS total_return_pct,
    -- $10,000 hypothetical investment
    ROUND(
        10000.0
        * CAST(adj_close_price AS FLOAT)
        / NULLIF(CAST(inception_price AS FLOAT),0), 2)            AS investment_value_usd,
    -- 52-week range context (using available data)
    ROUND(all_time_low,4)                                         AS data_period_low,
    ROUND(all_time_high,4)                                        AS data_period_high,
    ROUND(
        (CAST(adj_close_price AS FLOAT) - CAST(all_time_low AS FLOAT))
        / NULLIF(CAST(all_time_high AS FLOAT) - CAST(all_time_low AS FLOAT),0) * 100,
    1)                                                            AS pct_of_price_range,
    -- Relative performance vs sector
    ROUND(
        (CAST(adj_close_price AS FLOAT) - CAST(inception_price AS FLOAT))
        / NULLIF(CAST(inception_price AS FLOAT),0) * 100
        - AVG(
            (CAST(adj_close_price AS FLOAT) - CAST(inception_price AS FLOAT))
            / NULLIF(CAST(inception_price AS FLOAT),0) * 100
          ) OVER (PARTITION BY gics_sector_name, date_key),
    1)                                                            AS vs_sector_avg_pct
FROM price_series;
GO
PRINT '✓ mart.v_stock_return_analytics created.';
GO

-- ============================================================
-- MODULE 3 – ADDITIONAL STORED PROCEDURES
-- ============================================================

-- ── Portfolio Snapshot Procedure ─────────────────────────────
IF OBJECT_ID('mart.usp_portfolio_snapshot','P') IS NOT NULL DROP PROCEDURE mart.usp_portfolio_snapshot;
GO
CREATE PROCEDURE mart.usp_portfolio_snapshot
    @portfolio_id VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    PRINT '=== PORTFOLIO SNAPSHOT: ' + @portfolio_id + ' ===';

    -- 1. Holdings Summary
    PRINT '-- Holdings';
    SELECT portfolio_id, portfolio_name,
           ticker_symbol, company_name, gics_sector_name,
           shares_held, avg_cost_basis, market_price,
           market_value_m, unrealized_pnl_m,
           position_return_pct, portfolio_weight_pct,
           contribution_to_return_pct, position_status
    FROM mart.v_portfolio_performance
    WHERE portfolio_id=@portfolio_id
    ORDER BY market_value_m DESC;

    -- 2. Portfolio Totals
    PRINT '-- Portfolio Totals';
    SELECT DISTINCT
        portfolio_id, portfolio_name,
        portfolio_total_value_m,
        portfolio_total_cost_m,
        portfolio_total_pnl_m,
        portfolio_total_return_pct
    FROM mart.v_portfolio_performance
    WHERE portfolio_id=@portfolio_id;

    -- 3. Sector Attribution
    PRINT '-- Sector Attribution';
    SELECT portfolio_id, gics_sector_name,
           sector_value_m, sector_weight_pct,
           sector_return_pct, sector_contribution_pct,
           contribution_rank
    FROM mart.v_portfolio_attribution
    WHERE portfolio_id=@portfolio_id
    ORDER BY contribution_rank;
END;
GO
PRINT '✓ mart.usp_portfolio_snapshot created.';
GO

-- ── Economic Indicator Seed + View ───────────────────────────
IF NOT EXISTS (SELECT 1 FROM dw.fact_economic_indicator)
BEGIN
    INSERT INTO dw.fact_economic_indicator
        (country_key, date_key, indicator_code, indicator_name,
         indicator_value, unit, frequency, source)
    SELECT co.country_key, d.date_key,
           v.icode, v.iname, v.ival, v.unit, v.freq, v.src
    FROM (VALUES
    -- USA GDP Growth (FRED: A191RL1Q225SBEA)
    ('USA','GDP_GROWTH','Real GDP Growth Rate',CAST(2.3  AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20191231),
    ('USA','GDP_GROWTH','Real GDP Growth Rate',CAST(-3.4 AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20201231),
    ('USA','GDP_GROWTH','Real GDP Growth Rate',CAST(5.9  AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20211231),
    ('USA','GDP_GROWTH','Real GDP Growth Rate',CAST(2.1  AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20221231),
    ('USA','GDP_GROWTH','Real GDP Growth Rate',CAST(2.5  AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20231231),
    -- USA CPI Inflation
    ('USA','CPI_INFLATION','CPI Inflation Rate',CAST(2.3  AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20191231),
    ('USA','CPI_INFLATION','CPI Inflation Rate',CAST(1.2  AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20201231),
    ('USA','CPI_INFLATION','CPI Inflation Rate',CAST(4.7  AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20211231),
    ('USA','CPI_INFLATION','CPI Inflation Rate',CAST(8.0  AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20221231),
    ('USA','CPI_INFLATION','CPI Inflation Rate',CAST(4.1  AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20231231),
    -- USA Fed Funds Rate
    ('USA','FED_FUNDS_RATE','Federal Funds Rate',CAST(1.55 AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20191231),
    ('USA','FED_FUNDS_RATE','Federal Funds Rate',CAST(0.09 AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20201231),
    ('USA','FED_FUNDS_RATE','Federal Funds Rate',CAST(0.08 AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20211231),
    ('USA','FED_FUNDS_RATE','Federal Funds Rate',CAST(3.04 AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20221231),
    ('USA','FED_FUNDS_RATE','Federal Funds Rate',CAST(5.02 AS DECIMAL(20,6)),'Percent','ANNUAL','FRED',20231231),
    -- KEN GDP Growth (World Bank)
    ('KEN','GDP_GROWTH','Real GDP Growth Rate',CAST(5.4  AS DECIMAL(20,6)),'Percent','ANNUAL','WORLD_BANK',20191231),
    ('KEN','GDP_GROWTH','Real GDP Growth Rate',CAST(-0.3 AS DECIMAL(20,6)),'Percent','ANNUAL','WORLD_BANK',20201231),
    ('KEN','GDP_GROWTH','Real GDP Growth Rate',CAST(7.5  AS DECIMAL(20,6)),'Percent','ANNUAL','WORLD_BANK',20211231),
    ('KEN','GDP_GROWTH','Real GDP Growth Rate',CAST(4.8  AS DECIMAL(20,6)),'Percent','ANNUAL','WORLD_BANK',20221231),
    ('KEN','GDP_GROWTH','Real GDP Growth Rate',CAST(5.6  AS DECIMAL(20,6)),'Percent','ANNUAL','WORLD_BANK',20231231)
    ) v(ctry, icode, iname, ival, unit, freq, src, dk)
    JOIN dw.dim_country co ON co.country_id=v.ctry
    JOIN dw.dim_date     d ON d.date_key=v.dk;
    PRINT '✓ Economic indicator data seeded (20 rows).';
END
GO

-- ── Economic Context View ─────────────────────────────────────
IF OBJECT_ID('mart.v_economic_context','V') IS NOT NULL DROP VIEW mart.v_economic_context;
GO
CREATE VIEW mart.v_economic_context AS
SELECT
    co.country_name, co.currency_code,
    ei.indicator_code, ei.indicator_name,
    dd.year_number   AS fiscal_year,
    ei.indicator_value,
    ei.unit, ei.source,
    -- YoY change
    ROUND(
        CAST(ei.indicator_value AS FLOAT)
        - CAST(LAG(ei.indicator_value) OVER (
            PARTITION BY co.country_key, ei.indicator_code
            ORDER BY dd.year_number) AS FLOAT),
    2)               AS yoy_change,
    -- 3-year rolling average
    ROUND(AVG(CAST(ei.indicator_value AS FLOAT)) OVER (
        PARTITION BY co.country_key, ei.indicator_code
        ORDER BY dd.year_number
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
    2)               AS rolling_3yr_avg,
    -- Signal
    CASE ei.indicator_code
        WHEN 'GDP_GROWTH'    THEN CASE WHEN ei.indicator_value >= 3 THEN 'EXPANSION' WHEN ei.indicator_value >= 0 THEN 'SLOW' ELSE 'RECESSION' END
        WHEN 'CPI_INFLATION' THEN CASE WHEN ei.indicator_value <= 2.5 THEN 'STABLE'  WHEN ei.indicator_value <= 5 THEN 'ELEVATED' ELSE 'HIGH INFLATION' END
        WHEN 'FED_FUNDS_RATE' THEN CASE WHEN ei.indicator_value <= 2 THEN 'ACCOMMODATIVE' WHEN ei.indicator_value <= 4 THEN 'NEUTRAL' ELSE 'RESTRICTIVE' END
        ELSE 'N/A'
    END              AS economic_signal
FROM dw.fact_economic_indicator ei
JOIN dw.dim_country co ON ei.country_key=co.country_key
JOIN dw.dim_date    dd ON ei.date_key=dd.date_key;
GO
PRINT '✓ mart.v_economic_context created.';
GO

-- ── Exchange Rate Seed ────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dw.fact_exchange_rate)
BEGIN
    INSERT INTO dw.fact_exchange_rate
        (base_currency, quote_currency, date_key, spot_rate, source)
    VALUES
    ('USD','KES',20191231,CAST(101.50 AS DECIMAL(18,8)),'FRED'),
    ('USD','KES',20201231,CAST(109.20 AS DECIMAL(18,8)),'FRED'),
    ('USD','KES',20211231,CAST(113.00 AS DECIMAL(18,8)),'FRED'),
    ('USD','KES',20221231,CAST(123.40 AS DECIMAL(18,8)),'FRED'),
    ('USD','KES',20231231,CAST(156.45 AS DECIMAL(18,8)),'FRED'),
    ('USD','GBP',20191231,CAST(0.7530 AS DECIMAL(18,8)),'FRED'),
    ('USD','GBP',20201231,CAST(0.7320 AS DECIMAL(18,8)),'FRED'),
    ('USD','GBP',20211231,CAST(0.7380 AS DECIMAL(18,8)),'FRED'),
    ('USD','GBP',20221231,CAST(0.8300 AS DECIMAL(18,8)),'FRED'),
    ('USD','GBP',20231231,CAST(0.7880 AS DECIMAL(18,8)),'FRED'),
    ('USD','EUR',20191231,CAST(0.8910 AS DECIMAL(18,8)),'FRED'),
    ('USD','EUR',20201231,CAST(0.8170 AS DECIMAL(18,8)),'FRED'),
    ('USD','EUR',20211231,CAST(0.8830 AS DECIMAL(18,8)),'FRED'),
    ('USD','EUR',20221231,CAST(0.9350 AS DECIMAL(18,8)),'FRED'),
    ('USD','EUR',20231231,CAST(0.9060 AS DECIMAL(18,8)),'FRED');
    PRINT '✓ Exchange rate data seeded (15 rows).';
END
GO

-- ── Exchange Rate Trend View ──────────────────────────────────
IF OBJECT_ID('mart.v_exchange_rate_trends','V') IS NOT NULL DROP VIEW mart.v_exchange_rate_trends;
GO
CREATE VIEW mart.v_exchange_rate_trends AS
SELECT
    er.base_currency, er.quote_currency,
    dd.year_number,
    er.spot_rate,
    LAG(er.spot_rate) OVER (
        PARTITION BY er.base_currency, er.quote_currency
        ORDER BY dd.year_number)                                  AS prior_rate,
    ROUND(
        (CAST(er.spot_rate AS FLOAT)
         - CAST(LAG(er.spot_rate) OVER (
             PARTITION BY er.base_currency, er.quote_currency
             ORDER BY dd.year_number) AS FLOAT))
        / NULLIF(CAST(LAG(er.spot_rate) OVER (
             PARTITION BY er.base_currency, er.quote_currency
             ORDER BY dd.year_number) AS FLOAT),0) * 100,
    2)                                                            AS yoy_change_pct,
    AVG(CAST(er.spot_rate AS FLOAT)) OVER (
        PARTITION BY er.base_currency, er.quote_currency
        ORDER BY dd.year_number
        ROWS BETWEEN 4 PRECEDING AND CURRENT ROW)                AS rolling_5yr_avg_rate,
    CASE
        WHEN er.quote_currency='KES' AND er.spot_rate > 130 THEN 'KES WEAK'
        WHEN er.quote_currency='GBP' AND er.spot_rate > 0.82 THEN 'GBP STRONG'
        WHEN er.quote_currency='EUR' AND er.spot_rate > 0.92 THEN 'EUR STRONG'
        ELSE 'NORMAL RANGE'
    END                                                           AS fx_signal
FROM dw.fact_exchange_rate er
JOIN dw.dim_date dd ON er.date_key=dd.date_key;
GO
PRINT '✓ mart.v_exchange_rate_trends created.';
GO

-- ============================================================
-- FINAL COMPREHENSIVE VERIFICATION – ALL 5 PARTS COMBINED
-- ============================================================
PRINT '';
PRINT '==============================================';
PRINT ' PART 5 VERIFICATION – PORTFOLIO + MARKET DATA';
PRINT '==============================================';
GO

PRINT '-- 1. Stock Return Analytics';
SELECT ticker_symbol, company_name, full_date,
       adj_close_price, annual_return_pct,
       total_return_pct, investment_value_usd,
       vs_sector_avg_pct, pct_of_price_range
FROM mart.v_stock_return_analytics
ORDER BY ticker_symbol, date_key;
GO

PRINT '-- 2. Portfolio Performance (PORT-TECH)';
EXEC mart.usp_portfolio_snapshot @portfolio_id='PORT-TECH';
GO

PRINT '-- 3. Portfolio Performance (PORT-BLEND)';
EXEC mart.usp_portfolio_snapshot @portfolio_id='PORT-BLEND';
GO

PRINT '-- 4. Economic Context';
SELECT country_name, fiscal_year, indicator_name,
       indicator_value, unit, yoy_change,
       rolling_3yr_avg, economic_signal
FROM mart.v_economic_context
ORDER BY country_name, indicator_code, fiscal_year;
GO

PRINT '-- 5. FX Rate Trends';
SELECT base_currency, quote_currency, year_number,
       spot_rate, yoy_change_pct, rolling_5yr_avg_rate, fx_signal
FROM mart.v_exchange_rate_trends
ORDER BY quote_currency, year_number;
GO

PRINT '-- 6. All Portfolios Side-by-Side';
SELECT
    portfolio_id, portfolio_name,
    MIN(full_date)                                                AS as_of_date,
    SUM(market_value_m)                                          AS total_aum_m,
    SUM(unrealized_pnl_m)                                        AS total_pnl_m,
    MAX(portfolio_total_return_pct)                              AS total_return_pct,
    COUNT(DISTINCT ticker_symbol)                                 AS holdings_count
FROM mart.v_portfolio_performance
GROUP BY portfolio_id, portfolio_name
ORDER BY total_return_pct DESC;
GO

-- ============================================================
-- GRAND FINAL OBJECT COUNT – ALL 5 PARTS
-- ============================================================
PRINT '';
PRINT '==============================================';
PRINT ' GRAND FINAL – COMPLETE PORTFOLIO STATISTICS';
PRINT '==============================================';
GO

SELECT
    s.name           AS schema_name,
    COUNT(CASE WHEN o.type='U'            THEN 1 END) AS tables,
    COUNT(CASE WHEN o.type='V'            THEN 1 END) AS views,
    COUNT(CASE WHEN o.type='P'            THEN 1 END) AS stored_procedures,
    COUNT(CASE WHEN o.type IN('IF','TF')  THEN 1 END) AS functions,
    COUNT(CASE WHEN o.type='TR'           THEN 1 END) AS triggers
FROM sys.schemas s
LEFT JOIN sys.objects o ON s.schema_id=o.schema_id
    AND o.type IN ('U','V','P','IF','TF','TR')
WHERE s.name IN ('dw','mart','credit','forensic','fpa','treasury',
                 'market','esg','bi','governance','etl','audit')
GROUP BY s.name
ORDER BY s.name;
GO

SELECT 'TOTAL TABLES'       AS metric, COUNT(*) AS count FROM sys.tables     t JOIN sys.schemas s ON t.schema_id=s.schema_id WHERE s.name NOT IN ('sys','INFORMATION_SCHEMA') UNION ALL
SELECT 'TOTAL VIEWS',               COUNT(*) FROM sys.views      v JOIN sys.schemas s ON v.schema_id=s.schema_id WHERE s.name NOT IN ('sys','INFORMATION_SCHEMA') UNION ALL
SELECT 'TOTAL PROCEDURES',          COUNT(*) FROM sys.procedures p JOIN sys.schemas s ON p.schema_id=s.schema_id WHERE s.name NOT IN ('sys','INFORMATION_SCHEMA') UNION ALL
SELECT 'TOTAL FUNCTIONS',           COUNT(*) FROM sys.objects o  JOIN sys.schemas s ON o.schema_id=s.schema_id WHERE o.type IN ('IF','TF') AND s.name NOT IN ('sys','INFORMATION_SCHEMA') UNION ALL
SELECT 'TOTAL TRIGGERS',            COUNT(*) FROM sys.triggers  tr JOIN sys.objects o ON tr.object_id=o.object_id JOIN sys.schemas s ON o.schema_id=s.schema_id WHERE s.name NOT IN ('sys','INFORMATION_SCHEMA') UNION ALL
SELECT 'TOTAL INDEXES',             COUNT(*) FROM sys.indexes    i JOIN sys.tables  t ON i.object_id=t.object_id JOIN sys.schemas s ON t.schema_id=s.schema_id WHERE i.type>0 AND s.name NOT IN ('sys','INFORMATION_SCHEMA');
GO

PRINT '';
PRINT '==============================================';
PRINT ' COMPLETE RUN ORDER IN SSMS:';
PRINT '  1. COMPLETE_PORTFOLIO_SQLSERVER.sql';
PRINT '  2. PORTFOLIO_ANALYTICS_PART2.sql';
PRINT '  3. PORTFOLIO_PART3_FINAL.sql';
PRINT '  4. PORTFOLIO_PART4_INTERVIEW_README.sql';
PRINT '  5. PORTFOLIO_PART5_STOCK_DATA_VIEWS.sql  <- THIS FILE';
PRINT '';
PRINT ' Quick test after all 5 parts:';
PRINT '  SELECT * FROM mart.v_financial_ratios;';
PRINT '  SELECT * FROM bi.v_executive_scorecard;';
PRINT '  SELECT * FROM credit.v_risk_dashboard;';
PRINT '  SELECT * FROM esg.v_esg_scores;';
PRINT '  SELECT * FROM mart.v_portfolio_performance;';
PRINT '  SELECT * FROM forensic.v_expense_anomalies;';
PRINT '  SELECT * FROM governance.v_platform_health;';
PRINT '  EXEC dw.fn_validate_warehouse;';
PRINT '==============================================';
GO

