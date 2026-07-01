
-- ============================================================
-- INSTITUTIONAL SQL BUSINESS ANALYTICS PORTFOLIO
-- Engine  : SQL Server 2017 Express + SSMS
-- Version : 2.0 COMPLETE (all bugs fixed)
-- Run     : Open in SSMS → F5 (entire file)
-- Time    : ~3-5 minutes (dim_date loop is the slow part)
-- ============================================================

USE master;
GO

-- ============================================================
-- STEP 1 – DATABASE
-- ============================================================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'FinancePortfolio')
BEGIN
    CREATE DATABASE FinancePortfolio;
    PRINT '✓ Database FinancePortfolio created.';
END
ELSE
    PRINT '✓ Database FinancePortfolio already exists.';
GO

USE FinancePortfolio;
GO

-- ============================================================
-- STEP 2 – SCHEMAS
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='dw')        EXEC('CREATE SCHEMA dw');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='staging')   EXEC('CREATE SCHEMA staging');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='mart')      EXEC('CREATE SCHEMA mart');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='audit')     EXEC('CREATE SCHEMA audit');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='credit')    EXEC('CREATE SCHEMA credit');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='forensic')  EXEC('CREATE SCHEMA forensic');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='fpa')       EXEC('CREATE SCHEMA fpa');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='treasury')  EXEC('CREATE SCHEMA treasury');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='market')    EXEC('CREATE SCHEMA market');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='esg')       EXEC('CREATE SCHEMA esg');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='bi')        EXEC('CREATE SCHEMA bi');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='etl')       EXEC('CREATE SCHEMA etl');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='governance')EXEC('CREATE SCHEMA governance');
GO
PRINT '✓ All 13 schemas ready.';
GO

-- ============================================================
-- STEP 3 – DIMENSION TABLES
-- ============================================================

-- ── dim_date ─────────────────────────────────────────────────
IF OBJECT_ID('dw.dim_date','U') IS NULL
BEGIN
    CREATE TABLE dw.dim_date (
        date_key        INT         NOT NULL PRIMARY KEY,
        full_date       DATE        NOT NULL UNIQUE,
        day_of_week     SMALLINT,
        day_name        VARCHAR(10),
        day_of_month    SMALLINT,
        day_of_year     SMALLINT,
        week_of_year    SMALLINT,
        month_number    SMALLINT,
        month_name      VARCHAR(10),
        quarter_number  SMALLINT,
        quarter_name    VARCHAR(6),
        year_number     SMALLINT,
        is_weekend      BIT,
        is_month_end    BIT,
        is_quarter_end  BIT,
        is_year_end     BIT,
        fiscal_year     SMALLINT,
        fiscal_quarter  SMALLINT,
        fiscal_period   SMALLINT
    );
    PRINT '✓ dw.dim_date created.';
END
GO

-- Populate dim_date 2010-2030 (WHILE loop – T-SQL has no GENERATE_SERIES)
DECLARE @d DATE = '2010-01-01', @end DATE = '2030-12-31';
WHILE @d <= @end
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dw.dim_date WHERE full_date = @d)
        INSERT INTO dw.dim_date VALUES (
            CAST(FORMAT(@d,'yyyyMMdd') AS INT), @d,
            DATEPART(WEEKDAY,@d), DATENAME(WEEKDAY,@d),
            DAY(@d), DATEPART(DAYOFYEAR,@d), DATEPART(WEEK,@d),
            MONTH(@d), DATENAME(MONTH,@d),
            DATEPART(QUARTER,@d), 'Q'+CAST(DATEPART(QUARTER,@d) AS VARCHAR),
            YEAR(@d),
            CASE WHEN DATEPART(WEEKDAY,@d) IN (1,7) THEN 1 ELSE 0 END,
            CASE WHEN @d = EOMONTH(@d) THEN 1 ELSE 0 END,
            CASE WHEN @d = EOMONTH(DATEADD(MONTH, 3-((MONTH(@d)-1)%3), @d)) THEN 1 ELSE 0 END,
            CASE WHEN MONTH(@d)=12 AND DAY(@d)=31 THEN 1 ELSE 0 END,
            CASE WHEN MONTH(@d)>=4 THEN YEAR(@d) ELSE YEAR(@d)-1 END,
            CASE WHEN MONTH(@d) BETWEEN 4  AND 6  THEN 1
                 WHEN MONTH(@d) BETWEEN 7  AND 9  THEN 2
                 WHEN MONTH(@d) BETWEEN 10 AND 12 THEN 3
                 ELSE 4 END,
            CASE WHEN MONTH(@d)>=4 THEN MONTH(@d)-3 ELSE MONTH(@d)+9 END
        );
    SET @d = DATEADD(DAY,1,@d);
END
PRINT '✓ dw.dim_date populated 2010-2030 (7,670 rows).';
GO

-- ── dim_country ───────────────────────────────────────────────
IF OBJECT_ID('dw.dim_country','U') IS NULL
BEGIN
    CREATE TABLE dw.dim_country (
        country_key     INT           IDENTITY(1,1) PRIMARY KEY,
        country_id      CHAR(3)       NOT NULL UNIQUE,
        country_name    NVARCHAR(100) NOT NULL,
        region          NVARCHAR(60),
        sub_region      NVARCHAR(60),
        currency_code   CHAR(3),
        currency_name   NVARCHAR(50),
        gdp_usd_bn      DECIMAL(18,2),
        scd_start_date  DATE          NOT NULL DEFAULT CAST(GETDATE() AS DATE),
        scd_end_date    DATE,
        is_current      BIT           NOT NULL DEFAULT 1,
        created_at      DATETIME2     DEFAULT GETDATE()
    );
    INSERT INTO dw.dim_country (country_id,country_name,region,sub_region,currency_code,currency_name,gdp_usd_bn,scd_start_date,is_current)
    VALUES
    ('USA','United States','Americas','Northern America','USD','US Dollar',27360.90,'2010-01-01',1),
    ('GBR','United Kingdom','Europe','Northern Europe','GBP','Pound Sterling',3089.07,'2010-01-01',1),
    ('DEU','Germany','Europe','Western Europe','EUR','Euro',4457.30,'2010-01-01',1),
    ('JPN','Japan','Asia','Eastern Asia','JPY','Japanese Yen',4212.94,'2010-01-01',1),
    ('KEN','Kenya','Africa','Eastern Africa','KES','Kenyan Shilling',106.00,'2010-01-01',1),
    ('CHN','China','Asia','Eastern Asia','CNY','Chinese Renminbi',18532.63,'2010-01-01',1),
    ('IND','India','Asia','Southern Asia','INR','Indian Rupee',3736.88,'2010-01-01',1),
    ('FRA','France','Europe','Western Europe','EUR','Euro',3049.02,'2010-01-01',1),
    ('CAN','Canada','Americas','Northern America','CAD','Canadian Dollar',2139.84,'2010-01-01',1),
    ('AUS','Australia','Oceania','Australia and NZ','AUD','Australian Dollar',1723.83,'2010-01-01',1);
    PRINT '✓ dw.dim_country created and seeded (10 rows).';
END
GO

-- ── dim_industry ──────────────────────────────────────────────
IF OBJECT_ID('dw.dim_industry','U') IS NULL
BEGIN
    CREATE TABLE dw.dim_industry (
        industry_key              INT         IDENTITY(1,1) PRIMARY KEY,
        gics_sector_code          CHAR(2)     NOT NULL,
        gics_sector_name          VARCHAR(80) NOT NULL,
        gics_industry_group_code  CHAR(4),
        gics_industry_group_name  VARCHAR(100),
        gics_industry_code        CHAR(6),
        gics_industry_name        VARCHAR(100),
        gics_sub_industry_code    CHAR(8),
        gics_sub_industry_name    VARCHAR(150),
        is_active                 BIT         DEFAULT 1
    );
    INSERT INTO dw.dim_industry
        (gics_sector_code,gics_sector_name,gics_industry_group_code,
         gics_industry_group_name,gics_industry_code,gics_industry_name,
         gics_sub_industry_code,gics_sub_industry_name)
    VALUES
    ('10','Energy','1010','Energy','101020','Oil Gas Fuels','10102010','Integrated Oil & Gas'),
    ('20','Industrials','2010','Capital Goods','201010','Aerospace Defense','20101010','Aerospace & Defense'),
    ('25','Consumer Discretionary','2510','Automobiles','251010','Auto Components','25101010','Auto Parts'),
    ('30','Consumer Staples','3010','Food Retailing','301010','Food Retailing','30101010','Drug Retail'),
    ('35','Health Care','3510','HC Equipment','351010','HC Equipment','35101010','HC Equipment'),
    ('40','Financials','4010','Banks','401010','Banks','40101010','Diversified Banks'),
    ('40','Financials','4020','Div Financials','402010','Capital Markets','40201020','Investment Banking'),
    ('45','Information Technology','4510','Software Svcs','451020','Software','45102030','Application Software'),
    ('50','Communication Services','5010','Telecom Svcs','501010','Diversified Telecom','50101010','Alt Carriers'),
    ('55','Utilities','5510','Utilities','551010','Electric Utilities','55101010','Electric Utilities'),
    ('60','Real Estate','6010','Real Estate','601010','Equity REITs','60101010','Diversified REITs');
    PRINT '✓ dw.dim_industry created and seeded (11 rows).';
END
GO

-- ── dim_company ───────────────────────────────────────────────
IF OBJECT_ID('dw.dim_company','U') IS NULL
BEGIN
    CREATE TABLE dw.dim_company (
        company_key           INT           IDENTITY(1,1) PRIMARY KEY,
        company_id            VARCHAR(20)   NOT NULL UNIQUE,
        ticker_symbol         VARCHAR(12)   NOT NULL,
        company_name          NVARCHAR(200) NOT NULL,
        exchange_code         VARCHAR(10),
        industry_key          INT           REFERENCES dw.dim_industry(industry_key),
        country_key           INT           REFERENCES dw.dim_country(country_key),
        sec_cik               VARCHAR(20),
        isin                  CHAR(12),
        founded_year          SMALLINT,
        fiscal_year_end_month SMALLINT,
        reporting_currency    CHAR(3),
        employee_count        INT,
        is_sp500              BIT           DEFAULT 0,
        is_ftse100            BIT           DEFAULT 0,
        is_nse20              BIT           DEFAULT 0,
        market_cap_usd_m      DECIMAL(20,4),
        scd_start_date        DATE          NOT NULL DEFAULT CAST(GETDATE() AS DATE),
        scd_end_date          DATE,
        is_current            BIT           NOT NULL DEFAULT 1,
        created_at            DATETIME2     DEFAULT GETDATE(),
        updated_at            DATETIME2     DEFAULT GETDATE()
    );
    INSERT INTO dw.dim_company
        (company_id,ticker_symbol,company_name,exchange_code,sec_cik,isin,
         founded_year,fiscal_year_end_month,reporting_currency,is_sp500,scd_start_date,is_current)
    VALUES
    ('AAPL-US','AAPL','Apple Inc.','NASDAQ','0000320193','US0378331005',1976,9,'USD',1,'2010-01-01',1),
    ('MSFT-US','MSFT','Microsoft Corporation','NASDAQ','0000789019','US5949181045',1975,6,'USD',1,'2010-01-01',1),
    ('GOOGL-US','GOOGL','Alphabet Inc.','NASDAQ','0001652044','US02079K3059',1998,12,'USD',1,'2010-01-01',1),
    ('AMZN-US','AMZN','Amazon.com Inc.','NASDAQ','0001018724','US0231351067',1994,12,'USD',1,'2010-01-01',1),
    ('JPM-US','JPM','JPMorgan Chase & Co.','NYSE','0000019617','US46625H1005',1799,12,'USD',1,'2010-01-01',1),
    ('HSBA-GB','HSBA','HSBC Holdings PLC','LSE','0001089113','GB0005405286',1865,12,'USD',1,'2010-01-01',1),
    ('EQTY-KE','EQTY','Equity Group Holdings','NSE',NULL,'KE1000001492',1984,12,'KES',0,'2010-01-01',1),
    ('SAFCOM-KE','SCOM','Safaricom PLC','NSE',NULL,'KE1000000077',1997,3,'KES',0,'2010-01-01',1),
    ('BRK-US','BRK.B','Berkshire Hathaway Inc.','NYSE','0001067983','US0846707026',1839,12,'USD',1,'2010-01-01',1),
    ('VOD-GB','VOD','Vodafone Group PLC','LSE','0001089872','GB00BH4HKS39',1984,3,'EUR',0,'2010-01-01',1);
    PRINT '✓ dw.dim_company created and seeded (10 rows).';
END
GO

-- ── dim_company: backfill industry_key / country_key ─────────
-- BUGFIX (post-deployment audit): the original seed INSERT above
-- never populated industry_key or country_key, which are NULLable
-- foreign keys. Every downstream view that INNER JOINs dim_industry
-- or dim_country (v_financial_ratios, v_executive_scorecard,
-- v_esg_scores, v_ranking_engine, v_portfolio_performance,
-- v_stock_return_analytics, v_enterprise_company_360 — 7 views in
-- total) silently returned 0 rows as a result. This block is
-- idempotent and safe to re-run.
UPDATE c
SET c.industry_key = i.industry_key
FROM dw.dim_company c
CROSS APPLY (VALUES
    ('AAPL-US',  '45'),  -- Information Technology
    ('MSFT-US',  '45'),  -- Information Technology
    ('GOOGL-US', '50'),  -- Communication Services
    ('AMZN-US',  '25'),  -- Consumer Discretionary
    ('JPM-US',   '40'),  -- Financials (Banks)
    ('HSBA-GB',  '40'),  -- Financials (Banks)
    ('EQTY-KE',  '40'),  -- Financials (Banks)
    ('SAFCOM-KE','50'),  -- Communication Services
    ('BRK-US',   '40'),  -- Financials
    ('VOD-GB',   '50')   -- Communication Services
) v(company_id, sector_code)
JOIN dw.dim_industry i
    ON i.gics_sector_code = v.sector_code
WHERE c.company_id = v.company_id
  AND c.industry_key IS NULL;

UPDATE c
SET c.country_key = co.country_key
FROM dw.dim_company c
CROSS APPLY (VALUES
    ('AAPL-US',  'USA'),
    ('MSFT-US',  'USA'),
    ('GOOGL-US', 'USA'),
    ('AMZN-US',  'USA'),
    ('JPM-US',   'USA'),
    ('HSBA-GB',  'GBR'),
    ('EQTY-KE',  'KEN'),
    ('SAFCOM-KE','KEN'),
    ('BRK-US',   'USA'),
    ('VOD-GB',   'GBR')
) v(company_id, country_id)
JOIN dw.dim_country co
    ON co.country_id = v.country_id
WHERE c.company_id = v.company_id
  AND c.country_key IS NULL;

PRINT '✓ dw.dim_company backfilled with industry_key / country_key (fixes 7 dependent views).';
GO

-- ── dim_account (Chart of Accounts) ──────────────────────────
IF OBJECT_ID('dw.dim_account','U') IS NULL
BEGIN
    CREATE TABLE dw.dim_account (
        account_key         INT         IDENTITY(1,1) PRIMARY KEY,
        account_code        VARCHAR(20) NOT NULL UNIQUE,
        account_name        VARCHAR(150) NOT NULL,
        account_type        VARCHAR(30) NOT NULL,
        account_subtype     VARCHAR(60),
        financial_statement VARCHAR(20),
        normal_balance      CHAR(6),
        is_active           BIT         DEFAULT 1,
        sort_order          INT
    );
    INSERT INTO dw.dim_account
        (account_code,account_name,account_type,account_subtype,financial_statement,normal_balance,sort_order)
    VALUES
    ('1000','Total Assets','ASSET','Total','BS','DEBIT',100),
    ('1110','Cash and Cash Equivalents','ASSET','Cash','BS','DEBIT',111),
    ('1130','Accounts Receivable Net','ASSET','Receivable','BS','DEBIT',113),
    ('1140','Inventories','ASSET','Inventory','BS','DEBIT',114),
    ('1210','Property Plant Equipment Net','ASSET','PP&E','BS','DEBIT',121),
    ('1220','Intangible Assets Net','ASSET','Intangible','BS','DEBIT',122),
    ('1230','Goodwill','ASSET','Goodwill','BS','DEBIT',123),
    ('2000','Total Liabilities','LIABILITY','Total','BS','CREDIT',200),
    ('2110','Accounts Payable','LIABILITY','Payable','BS','CREDIT',211),
    ('2120','Short Term Debt','LIABILITY','Debt','BS','CREDIT',212),
    ('2210','Long Term Debt','LIABILITY','Debt','BS','CREDIT',221),
    ('3000','Total Stockholders Equity','EQUITY','Total','BS','CREDIT',300),
    ('3030','Retained Earnings','EQUITY','Retained','BS','CREDIT',303),
    ('4000','Total Revenue','REVENUE','Total','IS','CREDIT',400),
    ('4010','Product Revenue','REVENUE','Product','IS','CREDIT',401),
    ('4020','Service Revenue','REVENUE','Service','IS','CREDIT',402),
    ('5000','Cost of Revenue','EXPENSE','COGS','IS','DEBIT',500),
    ('6010','Research and Development','EXPENSE','R&D','IS','DEBIT',601),
    ('6020','Sales General Administrative','EXPENSE','SG&A','IS','DEBIT',602),
    ('6030','Depreciation Amortization','EXPENSE','D&A','IS','DEBIT',603),
    ('7010','Interest Expense','EXPENSE','Interest','IS','DEBIT',701),
    ('7020','Interest Income','REVENUE','Interest','IS','CREDIT',702),
    ('8000','Income Tax Expense','EXPENSE','Tax','IS','DEBIT',800),
    ('9000','Net Income','EQUITY','Net Income','IS','CREDIT',900);
    PRINT '✓ dw.dim_account created and seeded (24 rows).';
END
GO

-- ============================================================
-- STEP 4 – FACT TABLES
-- ============================================================

-- ── fact_income_statement ─────────────────────────────────────
IF OBJECT_ID('dw.fact_income_statement','U') IS NULL
BEGIN
    CREATE TABLE dw.fact_income_statement (
        income_stmt_key           BIGINT        IDENTITY(1,1) PRIMARY KEY,
        company_key               INT           NOT NULL REFERENCES dw.dim_company(company_key),
        date_key                  INT           NOT NULL REFERENCES dw.dim_date(date_key),
        period_type               VARCHAR(10)   NOT NULL,
        fiscal_year               SMALLINT      NOT NULL,
        fiscal_quarter            SMALLINT,
        total_revenue             DECIMAL(20,4),
        product_revenue           DECIMAL(20,4),
        service_revenue           DECIMAL(20,4),
        cost_of_revenue           DECIMAL(20,4),
        -- Computed column: gross profit
        gross_profit              AS (ISNULL(total_revenue,0) - ISNULL(cost_of_revenue,0)),
        research_development      DECIMAL(20,4),
        selling_general_admin     DECIMAL(20,4),
        depreciation_amortization DECIMAL(20,4),
        total_operating_expenses  DECIMAL(20,4),
        operating_income          DECIMAL(20,4),
        interest_expense          DECIMAL(20,4),
        interest_income           DECIMAL(20,4),
        ebt                       DECIMAL(20,4),
        income_tax_expense        DECIMAL(20,4),
        net_income                DECIMAL(20,4),
        eps_basic                 DECIMAL(12,6),
        eps_diluted               DECIMAL(12,6),
        shares_basic_m            DECIMAL(16,4),
        shares_diluted_m          DECIMAL(16,4),
        data_source               VARCHAR(50)   DEFAULT 'SEC_EDGAR',
        filing_date               DATE,
        restatement_flag          BIT           DEFAULT 0,
        created_at                DATETIME2     DEFAULT GETDATE()
    );
    PRINT '✓ dw.fact_income_statement created.';
END
GO

-- ── fact_balance_sheet ────────────────────────────────────────
IF OBJECT_ID('dw.fact_balance_sheet','U') IS NULL
BEGIN
    CREATE TABLE dw.fact_balance_sheet (
        balance_sheet_key             BIGINT       IDENTITY(1,1) PRIMARY KEY,
        company_key                   INT          NOT NULL REFERENCES dw.dim_company(company_key),
        date_key                      INT          NOT NULL REFERENCES dw.dim_date(date_key),
        period_type                   VARCHAR(10)  NOT NULL,
        fiscal_year                   SMALLINT     NOT NULL,
        fiscal_quarter                SMALLINT,
        -- Current Assets
        cash_equivalents              DECIMAL(20,4),
        short_term_investments        DECIMAL(20,4),
        accounts_receivable_net       DECIMAL(20,4),
        inventories                   DECIMAL(20,4),
        prepaid_other_current         DECIMAL(20,4),
        total_current_assets          DECIMAL(20,4),
        -- Non-Current Assets
        ppe_net                       DECIMAL(20,4),
        intangible_assets_net         DECIMAL(20,4),
        goodwill                      DECIMAL(20,4),
        long_term_investments         DECIMAL(20,4),
        total_non_current_assets      DECIMAL(20,4),
        total_assets                  DECIMAL(20,4),
        -- Current Liabilities
        accounts_payable              DECIMAL(20,4),
        short_term_debt               DECIMAL(20,4),
        accrued_liabilities           DECIMAL(20,4),
        total_current_liabilities     DECIMAL(20,4),
        -- Non-Current Liabilities
        long_term_debt                DECIMAL(20,4),
        total_non_current_liabilities DECIMAL(20,4),
        total_liabilities             DECIMAL(20,4),
        -- Equity
        common_stock                  DECIMAL(20,4),
        retained_earnings             DECIMAL(20,4),
        total_equity                  DECIMAL(20,4),
        total_liabilities_equity      DECIMAL(20,4),
        minority_interest             DECIMAL(20,4),
        -- Computed columns
        net_debt AS (
            ISNULL(short_term_debt,0) + ISNULL(long_term_debt,0)
            - ISNULL(cash_equivalents,0) - ISNULL(short_term_investments,0)
        ),
        working_capital AS (
            ISNULL(total_current_assets,0) - ISNULL(total_current_liabilities,0)
        ),
        data_source  VARCHAR(50)  DEFAULT 'SEC_EDGAR',
        filing_date  DATE,
        created_at   DATETIME2    DEFAULT GETDATE()
    );
    PRINT '✓ dw.fact_balance_sheet created.';
END
GO

-- ── fact_cash_flow ────────────────────────────────────────────
IF OBJECT_ID('dw.fact_cash_flow','U') IS NULL
BEGIN
    CREATE TABLE dw.fact_cash_flow (
        cash_flow_key                BIGINT      IDENTITY(1,1) PRIMARY KEY,
        company_key                  INT         NOT NULL REFERENCES dw.dim_company(company_key),
        date_key                     INT         NOT NULL REFERENCES dw.dim_date(date_key),
        period_type                  VARCHAR(10) NOT NULL,
        fiscal_year                  SMALLINT    NOT NULL,
        fiscal_quarter               SMALLINT,
        net_income_cf                DECIMAL(20,4),
        depreciation_amortization_cf DECIMAL(20,4),
        stock_compensation_cf        DECIMAL(20,4),
        changes_working_capital      DECIMAL(20,4),
        cash_from_operations         DECIMAL(20,4),
        capital_expenditures         DECIMAL(20,4),
        acquisitions_net             DECIMAL(20,4),
        cash_from_investing          DECIMAL(20,4),
        debt_repayment               DECIMAL(20,4),
        common_stock_repurchased     DECIMAL(20,4),
        dividends_paid               DECIMAL(20,4),
        cash_from_financing          DECIMAL(20,4),
        net_change_in_cash           DECIMAL(20,4),
        cash_beginning               DECIMAL(20,4),
        cash_ending                  DECIMAL(20,4),
        -- Computed: Free Cash Flow = CFO + CapEx (CapEx is negative)
        free_cash_flow AS (
            ISNULL(cash_from_operations,0) + ISNULL(capital_expenditures,0)
        ),
        data_source  VARCHAR(50) DEFAULT 'SEC_EDGAR',
        filing_date  DATE,
        created_at   DATETIME2  DEFAULT GETDATE()
    );
    PRINT '✓ dw.fact_cash_flow created.';
END
GO

-- ── fact_stock_price ──────────────────────────────────────────
IF OBJECT_ID('dw.fact_stock_price','U') IS NULL
BEGIN
    CREATE TABLE dw.fact_stock_price (
        stock_price_key      BIGINT        IDENTITY(1,1) PRIMARY KEY,
        company_key          INT           NOT NULL REFERENCES dw.dim_company(company_key),
        date_key             INT           NOT NULL REFERENCES dw.dim_date(date_key),
        open_price           DECIMAL(14,4),
        high_price           DECIMAL(14,4),
        low_price            DECIMAL(14,4),
        close_price          DECIMAL(14,4) NOT NULL,
        adj_close_price      DECIMAL(14,4),
        volume               BIGINT,
        market_cap_m         DECIMAL(20,4),
        shares_outstanding_m DECIMAL(16,4),
        split_factor         DECIMAL(8,4)  DEFAULT 1.0,
        dividend_amount      DECIMAL(12,6) DEFAULT 0,
        data_source          VARCHAR(30),
        created_at           DATETIME2     DEFAULT GETDATE(),
        CONSTRAINT UQ_stock_price UNIQUE (company_key, date_key)
    );
    PRINT '✓ dw.fact_stock_price created.';
END
GO

-- ── fact_exchange_rate ────────────────────────────────────────
IF OBJECT_ID('dw.fact_exchange_rate','U') IS NULL
BEGIN
    CREATE TABLE dw.fact_exchange_rate (
        exchange_rate_key BIGINT        IDENTITY(1,1) PRIMARY KEY,
        base_currency     CHAR(3)       NOT NULL,
        quote_currency    CHAR(3)       NOT NULL,
        date_key          INT           NOT NULL REFERENCES dw.dim_date(date_key),
        spot_rate         DECIMAL(18,8) NOT NULL,
        bid_rate          DECIMAL(18,8),
        ask_rate          DECIMAL(18,8),
        source            VARCHAR(30)   DEFAULT 'FRED',
        created_at        DATETIME2     DEFAULT GETDATE(),
        CONSTRAINT UQ_fx_rate UNIQUE (base_currency, quote_currency, date_key)
    );
    PRINT '✓ dw.fact_exchange_rate created.';
END
GO

-- ── fact_economic_indicator ───────────────────────────────────
IF OBJECT_ID('dw.fact_economic_indicator','U') IS NULL
BEGIN
    CREATE TABLE dw.fact_economic_indicator (
        econ_key        BIGINT       IDENTITY(1,1) PRIMARY KEY,
        country_key     INT          NOT NULL REFERENCES dw.dim_country(country_key),
        date_key        INT          NOT NULL REFERENCES dw.dim_date(date_key),
        indicator_code  VARCHAR(30)  NOT NULL,
        indicator_name  VARCHAR(150) NOT NULL,
        indicator_value DECIMAL(20,6),
        unit            VARCHAR(40),
        frequency       VARCHAR(20),
        source          VARCHAR(30),
        created_at      DATETIME2    DEFAULT GETDATE()
    );
    PRINT '✓ dw.fact_economic_indicator created.';
END
GO

-- ============================================================
-- STEP 5 – SEED FINANCIAL DATA (SEC EDGAR – USD millions)
-- Apple FY2019-2023, Microsoft FY2019-2023, JPMorgan FY2019-2023
-- ============================================================

-- Income Statements
IF NOT EXISTS (SELECT 1 FROM dw.fact_income_statement WHERE fiscal_year=2019)
BEGIN
    INSERT INTO dw.fact_income_statement
        (company_key,date_key,period_type,fiscal_year,
         total_revenue,cost_of_revenue,research_development,
         selling_general_admin,depreciation_amortization,
         operating_income,interest_expense,income_tax_expense,
         net_income,eps_diluted,shares_diluted_m,data_source,filing_date)
    SELECT c.company_key, d.date_key,
           v.pt, v.fy, v.rev, v.cogs, v.rd, v.sga, v.da,
           v.oi, v.ie, v.tax, v.ni, v.eps, v.shr,
           'SEC_EDGAR', v.fd
    FROM (VALUES
    -- AAPL: fiscal year ends in September; map to Dec 31 of same calendar year for date_key
    ('AAPL','ANNUAL',2019,CAST(260174 AS DECIMAL(20,4)),CAST(161782 AS DECIMAL(20,4)),CAST(16217 AS DECIMAL(20,4)),CAST(18245 AS DECIMAL(20,4)),CAST(12547 AS DECIMAL(20,4)),CAST(63930 AS DECIMAL(20,4)),CAST(-3576 AS DECIMAL(20,4)),CAST(10481 AS DECIMAL(20,4)),CAST(55256 AS DECIMAL(20,4)),CAST(11.89 AS DECIMAL(12,6)),CAST(4648 AS DECIMAL(16,4)),CAST('2019-10-31' AS DATE)),
    ('AAPL','ANNUAL',2020,CAST(274515 AS DECIMAL(20,4)),CAST(169559 AS DECIMAL(20,4)),CAST(18752 AS DECIMAL(20,4)),CAST(19916 AS DECIMAL(20,4)),CAST(11056 AS DECIMAL(20,4)),CAST(66288 AS DECIMAL(20,4)),CAST(-2873 AS DECIMAL(20,4)),CAST(9680  AS DECIMAL(20,4)),CAST(57411 AS DECIMAL(20,4)),CAST(12.73 AS DECIMAL(12,6)),CAST(4501 AS DECIMAL(16,4)),CAST('2020-10-29' AS DATE)),
    ('AAPL','ANNUAL',2021,CAST(365817 AS DECIMAL(20,4)),CAST(212981 AS DECIMAL(20,4)),CAST(21914 AS DECIMAL(20,4)),CAST(21973 AS DECIMAL(20,4)),CAST(11284 AS DECIMAL(20,4)),CAST(108949 AS DECIMAL(20,4)),CAST(-2645 AS DECIMAL(20,4)),CAST(14527 AS DECIMAL(20,4)),CAST(94680 AS DECIMAL(20,4)),CAST(21.32 AS DECIMAL(12,6)),CAST(4440 AS DECIMAL(16,4)),CAST('2021-10-28' AS DATE)),
    ('AAPL','ANNUAL',2022,CAST(394328 AS DECIMAL(20,4)),CAST(223546 AS DECIMAL(20,4)),CAST(26251 AS DECIMAL(20,4)),CAST(25094 AS DECIMAL(20,4)),CAST(11104 AS DECIMAL(20,4)),CAST(119437 AS DECIMAL(20,4)),CAST(-2828 AS DECIMAL(20,4)),CAST(19300 AS DECIMAL(20,4)),CAST(99803 AS DECIMAL(20,4)),CAST(23.22 AS DECIMAL(12,6)),CAST(4298 AS DECIMAL(16,4)),CAST('2022-10-27' AS DATE)),
    ('AAPL','ANNUAL',2023,CAST(383285 AS DECIMAL(20,4)),CAST(214137 AS DECIMAL(20,4)),CAST(29915 AS DECIMAL(20,4)),CAST(24932 AS DECIMAL(20,4)),CAST(11519 AS DECIMAL(20,4)),CAST(114301 AS DECIMAL(20,4)),CAST(-3933 AS DECIMAL(20,4)),CAST(29749 AS DECIMAL(20,4)),CAST(96995 AS DECIMAL(20,4)),CAST(24.23 AS DECIMAL(12,6)),CAST(4004 AS DECIMAL(16,4)),CAST('2023-11-02' AS DATE)),
    -- MSFT
    ('MSFT','ANNUAL',2019,CAST(125843 AS DECIMAL(20,4)),CAST(42910  AS DECIMAL(20,4)),CAST(16876 AS DECIMAL(20,4)),CAST(24709 AS DECIMAL(20,4)),CAST(12513 AS DECIMAL(20,4)),CAST(35058  AS DECIMAL(20,4)),CAST(-2686 AS DECIMAL(20,4)),CAST(4448  AS DECIMAL(20,4)),CAST(39240 AS DECIMAL(20,4)),CAST(5.06  AS DECIMAL(12,6)),CAST(7755 AS DECIMAL(16,4)),CAST('2019-07-31' AS DATE)),
    ('MSFT','ANNUAL',2020,CAST(143015 AS DECIMAL(20,4)),CAST(46078  AS DECIMAL(20,4)),CAST(19269 AS DECIMAL(20,4)),CAST(24709 AS DECIMAL(20,4)),CAST(12796 AS DECIMAL(20,4)),CAST(52959  AS DECIMAL(20,4)),CAST(-2591 AS DECIMAL(20,4)),CAST(8755  AS DECIMAL(20,4)),CAST(44281 AS DECIMAL(20,4)),CAST(5.76  AS DECIMAL(12,6)),CAST(7683 AS DECIMAL(16,4)),CAST('2020-07-29' AS DATE)),
    ('MSFT','ANNUAL',2021,CAST(168088 AS DECIMAL(20,4)),CAST(52232  AS DECIMAL(20,4)),CAST(20716 AS DECIMAL(20,4)),CAST(25224 AS DECIMAL(20,4)),CAST(11686 AS DECIMAL(20,4)),CAST(69916  AS DECIMAL(20,4)),CAST(-2346 AS DECIMAL(20,4)),CAST(9831  AS DECIMAL(20,4)),CAST(61271 AS DECIMAL(20,4)),CAST(8.05  AS DECIMAL(12,6)),CAST(7608 AS DECIMAL(16,4)),CAST('2021-07-28' AS DATE)),
    ('MSFT','ANNUAL',2022,CAST(198270 AS DECIMAL(20,4)),CAST(62650  AS DECIMAL(20,4)),CAST(24512 AS DECIMAL(20,4)),CAST(27725 AS DECIMAL(20,4)),CAST(14460 AS DECIMAL(20,4)),CAST(83383  AS DECIMAL(20,4)),CAST(-2063 AS DECIMAL(20,4)),CAST(10978 AS DECIMAL(20,4)),CAST(72738 AS DECIMAL(20,4)),CAST(9.65  AS DECIMAL(12,6)),CAST(7540 AS DECIMAL(16,4)),CAST('2022-07-28' AS DATE)),
    ('MSFT','ANNUAL',2023,CAST(211915 AS DECIMAL(20,4)),CAST(65863  AS DECIMAL(20,4)),CAST(27195 AS DECIMAL(20,4)),CAST(24456 AS DECIMAL(20,4)),CAST(13861 AS DECIMAL(20,4)),CAST(88523  AS DECIMAL(20,4)),CAST(-1901 AS DECIMAL(20,4)),CAST(16950 AS DECIMAL(20,4)),CAST(72361 AS DECIMAL(20,4)),CAST(9.72  AS DECIMAL(12,6)),CAST(7445 AS DECIMAL(16,4)),CAST('2023-07-27' AS DATE)),
    -- JPM
    ('JPM','ANNUAL',2019,CAST(115627 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(62800 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(36431 AS DECIMAL(20,4)),CAST(-8385 AS DECIMAL(20,4)),CAST(9803 AS DECIMAL(20,4)),CAST(36431 AS DECIMAL(20,4)),CAST(10.72 AS DECIMAL(12,6)),CAST(3401 AS DECIMAL(16,4)),CAST('2020-02-25' AS DATE)),
    ('JPM','ANNUAL',2020,CAST(119543 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(66656 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(29131 AS DECIMAL(20,4)),CAST(-9685 AS DECIMAL(20,4)),CAST(9000 AS DECIMAL(20,4)),CAST(29131 AS DECIMAL(20,4)),CAST(8.88  AS DECIMAL(12,6)),CAST(3279 AS DECIMAL(16,4)),CAST('2021-02-23' AS DATE)),
    ('JPM','ANNUAL',2021,CAST(121649 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(71349 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(48334 AS DECIMAL(20,4)),CAST(-7671 AS DECIMAL(20,4)),CAST(9926 AS DECIMAL(20,4)),CAST(48334 AS DECIMAL(20,4)),CAST(15.36 AS DECIMAL(12,6)),CAST(3147 AS DECIMAL(16,4)),CAST('2022-02-22' AS DATE)),
    ('JPM','ANNUAL',2022,CAST(128695 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(76140 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(37676 AS DECIMAL(20,4)),CAST(-9606 AS DECIMAL(20,4)),CAST(8490 AS DECIMAL(20,4)),CAST(37676 AS DECIMAL(20,4)),CAST(12.09 AS DECIMAL(12,6)),CAST(3115 AS DECIMAL(16,4)),CAST('2023-02-21' AS DATE)),
    ('JPM','ANNUAL',2023,CAST(154796 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(87219 AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(49552 AS DECIMAL(20,4)),CAST(-9738 AS DECIMAL(20,4)),CAST(14700 AS DECIMAL(20,4)),CAST(49552 AS DECIMAL(20,4)),CAST(16.23 AS DECIMAL(12,6)),CAST(3052 AS DECIMAL(16,4)),CAST('2024-02-16' AS DATE))
    ) v(tkr,pt,fy,rev,cogs,rd,sga,da,oi,ie,tax,ni,eps,shr,fd)
    JOIN dw.dim_company c ON c.ticker_symbol = v.tkr AND c.is_current = 1
    JOIN dw.dim_date    d ON d.full_date = DATEFROMPARTS(v.fy, 12, 31);
    PRINT '✓ Income statement data inserted (15 rows).';
END
GO

-- Balance Sheets
IF NOT EXISTS (SELECT 1 FROM dw.fact_balance_sheet WHERE fiscal_year=2019)
BEGIN
    INSERT INTO dw.fact_balance_sheet
        (company_key,date_key,period_type,fiscal_year,
         cash_equivalents,short_term_investments,accounts_receivable_net,inventories,
         total_current_assets,ppe_net,goodwill,intangible_assets_net,
         total_assets,accounts_payable,short_term_debt,
         total_current_liabilities,long_term_debt,total_liabilities,
         retained_earnings,total_equity,data_source)
    SELECT c.company_key, d.date_key,
           v.pt, v.fy,
           v.cash, v.sti, v.ar, v.inv,
           v.ca, v.ppe, v.gw, v.intang,
           v.ta, v.ap, v.std,
           v.cl, v.ltd, v.tl,
           v.re, v.eq, 'SEC_EDGAR'
    FROM (VALUES
    ('AAPL','ANNUAL',2019,CAST(48844  AS DECIMAL(20,4)),CAST(51713 AS DECIMAL(20,4)),CAST(22926 AS DECIMAL(20,4)),CAST(4106  AS DECIMAL(20,4)),CAST(162819 AS DECIMAL(20,4)),CAST(37378 AS DECIMAL(20,4)),CAST(0     AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(338516 AS DECIMAL(20,4)),CAST(46236 AS DECIMAL(20,4)),CAST(16240 AS DECIMAL(20,4)),CAST(105718 AS DECIMAL(20,4)),CAST(91807  AS DECIMAL(20,4)),CAST(248028 AS DECIMAL(20,4)),CAST(-70400 AS DECIMAL(20,4)),CAST(90488  AS DECIMAL(20,4))),
    ('AAPL','ANNUAL',2020,CAST(38016  AS DECIMAL(20,4)),CAST(52927 AS DECIMAL(20,4)),CAST(16120 AS DECIMAL(20,4)),CAST(4061  AS DECIMAL(20,4)),CAST(143713 AS DECIMAL(20,4)),CAST(36766 AS DECIMAL(20,4)),CAST(0     AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(323888 AS DECIMAL(20,4)),CAST(42296 AS DECIMAL(20,4)),CAST(13769 AS DECIMAL(20,4)),CAST(105392 AS DECIMAL(20,4)),CAST(98667  AS DECIMAL(20,4)),CAST(258578 AS DECIMAL(20,4)),CAST(-90099 AS DECIMAL(20,4)),CAST(65339  AS DECIMAL(20,4))),
    ('AAPL','ANNUAL',2021,CAST(37119  AS DECIMAL(20,4)),CAST(27699 AS DECIMAL(20,4)),CAST(26278 AS DECIMAL(20,4)),CAST(6580  AS DECIMAL(20,4)),CAST(134836 AS DECIMAL(20,4)),CAST(39440 AS DECIMAL(20,4)),CAST(0     AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(351002 AS DECIMAL(20,4)),CAST(54763 AS DECIMAL(20,4)),CAST(15613 AS DECIMAL(20,4)),CAST(125481 AS DECIMAL(20,4)),CAST(109106 AS DECIMAL(20,4)),CAST(287912 AS DECIMAL(20,4)),CAST(-77410 AS DECIMAL(20,4)),CAST(63090  AS DECIMAL(20,4))),
    ('AAPL','ANNUAL',2022,CAST(23646  AS DECIMAL(20,4)),CAST(24658 AS DECIMAL(20,4)),CAST(28184 AS DECIMAL(20,4)),CAST(4946  AS DECIMAL(20,4)),CAST(135405 AS DECIMAL(20,4)),CAST(42117 AS DECIMAL(20,4)),CAST(0     AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(352755 AS DECIMAL(20,4)),CAST(64115 AS DECIMAL(20,4)),CAST(21110 AS DECIMAL(20,4)),CAST(153982 AS DECIMAL(20,4)),CAST(98959  AS DECIMAL(20,4)),CAST(302083 AS DECIMAL(20,4)),CAST(-3068  AS DECIMAL(20,4)),CAST(50672  AS DECIMAL(20,4))),
    ('AAPL','ANNUAL',2023,CAST(29965  AS DECIMAL(20,4)),CAST(31590 AS DECIMAL(20,4)),CAST(29508 AS DECIMAL(20,4)),CAST(6331  AS DECIMAL(20,4)),CAST(143566 AS DECIMAL(20,4)),CAST(43715 AS DECIMAL(20,4)),CAST(0     AS DECIMAL(20,4)),CAST(0 AS DECIMAL(20,4)),CAST(352583 AS DECIMAL(20,4)),CAST(62611 AS DECIMAL(20,4)),CAST(15807 AS DECIMAL(20,4)),CAST(145308 AS DECIMAL(20,4)),CAST(95281  AS DECIMAL(20,4)),CAST(290437 AS DECIMAL(20,4)),CAST(-214   AS DECIMAL(20,4)),CAST(62146  AS DECIMAL(20,4))),
    -- MSFT
    ('MSFT','ANNUAL',2019,CAST(11356  AS DECIMAL(20,4)),CAST(122463 AS DECIMAL(20,4)),CAST(29524 AS DECIMAL(20,4)),CAST(2063  AS DECIMAL(20,4)),CAST(175552 AS DECIMAL(20,4)),CAST(36477 AS DECIMAL(20,4)),CAST(42026 AS DECIMAL(20,4)),CAST(7750 AS DECIMAL(20,4)),CAST(286556 AS DECIMAL(20,4)),CAST(9382  AS DECIMAL(20,4)),CAST(3749  AS DECIMAL(20,4)),CAST(69420  AS DECIMAL(20,4)),CAST(66662  AS DECIMAL(20,4)),CAST(184226 AS DECIMAL(20,4)),CAST(24150  AS DECIMAL(20,4)),CAST(102330 AS DECIMAL(20,4))),
    ('MSFT','ANNUAL',2020,CAST(13576  AS DECIMAL(20,4)),CAST(122728 AS DECIMAL(20,4)),CAST(32011 AS DECIMAL(20,4)),CAST(1895  AS DECIMAL(20,4)),CAST(181915 AS DECIMAL(20,4)),CAST(44151 AS DECIMAL(20,4)),CAST(43351 AS DECIMAL(20,4)),CAST(7038 AS DECIMAL(20,4)),CAST(301311 AS DECIMAL(20,4)),CAST(12530  AS DECIMAL(20,4)),CAST(3749  AS DECIMAL(20,4)),CAST(72310  AS DECIMAL(20,4)),CAST(59578  AS DECIMAL(20,4)),CAST(183007 AS DECIMAL(20,4)),CAST(34566  AS DECIMAL(20,4)),CAST(118304 AS DECIMAL(20,4))),
    ('MSFT','ANNUAL',2021,CAST(14224  AS DECIMAL(20,4)),CAST(116986 AS DECIMAL(20,4)),CAST(38043 AS DECIMAL(20,4)),CAST(2636  AS DECIMAL(20,4)),CAST(184406 AS DECIMAL(20,4)),CAST(59715 AS DECIMAL(20,4)),CAST(49711 AS DECIMAL(20,4)),CAST(9366 AS DECIMAL(20,4)),CAST(333779 AS DECIMAL(20,4)),CAST(15163  AS DECIMAL(20,4)),CAST(8072  AS DECIMAL(20,4)),CAST(88657  AS DECIMAL(20,4)),CAST(50074  AS DECIMAL(20,4)),CAST(191791 AS DECIMAL(20,4)),CAST(57055  AS DECIMAL(20,4)),CAST(141988 AS DECIMAL(20,4))),
    ('MSFT','ANNUAL',2022,CAST(13931  AS DECIMAL(20,4)),CAST(104757 AS DECIMAL(20,4)),CAST(44261 AS DECIMAL(20,4)),CAST(3742  AS DECIMAL(20,4)),CAST(169684 AS DECIMAL(20,4)),CAST(74398 AS DECIMAL(20,4)),CAST(67524 AS DECIMAL(20,4)),CAST(11298 AS DECIMAL(20,4)),CAST(364840 AS DECIMAL(20,4)),CAST(19000  AS DECIMAL(20,4)),CAST(2750  AS DECIMAL(20,4)),CAST(95082  AS DECIMAL(20,4)),CAST(47032  AS DECIMAL(20,4)),CAST(198298 AS DECIMAL(20,4)),CAST(84281  AS DECIMAL(20,4)),CAST(166542 AS DECIMAL(20,4))),
    ('MSFT','ANNUAL',2023,CAST(34704  AS DECIMAL(20,4)),CAST(76558  AS DECIMAL(20,4)),CAST(48688 AS DECIMAL(20,4)),CAST(2500  AS DECIMAL(20,4)),CAST(211915 AS DECIMAL(20,4)),CAST(90865 AS DECIMAL(20,4)),CAST(67886 AS DECIMAL(20,4)),CAST(9366 AS DECIMAL(20,4)),CAST(411976 AS DECIMAL(20,4)),CAST(18095  AS DECIMAL(20,4)),CAST(5247  AS DECIMAL(20,4)),CAST(104149 AS DECIMAL(20,4)),CAST(41990  AS DECIMAL(20,4)),CAST(205753 AS DECIMAL(20,4)),CAST(118848 AS DECIMAL(20,4)),CAST(206223 AS DECIMAL(20,4)))
    ) v(tkr,pt,fy,cash,sti,ar,inv,ca,ppe,gw,intang,ta,ap,std,cl,ltd,tl,re,eq)
    JOIN dw.dim_company c ON c.ticker_symbol = v.tkr AND c.is_current = 1
    JOIN dw.dim_date    d ON d.full_date = DATEFROMPARTS(v.fy, 12, 31);
    PRINT '✓ Balance sheet data inserted (10 rows).';
END
GO

-- Cash Flow Statements
IF NOT EXISTS (SELECT 1 FROM dw.fact_cash_flow WHERE fiscal_year=2019)
BEGIN
    INSERT INTO dw.fact_cash_flow
        (company_key,date_key,period_type,fiscal_year,
         net_income_cf,depreciation_amortization_cf,
         cash_from_operations,capital_expenditures,
         cash_from_investing,dividends_paid,
         common_stock_repurchased,cash_from_financing,
         net_change_in_cash,data_source)
    SELECT c.company_key, d.date_key,
           v.pt, v.fy,
           v.ni, v.da, v.cfo, v.capex,
           v.cfi, v.div, v.buyback, v.cff,
           v.netcash, 'SEC_EDGAR'
    FROM (VALUES
    ('AAPL','ANNUAL',2019,CAST(55256  AS DECIMAL(20,4)),CAST(12547 AS DECIMAL(20,4)),CAST(69391  AS DECIMAL(20,4)),CAST(-10495 AS DECIMAL(20,4)),CAST(-45896 AS DECIMAL(20,4)),CAST(-14119 AS DECIMAL(20,4)),CAST(-66897 AS DECIMAL(20,4)),CAST(-90976 AS DECIMAL(20,4)),CAST(-3481  AS DECIMAL(20,4))),
    ('AAPL','ANNUAL',2020,CAST(57411  AS DECIMAL(20,4)),CAST(11056 AS DECIMAL(20,4)),CAST(80674  AS DECIMAL(20,4)),CAST(-7309  AS DECIMAL(20,4)),CAST(-4289  AS DECIMAL(20,4)),CAST(-14081 AS DECIMAL(20,4)),CAST(-72358 AS DECIMAL(20,4)),CAST(-86820 AS DECIMAL(20,4)),CAST(-10435 AS DECIMAL(20,4))),
    ('AAPL','ANNUAL',2021,CAST(94680  AS DECIMAL(20,4)),CAST(11284 AS DECIMAL(20,4)),CAST(104038 AS DECIMAL(20,4)),CAST(-11085 AS DECIMAL(20,4)),CAST(-14545 AS DECIMAL(20,4)),CAST(-14467 AS DECIMAL(20,4)),CAST(-85971 AS DECIMAL(20,4)),CAST(-93353 AS DECIMAL(20,4)),CAST(-3860  AS DECIMAL(20,4))),
    ('AAPL','ANNUAL',2022,CAST(99803  AS DECIMAL(20,4)),CAST(11104 AS DECIMAL(20,4)),CAST(122151 AS DECIMAL(20,4)),CAST(-10708 AS DECIMAL(20,4)),CAST(-22354 AS DECIMAL(20,4)),CAST(-14841 AS DECIMAL(20,4)),CAST(-89402 AS DECIMAL(20,4)),CAST(-110749 AS DECIMAL(20,4)),CAST(-10952 AS DECIMAL(20,4))),
    ('AAPL','ANNUAL',2023,CAST(96995  AS DECIMAL(20,4)),CAST(11519 AS DECIMAL(20,4)),CAST(113736 AS DECIMAL(20,4)),CAST(-11633 AS DECIMAL(20,4)),CAST(-3632  AS DECIMAL(20,4)),CAST(-15025 AS DECIMAL(20,4)),CAST(-77550 AS DECIMAL(20,4)),CAST(-108488 AS DECIMAL(20,4)),CAST(5024   AS DECIMAL(20,4))),
    ('MSFT','ANNUAL',2019,CAST(39240  AS DECIMAL(20,4)),CAST(12513 AS DECIMAL(20,4)),CAST(52185  AS DECIMAL(20,4)),CAST(-13925 AS DECIMAL(20,4)),CAST(-15805 AS DECIMAL(20,4)),CAST(-13811 AS DECIMAL(20,4)),CAST(-19800 AS DECIMAL(20,4)),CAST(-33561 AS DECIMAL(20,4)),CAST(2819   AS DECIMAL(20,4))),
    ('MSFT','ANNUAL',2020,CAST(44281  AS DECIMAL(20,4)),CAST(12796 AS DECIMAL(20,4)),CAST(60675  AS DECIMAL(20,4)),CAST(-15441 AS DECIMAL(20,4)),CAST(-10441 AS DECIMAL(20,4)),CAST(-15137 AS DECIMAL(20,4)),CAST(-22956 AS DECIMAL(20,4)),CAST(-39173 AS DECIMAL(20,4)),CAST(11060  AS DECIMAL(20,4))),
    ('MSFT','ANNUAL',2021,CAST(61271  AS DECIMAL(20,4)),CAST(11686 AS DECIMAL(20,4)),CAST(76740  AS DECIMAL(20,4)),CAST(-20622 AS DECIMAL(20,4)),CAST(-25049 AS DECIMAL(20,4)),CAST(-16521 AS DECIMAL(20,4)),CAST(-32696 AS DECIMAL(20,4)),CAST(-49453 AS DECIMAL(20,4)),CAST(2238   AS DECIMAL(20,4))),
    ('MSFT','ANNUAL',2022,CAST(72738  AS DECIMAL(20,4)),CAST(14460 AS DECIMAL(20,4)),CAST(89035  AS DECIMAL(20,4)),CAST(-23886 AS DECIMAL(20,4)),CAST(-28169 AS DECIMAL(20,4)),CAST(-18135 AS DECIMAL(20,4)),CAST(-32696 AS DECIMAL(20,4)),CAST(-52777 AS DECIMAL(20,4)),CAST(7517   AS DECIMAL(20,4))),
    ('MSFT','ANNUAL',2023,CAST(72361  AS DECIMAL(20,4)),CAST(13861 AS DECIMAL(20,4)),CAST(87582  AS DECIMAL(20,4)),CAST(-28107 AS DECIMAL(20,4)),CAST(-22038 AS DECIMAL(20,4)),CAST(-20444 AS DECIMAL(20,4)),CAST(-22672 AS DECIMAL(20,4)),CAST(-56052 AS DECIMAL(20,4)),CAST(5022   AS DECIMAL(20,4)))
    ) v(tkr,pt,fy,ni,da,cfo,capex,cfi,div,buyback,cff,netcash)
    JOIN dw.dim_company c ON c.ticker_symbol = v.tkr AND c.is_current = 1
    JOIN dw.dim_date    d ON d.full_date = DATEFROMPARTS(v.fy, 12, 31);
    PRINT '✓ Cash flow data inserted (10 rows).';
END
GO

-- ============================================================
-- STEP 6 – AUDIT TABLE + TRIGGER
-- ============================================================
IF OBJECT_ID('audit.dw_audit_log','U') IS NULL
BEGIN
    CREATE TABLE audit.dw_audit_log (
        log_id      BIGINT       IDENTITY(1,1) PRIMARY KEY,
        schema_name VARCHAR(50),
        table_name  VARCHAR(100),
        operation   CHAR(6),
        old_data    NVARCHAR(MAX),
        new_data    NVARCHAR(MAX),
        changed_by  VARCHAR(100) DEFAULT SYSTEM_USER,
        changed_at  DATETIME2    DEFAULT GETDATE()
    );
    PRINT '✓ audit.dw_audit_log created.';
END
GO
CREATE OR ALTER TRIGGER dw.trg_audit_dim_company
ON dw.dim_company
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @op CHAR(6) =
        CASE
            WHEN EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted) THEN 'UPDATE'
            WHEN EXISTS (SELECT 1 FROM inserted)                                    THEN 'INSERT'
            ELSE                                                                         'DELETE'
        END;

    INSERT INTO audit.dw_audit_log (schema_name, table_name, operation, changed_by)
    VALUES ('dw', 'dim_company', @op, SYSTEM_USER);
END;
GO

PRINT N'✓ Audit trigger dw.trg_audit_dim_company created / updated.';
GO
-- ============================================================
-- STEP 7 – INDEXES
-- ============================================================
-- Pattern: IF NOT EXISTS guard on sys.indexes
-- Safe to run multiple times — skips silently if index exists.

-- ── dw.fact_income_statement ──────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.fact_income_statement')
      AND name = N'idx_fis_company_year'
)
BEGIN
    CREATE INDEX idx_fis_company_year
        ON dw.fact_income_statement (company_key, fiscal_year, period_type);
    PRINT N'  ✓ idx_fis_company_year created.';
END
ELSE
    PRINT N'  – idx_fis_company_year already exists, skipped.';

-- ── dw.fact_balance_sheet ─────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.fact_balance_sheet')
      AND name = N'idx_fbs_company_year'
)
BEGIN
    CREATE INDEX idx_fbs_company_year
        ON dw.fact_balance_sheet (company_key, fiscal_year, period_type);
    PRINT N'  ✓ idx_fbs_company_year created.';
END
ELSE
    PRINT N'  – idx_fbs_company_year already exists, skipped.';

-- ── dw.fact_cash_flow ─────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.fact_cash_flow')
      AND name = N'idx_fcf_company_year'
)
BEGIN
    CREATE INDEX idx_fcf_company_year
        ON dw.fact_cash_flow (company_key, fiscal_year, period_type);
    PRINT N'  ✓ idx_fcf_company_year created.';
END
ELSE
    PRINT N'  – idx_fcf_company_year already exists, skipped.';

-- ── dw.fact_stock_price ───────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dw.fact_stock_price')
      AND name = N'idx_fsp_company_date'
)
BEGIN
    CREATE INDEX idx_fsp_company_date
        ON dw.fact_stock_price (company_key, date_key);
    PRINT N'  ✓ idx_fsp_company_date created.';
END
ELSE
    PRINT N'  – idx_fsp_company_date already exists, skipped.';

PRINT N'✓ STEP 7 complete – all indexes created / verified.';
GO

-- ============================================================
-- STEP 8 – CREDIT RISK TABLES
-- ============================================================
IF OBJECT_ID('credit.pd_master_scale','U') IS NULL
BEGIN
    CREATE TABLE credit.pd_master_scale (
        rating             VARCHAR(10) PRIMARY KEY,
        rating_description VARCHAR(50),
        pd_lower_pct       DECIMAL(10,6),
        pd_upper_pct       DECIMAL(10,6),
        pd_midpoint_pct    DECIMAL(10,6),
        moody_equivalent   VARCHAR(10),
        sp_equivalent      VARCHAR(10),
        basel_class        VARCHAR(25)
    );
    INSERT INTO credit.pd_master_scale VALUES
    ('AAA','Prime',          0.000001, 0.0100,  0.0030, 'Aaa', 'AAA','INVESTMENT_GRADE'),
    ('AA', 'High Grade',     0.0200,   0.0400,  0.0250, 'Aa2', 'AA', 'INVESTMENT_GRADE'),
    ('A',  'Upper Medium',   0.0700,   0.1400,  0.1000, 'A2',  'A',  'INVESTMENT_GRADE'),
    ('BBB','Lower Medium',   0.2000,   0.5000,  0.3500, 'Baa2','BBB','INVESTMENT_GRADE'),
    ('BB', 'Non-Investment', 1.2500,   2.5000,  1.8500, 'Ba2', 'BB', 'SUB_INVESTMENT'),
    ('B',  'Speculative',    5.5000,  11.0000,  8.0000, 'B2',  'B',  'SUB_INVESTMENT'),
    ('CCC','Vulnerable',    15.0000,  35.0000, 22.0000, 'Caa', 'CCC','SUB_INVESTMENT'),
    ('D',  'Default',      100.0000, 100.0000,100.0000, 'D',   'D',  'DEFAULT');
    PRINT '✓ credit.pd_master_scale created and seeded (8 rows).';
END
GO

IF OBJECT_ID('credit.borrowers','U') IS NULL
BEGIN
    CREATE TABLE credit.borrowers (
        borrower_key       INT          IDENTITY(1,1) PRIMARY KEY,
        borrower_id        VARCHAR(30)  NOT NULL UNIQUE,
        borrower_type      VARCHAR(20)  NOT NULL,
        borrower_name      NVARCHAR(200) NOT NULL,
        annual_revenue_usd DECIMAL(20,4),
        ebitda_usd         DECIMAL(20,4),
        internal_rating    VARCHAR(10),
        credit_score       SMALLINT,
        is_active          BIT          DEFAULT 1,
        onboarding_date    DATE,
        created_at         DATETIME2    DEFAULT GETDATE()
    );
    INSERT INTO credit.borrowers
        (borrower_id, borrower_type, borrower_name, annual_revenue_usd, ebitda_usd, internal_rating, onboarding_date)
    VALUES
    ('BORR-001','CORPORATE','East Africa Breweries Ltd',  850000000, 210000000,'BBB','2018-03-15'),
    ('BORR-002','SME',      'Nairobi Auto Parts Ltd',     45000000,   8500000, 'BB', '2019-07-22'),
    ('BORR-003','CORPORATE','Kenya Power and Lighting',   680000000, 145000000,'BB', '2017-11-01'),
    ('BORR-004','CORPORATE','Safaricom PLC Corporate',  3800000000,1200000000, 'A',  '2015-06-30'),
    ('BORR-005','SME',      'Mombasa Grain Traders',      22000000,   3500000, 'B',  '2021-02-14');
    PRINT '✓ credit.borrowers created and seeded (5 rows).';
END
GO

IF OBJECT_ID('credit.loan_facilities','U') IS NULL
BEGIN
    CREATE TABLE credit.loan_facilities (
        facility_key         BIGINT        IDENTITY(1,1) PRIMARY KEY,
        facility_id          VARCHAR(30)   NOT NULL UNIQUE,
        borrower_key         INT           NOT NULL REFERENCES credit.borrowers(borrower_key),
        facility_type        VARCHAR(40)   NOT NULL,
        -- FIX: renamed from 'commit' (reserved keyword) to 'commitment_usd'
        commitment_usd       DECIMAL(20,4) NOT NULL,
        outstanding_balance  DECIMAL(20,4) NOT NULL DEFAULT 0,
        -- Computed: undrawn = commitment - outstanding
        undrawn_amount  AS   (commitment_usd - outstanding_balance),
        interest_rate_pct    DECIMAL(8,4)  NOT NULL,
        origination_date     DATE NOT NULL,
        maturity_date        DATE NOT NULL,
        is_secured           BIT  DEFAULT 0,
        collateral_value_usd DECIMAL(20,4),
        facility_status      VARCHAR(20)   DEFAULT 'CURRENT',
        days_past_due        SMALLINT      DEFAULT 0,
        pd_pct               DECIMAL(10,6),
        lgd_pct              DECIMAL(10,6),
        -- Computed: Expected Loss = PD x LGD x EAD
        expected_loss_usd AS (
            ISNULL(pd_pct,0)/100.0 * ISNULL(lgd_pct,0)/100.0 *
            (outstanding_balance + 0.75*(commitment_usd - outstanding_balance))
        ),
        created_at           DATETIME2     DEFAULT GETDATE(),
        updated_at           DATETIME2     DEFAULT GETDATE()
    );
    -- FIX: Use explicit column names – no reserved keyword aliases
    INSERT INTO credit.loan_facilities
        (facility_id, borrower_key, facility_type,
         commitment_usd, outstanding_balance,
         interest_rate_pct, origination_date, maturity_date,
         is_secured, collateral_value_usd,
         facility_status, days_past_due, pd_pct, lgd_pct)
    VALUES
    ('FAC-001',(SELECT borrower_key FROM credit.borrowers WHERE borrower_id='BORR-001'),'TERM_LOAN', 10000000, 8500000, 7.50,'2021-01-15','2026-01-15',1,12000000,'CURRENT',  0,  0.35,35.0),
    ('FAC-002',(SELECT borrower_key FROM credit.borrowers WHERE borrower_id='BORR-002'),'REVOLVER',   2000000, 1200000,12.00,'2022-06-01','2024-06-01',0,       0,'WATCHLIST',45,  5.00,45.0),
    ('FAC-003',(SELECT borrower_key FROM credit.borrowers WHERE borrower_id='BORR-003'),'TERM_LOAN', 25000000,25000000, 8.25,'2020-03-01','2027-03-01',1,35000000,'CURRENT',  0,  1.85,30.0),
    ('FAC-004',(SELECT borrower_key FROM credit.borrowers WHERE borrower_id='BORR-004'),'REVOLVER',  50000000,15000000, 5.50,'2023-01-01','2025-01-01',0,       0,'CURRENT',  0,  0.10,45.0),
    ('FAC-005',(SELECT borrower_key FROM credit.borrowers WHERE borrower_id='BORR-005'),'TERM_LOAN',  1500000, 1500000,18.00,'2021-09-01','2024-09-01',1, 1200000,'NPL',      92, 22.00,55.0);
    PRINT '✓ credit.loan_facilities created and seeded (5 rows).';
END
GO

-- Repayment History
-- FIX: facility_key changed from INT to BIGINT to match
--      credit.loan_facilities.facility_key (BIGINT IDENTITY) –
--      resolves Msg 1778 FK type-mismatch error
IF OBJECT_ID('credit.repayment_history','U') IS NULL
BEGIN
    CREATE TABLE credit.repayment_history (
        repayment_key    BIGINT       IDENTITY(1,1) PRIMARY KEY,
        facility_key     BIGINT       NOT NULL REFERENCES credit.loan_facilities(facility_key),
        scheduled_date   DATE         NOT NULL,
        actual_date      DATE,
        scheduled_amount DECIMAL(16,4) NOT NULL,
        principal_paid   DECIMAL(16,4) DEFAULT 0,
        interest_paid    DECIMAL(16,4) DEFAULT 0,
        fees_paid        DECIMAL(12,4) DEFAULT 0,
        total_paid AS    (ISNULL(principal_paid,0)+ISNULL(interest_paid,0)+ISNULL(fees_paid,0)),
        days_late AS     (CASE WHEN actual_date IS NOT NULL
                               THEN DATEDIFF(DAY, scheduled_date, actual_date)
                               ELSE NULL END),
        payment_status   VARCHAR(20),
        created_at       DATETIME2    DEFAULT GETDATE()
    );
    PRINT '✓ credit.repayment_history created.';
END
GO

-- ============================================================
-- STEP 9 – FP&A TABLES
-- ============================================================
IF OBJECT_ID('fpa.dim_cost_center','U') IS NULL
BEGIN
    CREATE TABLE fpa.dim_cost_center (
        cost_center_key  INT           IDENTITY(1,1) PRIMARY KEY,
        cost_center_code VARCHAR(20)   NOT NULL UNIQUE,
        cost_center_name NVARCHAR(100) NOT NULL,
        department       NVARCHAR(80),
        division         NVARCHAR(80),
        cost_center_type VARCHAR(30),
        manager_name     NVARCHAR(100),
        is_active        BIT           DEFAULT 1
    );
    INSERT INTO fpa.dim_cost_center (cost_center_code,cost_center_name,department,division,cost_center_type)
    VALUES
    ('CC-001','Technology and Engineering','Engineering','Product','COST'),
    ('CC-002','Sales EMEA','Sales','Commercial','REVENUE'),
    ('CC-003','Sales Americas','Sales','Commercial','REVENUE'),
    ('CC-004','Marketing','Marketing','Commercial','COST'),
    ('CC-005','Finance and Accounting','Finance','Corporate','COST'),
    ('CC-006','Human Resources','HR','Corporate','COST'),
    ('CC-007','Research and Development','R&D','Product','COST');
    PRINT '✓ fpa.dim_cost_center created and seeded (7 rows).';
END
GO

IF OBJECT_ID('fpa.actuals','U') IS NULL
BEGIN
    CREATE TABLE fpa.actuals (
        actual_key      BIGINT       IDENTITY(1,1) PRIMARY KEY,
        company_key     INT          REFERENCES dw.dim_company(company_key),
        cost_center_key INT          REFERENCES fpa.dim_cost_center(cost_center_key),
        account_code    VARCHAR(20)  REFERENCES dw.dim_account(account_code),
        fiscal_year     SMALLINT     NOT NULL,
        fiscal_month    SMALLINT     NOT NULL,
        actual_amount   DECIMAL(20,4) NOT NULL,
        is_preliminary  BIT          DEFAULT 0,
        gl_close_date   DATE,
        created_at      DATETIME2    DEFAULT GETDATE(),
        CONSTRAINT UQ_actuals UNIQUE (company_key,cost_center_key,account_code,fiscal_year,fiscal_month)
    );
    PRINT '✓ fpa.actuals created.';
END
GO

IF OBJECT_ID('fpa.budgets','U') IS NULL
BEGIN
    CREATE TABLE fpa.budgets (
        budget_key      BIGINT       IDENTITY(1,1) PRIMARY KEY,
        company_key     INT          REFERENCES dw.dim_company(company_key),
        cost_center_key INT          REFERENCES fpa.dim_cost_center(cost_center_key),
        account_code    VARCHAR(20)  REFERENCES dw.dim_account(account_code),
        fiscal_year     SMALLINT     NOT NULL,
        budget_version  VARCHAR(20)  NOT NULL DEFAULT 'ORIGINAL',
        budget_jan      DECIMAL(18,4) DEFAULT 0,
        budget_feb      DECIMAL(18,4) DEFAULT 0,
        budget_mar      DECIMAL(18,4) DEFAULT 0,
        budget_apr      DECIMAL(18,4) DEFAULT 0,
        budget_may      DECIMAL(18,4) DEFAULT 0,
        budget_jun      DECIMAL(18,4) DEFAULT 0,
        budget_jul      DECIMAL(18,4) DEFAULT 0,
        budget_aug      DECIMAL(18,4) DEFAULT 0,
        budget_sep      DECIMAL(18,4) DEFAULT 0,
        budget_oct      DECIMAL(18,4) DEFAULT 0,
        budget_nov      DECIMAL(18,4) DEFAULT 0,
        budget_dec      DECIMAL(18,4) DEFAULT 0,
        budget_annual AS (budget_jan+budget_feb+budget_mar+budget_apr+budget_may+budget_jun+
                          budget_jul+budget_aug+budget_sep+budget_oct+budget_nov+budget_dec),
        approved_by     VARCHAR(80),
        created_at      DATETIME2    DEFAULT GETDATE()
    );
    PRINT '✓ fpa.budgets created.';
END
GO

-- ============================================================
-- STEP 10 – ETL PIPELINE CONTROL
-- ============================================================
IF OBJECT_ID('etl.pipeline_jobs','U') IS NULL
BEGIN
    CREATE TABLE etl.pipeline_jobs (
        job_id           INT          IDENTITY(1,1) PRIMARY KEY,
        job_name         VARCHAR(150) NOT NULL,
        job_type         VARCHAR(30)  NOT NULL,
        source_system    VARCHAR(50),
        target_schema    VARCHAR(50),
        target_table     VARCHAR(100),
        last_run_start   DATETIME2,
        last_run_end     DATETIME2,
        last_run_status  VARCHAR(20)  DEFAULT 'PENDING',
        records_loaded   BIGINT       DEFAULT 0,
        records_rejected BIGINT       DEFAULT 0,
        error_message    NVARCHAR(MAX),
        is_active        BIT          DEFAULT 1,
        created_at       DATETIME2    DEFAULT GETDATE()
    );
    INSERT INTO etl.pipeline_jobs (job_name,job_type,source_system,target_schema,target_table)
    VALUES
    ('SEC_EDGAR_Income_Statement','FULL_ETL','SEC_EDGAR',  'dw',  'fact_income_statement'),
    ('Market_Price_Daily_Load',   'LOAD',   'MARKET_DATA','dw',  'fact_stock_price'),
    ('Exchange_Rate_Load',        'LOAD',   'FRED',       'dw',  'fact_exchange_rate'),
    ('FPA_Actuals_GL_Load',       'LOAD',   'ERP_SYSTEM', 'fpa', 'actuals'),
    ('Credit_Risk_Recalc',        'TRANSFORM','INTERNAL', 'credit','loan_facilities');
    PRINT '✓ etl.pipeline_jobs created and seeded (5 rows).';
END
GO

-- ============================================================
-- STEP 11 – STORED PROCEDURES
-- ============================================================

-- ── SCD Type 2 Upsert for dim_company ────────────────────────
IF OBJECT_ID('dw.usp_upsert_company_scd2','P') IS NOT NULL
    DROP PROCEDURE dw.usp_upsert_company_scd2;
GO
CREATE PROCEDURE dw.usp_upsert_company_scd2
    @p_company_id  VARCHAR(20),
    @p_ticker      VARCHAR(12),
    @p_name        NVARCHAR(200),
    @p_market_cap  DECIMAL(20,4),
    @p_exchange    VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @key INT, @changed BIT = 0;
    SELECT @key = company_key FROM dw.dim_company
    WHERE company_id = @p_company_id AND is_current = 1;

    IF @key IS NOT NULL
    BEGIN
        SELECT @changed = CASE WHEN ticker_symbol <> @p_ticker OR company_name <> @p_name THEN 1 ELSE 0 END
        FROM dw.dim_company WHERE company_key = @key;
        IF @changed = 1
        BEGIN
            UPDATE dw.dim_company
            SET scd_end_date = CAST(DATEADD(DAY,-1,GETDATE()) AS DATE),
                is_current = 0, updated_at = GETDATE()
            WHERE company_key = @key;
            INSERT INTO dw.dim_company (company_id,ticker_symbol,company_name,exchange_code,market_cap_usd_m,scd_start_date,is_current)
            VALUES (@p_company_id,@p_ticker,@p_name,@p_exchange,@p_market_cap,CAST(GETDATE() AS DATE),1);
            PRINT 'SCD2: New version inserted for ' + @p_company_id;
        END ELSE BEGIN
            UPDATE dw.dim_company SET market_cap_usd_m=@p_market_cap, updated_at=GETDATE()
            WHERE company_key=@key;
            PRINT 'SCD2: Market cap updated for ' + @p_company_id;
        END
    END ELSE BEGIN
        INSERT INTO dw.dim_company (company_id,ticker_symbol,company_name,exchange_code,market_cap_usd_m,scd_start_date,is_current)
        VALUES (@p_company_id,@p_ticker,@p_name,@p_exchange,@p_market_cap,CAST(GETDATE() AS DATE),1);
        PRINT 'SCD2: New company inserted: ' + @p_company_id;
    END
END;
GO
PRINT '✓ dw.usp_upsert_company_scd2 created.';
GO

-- ── Credit Risk Summary ───────────────────────────────────────
IF OBJECT_ID('credit.usp_credit_risk_summary','P') IS NOT NULL
    DROP PROCEDURE credit.usp_credit_risk_summary;
GO
CREATE PROCEDURE credit.usp_credit_risk_summary
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        b.internal_rating,
        lf.facility_status,
        COUNT(*)                                           AS facility_count,
        ROUND(SUM(lf.commitment_usd)/1e6,2)               AS total_commitment_m,
        ROUND(SUM(lf.outstanding_balance)/1e6,2)          AS total_outstanding_m,
        ROUND(AVG(lf.pd_pct),4)                           AS avg_pd_pct,
        ROUND(AVG(lf.lgd_pct),2)                          AS avg_lgd_pct,
        ROUND(SUM(lf.expected_loss_usd)/1e6,4)            AS total_expected_loss_m,
        COUNT(CASE WHEN lf.days_past_due > 0 THEN 1 END)  AS facilities_with_dpd
    FROM credit.loan_facilities lf
    JOIN credit.borrowers b ON lf.borrower_key = b.borrower_key
    GROUP BY b.internal_rating, lf.facility_status
    ORDER BY b.internal_rating, lf.facility_status;
END;
GO
PRINT '✓ credit.usp_credit_risk_summary created.';
GO

-- ── Amortisation Schedule ─────────────────────────────────────
-- FIX: explicit CAST to DECIMAL(18,4) on EVERY column in BOTH
-- the anchor and recursive part → resolves Msg 240 completely
IF OBJECT_ID('credit.usp_amortisation_schedule','P') IS NOT NULL
    DROP PROCEDURE credit.usp_amortisation_schedule;
GO
CREATE PROCEDURE credit.usp_amortisation_schedule
    @principal   DECIMAL(18,4),
    @annual_rate DECIMAL(8,4),
    @term_months INT,
    @start_date  DATE
AS
BEGIN
    SET NOCOUNT ON;
    -- Use FLOAT for intermediate arithmetic to avoid precision issues
    DECLARE @r   FLOAT = CAST(@annual_rate AS FLOAT) / 100.0 / 12.0;
    DECLARE @pmt DECIMAL(18,4) = CAST(
        @principal * (@r / (1.0 - POWER(1.0 + @r, -CAST(@term_months AS FLOAT))))
    AS DECIMAL(18,4));

    WITH amort (period, payment_date, opening_bal, monthly_payment,
                interest_portion, principal_portion, closing_bal, cumulative_interest)
    AS (
        -- Anchor row
        SELECT
            CAST(1 AS INT),
            CAST(DATEADD(MONTH,1,@start_date) AS DATE),
            CAST(@principal                                 AS DECIMAL(18,4)),
            CAST(@pmt                                       AS DECIMAL(18,4)),
            CAST(ROUND(CAST(@principal AS FLOAT)*@r,4)     AS DECIMAL(18,4)),
            CAST(ROUND(CAST(@pmt AS FLOAT) - CAST(@principal AS FLOAT)*@r,4) AS DECIMAL(18,4)),
            CAST(ROUND(CAST(@principal AS FLOAT)
                 - (CAST(@pmt AS FLOAT) - CAST(@principal AS FLOAT)*@r),4) AS DECIMAL(18,4)),
            CAST(ROUND(CAST(@principal AS FLOAT)*@r,4)     AS DECIMAL(18,4))

        UNION ALL

        -- Recursive rows – every column CAST to DECIMAL(18,4)
        SELECT
            CAST(a.period + 1 AS INT),
            CAST(DATEADD(MONTH, a.period+1, @start_date) AS DATE),
            CAST(a.closing_bal AS DECIMAL(18,4)),
            CAST(@pmt AS DECIMAL(18,4)),
            CAST(ROUND(CAST(a.closing_bal AS FLOAT)*@r,4)  AS DECIMAL(18,4)),
            CAST(ROUND(CAST(@pmt AS FLOAT) - CAST(a.closing_bal AS FLOAT)*@r,4) AS DECIMAL(18,4)),
            CAST(CASE
                WHEN CAST(a.closing_bal AS FLOAT)
                     - (CAST(@pmt AS FLOAT) - CAST(a.closing_bal AS FLOAT)*@r) < 0
                THEN 0.0
                ELSE ROUND(CAST(a.closing_bal AS FLOAT)
                     - (CAST(@pmt AS FLOAT) - CAST(a.closing_bal AS FLOAT)*@r),4)
            END AS DECIMAL(18,4)),
            CAST(a.cumulative_interest
                 + ROUND(CAST(a.closing_bal AS FLOAT)*@r,4) AS DECIMAL(18,4))
        FROM amort a
        WHERE a.period < @term_months AND a.closing_bal > CAST(0.01 AS DECIMAL(18,4))
    )
    SELECT
        period,
        payment_date,
        opening_bal          AS opening_balance,
        monthly_payment,
        interest_portion,
        principal_portion,
        closing_bal          AS closing_balance,
        cumulative_interest
    FROM amort
    OPTION (MAXRECURSION 500);
END;
GO
PRINT '✓ credit.usp_amortisation_schedule created (type-safe recursive CTE).';
GO

-- ============================================================
-- STEP 12 – VIEWS
-- ============================================================

-- ── mart.v_financial_ratios (FIXED – was returning 0 rows) ───
-- FIX A: ISNULL on all fact columns prevents NULL arithmetic
-- FIX B: Inline OVER() clauses – T-SQL does NOT support named WINDOW aliases
-- FIX C: EBITDA uses ISNULL(da,0) to handle banks with no D&A
IF OBJECT_ID('mart.v_financial_ratios','V') IS NOT NULL DROP VIEW mart.v_financial_ratios;
GO
CREATE VIEW mart.v_financial_ratios AS
WITH base AS (
    SELECT
        c.company_key, c.ticker_symbol, c.company_name,
        i.gics_sector_name, i.gics_industry_name, co.country_name,
        is_.fiscal_year, is_.period_type,
        -- Income Statement (ISNULL guards prevent NULL arithmetic)
        ISNULL(is_.total_revenue,0)            AS total_revenue,
        ISNULL(is_.gross_profit,0)             AS gross_profit,
        ISNULL(is_.operating_income,0)         AS operating_income,
        ISNULL(is_.net_income,0)               AS net_income,
        ISNULL(is_.interest_expense,0)         AS interest_expense,
        ISNULL(is_.eps_diluted,0)              AS eps_diluted,
        ISNULL(is_.depreciation_amortization,0) AS da,
        -- EBITDA: operating_income + D&A (banks may have 0 D&A – that is correct)
        ISNULL(is_.operating_income,0) + ISNULL(is_.depreciation_amortization,0) AS ebitda,
        -- Balance Sheet
        ISNULL(bs.total_assets,0)              AS total_assets,
        ISNULL(bs.total_equity,0)              AS total_equity,
        ISNULL(bs.total_current_assets,0)      AS total_current_assets,
        ISNULL(bs.total_current_liabilities,0) AS total_current_liabilities,
        ISNULL(bs.cash_equivalents,0)          AS cash_equivalents,
        ISNULL(bs.short_term_investments,0)    AS short_term_investments,
        ISNULL(bs.accounts_receivable_net,0)   AS accounts_receivable_net,
        ISNULL(bs.inventories,0)               AS inventories,
        ISNULL(bs.accounts_payable,0)          AS accounts_payable,
        ISNULL(bs.long_term_debt,0)            AS long_term_debt,
        ISNULL(bs.short_term_debt,0)           AS short_term_debt,
        ISNULL(bs.ppe_net,0)                   AS ppe_net,
        ISNULL(bs.total_liabilities,0)         AS total_liabilities,
        ISNULL(bs.net_debt,0)                  AS net_debt,
        ISNULL(bs.working_capital,0)           AS working_capital,
        -- Cash Flow
        ISNULL(cf.cash_from_operations,0)      AS cash_from_operations,
        ISNULL(cf.capital_expenditures,0)      AS capital_expenditures,
        ISNULL(cf.free_cash_flow,0)            AS free_cash_flow,
        ISNULL(cf.dividends_paid,0)            AS dividends_paid,
        -- Rolling averages for ROA/ROE precision
        AVG(CAST(ISNULL(bs.total_assets,0) AS FLOAT)) OVER (
            PARTITION BY c.company_key ORDER BY is_.fiscal_year
            ROWS BETWEEN 1 PRECEDING AND CURRENT ROW)  AS avg_total_assets,
        AVG(CAST(ISNULL(bs.total_equity,0) AS FLOAT)) OVER (
            PARTITION BY c.company_key ORDER BY is_.fiscal_year
            ROWS BETWEEN 1 PRECEDING AND CURRENT ROW)  AS avg_total_equity
    FROM dw.dim_company c
    JOIN dw.fact_income_statement is_
        ON c.company_key = is_.company_key AND is_.period_type = 'ANNUAL'
    JOIN dw.fact_balance_sheet bs
        ON c.company_key = bs.company_key
       AND bs.period_type = 'ANNUAL' AND bs.fiscal_year = is_.fiscal_year
    JOIN dw.fact_cash_flow cf
        ON c.company_key = cf.company_key
       AND cf.period_type = 'ANNUAL' AND cf.fiscal_year = is_.fiscal_year
    JOIN dw.dim_industry i  ON c.industry_key = i.industry_key
    JOIN dw.dim_country  co ON c.country_key  = co.country_key
    WHERE c.is_current = 1
),
ratios AS (
    SELECT *,
        -- PROFITABILITY
        ROUND(CAST(gross_profit     AS FLOAT)/NULLIF(total_revenue,0)*100,2)  AS gross_margin_pct,
        ROUND(CAST(ebitda           AS FLOAT)/NULLIF(total_revenue,0)*100,2)  AS ebitda_margin_pct,
        ROUND(CAST(operating_income AS FLOAT)/NULLIF(total_revenue,0)*100,2)  AS operating_margin_pct,
        ROUND(CAST(net_income       AS FLOAT)/NULLIF(total_revenue,0)*100,2)  AS net_margin_pct,
        ROUND(CAST(net_income       AS FLOAT)/NULLIF(avg_total_assets,0)*100,2) AS roa_pct,
        ROUND(CAST(net_income       AS FLOAT)/NULLIF(avg_total_equity,0)*100,2) AS roe_pct,
        ROUND(CAST(net_income + interest_expense*0.79 AS FLOAT)
              /NULLIF(total_equity+long_term_debt+short_term_debt,0)*100,2)   AS roic_pct,
        -- LIQUIDITY
        ROUND(CAST(total_current_assets AS FLOAT)/NULLIF(total_current_liabilities,0),3) AS current_ratio,
        ROUND(CAST(total_current_assets-inventories AS FLOAT)/NULLIF(total_current_liabilities,0),3) AS quick_ratio,
        ROUND(CAST(cash_equivalents+short_term_investments AS FLOAT)/NULLIF(total_current_liabilities,0),3) AS cash_ratio,
        -- LEVERAGE
        ROUND(CAST(total_liabilities AS FLOAT)/NULLIF(total_equity,0),3)      AS debt_to_equity,
        ROUND(CAST(total_liabilities AS FLOAT)/NULLIF(total_assets,0),3)      AS debt_ratio,
        ROUND(CAST(ebitda AS FLOAT)/NULLIF(ABS(CASE WHEN interest_expense=0 THEN 1 ELSE interest_expense END),0),2) AS interest_coverage,
        ROUND(CAST(net_debt AS FLOAT)/NULLIF(ebitda,0),2)                     AS net_debt_to_ebitda,
        -- EFFICIENCY
        ROUND(CAST(total_revenue AS FLOAT)/NULLIF(avg_total_assets,0),3)      AS asset_turnover,
        ROUND(CAST(total_revenue AS FLOAT)/NULLIF(accounts_receivable_net,0),3) AS receivable_turnover,
        ROUND(365.0/NULLIF(CAST(total_revenue AS FLOAT)/NULLIF(accounts_receivable_net,0),0),1) AS dso,
        ROUND(365.0/NULLIF(CAST(total_revenue AS FLOAT)/NULLIF(accounts_payable,0),0),1)        AS dpo,
        -- FREE CASH FLOW
        ROUND(CAST(free_cash_flow AS FLOAT)/NULLIF(total_revenue,0)*100,2)    AS fcf_margin_pct,
        ROUND(CAST(free_cash_flow AS FLOAT)/NULLIF(net_income,0),3)           AS fcf_to_net_income
    FROM base
),
yoy AS (
    SELECT *,
        -- YoY Revenue Growth
        ROUND(CAST(total_revenue - LAG(total_revenue) OVER (PARTITION BY company_key ORDER BY fiscal_year) AS FLOAT)
              /NULLIF(ABS(LAG(total_revenue) OVER (PARTITION BY company_key ORDER BY fiscal_year)),0)*100,2) AS revenue_yoy_pct,
        -- YoY Net Income Growth
        ROUND(CAST(net_income - LAG(net_income) OVER (PARTITION BY company_key ORDER BY fiscal_year) AS FLOAT)
              /NULLIF(ABS(LAG(net_income) OVER (PARTITION BY company_key ORDER BY fiscal_year)),0)*100,2)    AS ni_yoy_pct,
        -- YoY EBITDA Growth
        ROUND(CAST(ebitda - LAG(ebitda) OVER (PARTITION BY company_key ORDER BY fiscal_year) AS FLOAT)
              /NULLIF(ABS(LAG(ebitda) OVER (PARTITION BY company_key ORDER BY fiscal_year)),0)*100,2)        AS ebitda_yoy_pct,
        -- YoY EPS Growth
        ROUND(CAST(eps_diluted - LAG(eps_diluted) OVER (PARTITION BY company_key ORDER BY fiscal_year) AS FLOAT)
              /NULLIF(ABS(LAG(eps_diluted) OVER (PARTITION BY company_key ORDER BY fiscal_year)),0)*100,2)   AS eps_yoy_pct,
        -- 3-Year Revenue CAGR
        ROUND((POWER(
            CAST(total_revenue AS FLOAT)/NULLIF(LAG(total_revenue,3) OVER (PARTITION BY company_key ORDER BY fiscal_year),0),
            1.0/3.0)-1.0)*100,2)                                                                             AS revenue_3yr_cagr,
        -- Rolling 3-year average net margin
        AVG(ROUND(CAST(net_income AS FLOAT)/NULLIF(total_revenue,0)*100,2))
            OVER (PARTITION BY company_key ORDER BY fiscal_year ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)   AS rolling_3yr_net_margin,
        -- Sector Rankings
        RANK() OVER (PARTITION BY gics_sector_name, fiscal_year
                     ORDER BY ROUND(CAST(net_income AS FLOAT)/NULLIF(avg_total_equity,0)*100,2) DESC)        AS sector_roe_rank,
        PERCENT_RANK() OVER (PARTITION BY gics_sector_name, fiscal_year
                             ORDER BY ROUND(CAST(net_income AS FLOAT)/NULLIF(total_revenue,0)*100,2))        AS net_margin_percentile,
        -- Cumulative Free Cash Flow
        SUM(free_cash_flow) OVER (PARTITION BY company_key ORDER BY fiscal_year
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)                          AS cumulative_fcf
    FROM ratios
)
SELECT * FROM yoy;
GO
PRINT '✓ mart.v_financial_ratios created.';
GO

-- ── bi.v_executive_scorecard ──────────────────────────────────
IF OBJECT_ID('bi.v_executive_scorecard','V') IS NOT NULL DROP VIEW bi.v_executive_scorecard;
GO
CREATE VIEW bi.v_executive_scorecard AS
SELECT
    c.ticker_symbol, c.company_name,
    i.gics_sector_name, co.country_name,
    r.fiscal_year,
    ROUND(r.total_revenue/1e6,2)     AS revenue_usd_m,
    ROUND(r.ebitda/1e6,2)            AS ebitda_usd_m,
    ROUND(r.net_income/1e6,2)        AS net_income_usd_m,
    r.gross_margin_pct, r.ebitda_margin_pct, r.operating_margin_pct, r.net_margin_pct,
    r.roe_pct, r.roa_pct, r.roic_pct,
    r.current_ratio, r.quick_ratio,
    r.debt_to_equity, r.interest_coverage, r.net_debt_to_ebitda,
    ROUND(r.free_cash_flow/1e6,2)    AS fcf_usd_m,
    r.fcf_margin_pct, r.asset_turnover, r.dso, r.dpo,
    r.revenue_yoy_pct, r.ebitda_yoy_pct, r.eps_yoy_pct, r.revenue_3yr_cagr,
    r.sector_roe_rank,
    -- KPI Traffic Lights
    CASE WHEN r.revenue_yoy_pct    >= 10  THEN 'GREEN' WHEN r.revenue_yoy_pct    >= 0   THEN 'AMBER' ELSE 'RED' END AS revenue_status,
    CASE WHEN r.ebitda_margin_pct  >= 20  THEN 'GREEN' WHEN r.ebitda_margin_pct  >= 10  THEN 'AMBER' ELSE 'RED' END AS margin_status,
    CASE WHEN r.net_debt_to_ebitda <= 2.0 THEN 'GREEN' WHEN r.net_debt_to_ebitda <= 3.5 THEN 'AMBER' ELSE 'RED' END AS leverage_status,
    CASE WHEN r.roe_pct            >= 15  THEN 'GREEN' WHEN r.roe_pct            >= 5   THEN 'AMBER' ELSE 'RED' END AS roe_status,
    CASE WHEN r.fcf_margin_pct     >= 10  THEN 'GREEN' WHEN r.fcf_margin_pct     >= 0   THEN 'AMBER' ELSE 'RED' END AS fcf_status,
    CASE
        WHEN (CASE WHEN r.revenue_yoy_pct >= 10 THEN 1 ELSE 0 END +
              CASE WHEN r.ebitda_margin_pct >= 20 THEN 1 ELSE 0 END +
              CASE WHEN r.net_debt_to_ebitda <= 2 THEN 1 ELSE 0 END +
              CASE WHEN r.fcf_margin_pct >= 10 THEN 1 ELSE 0 END +
              CASE WHEN r.roe_pct >= 15 THEN 1 ELSE 0 END) >= 4 THEN 'STRONG PERFORMER'
        WHEN (CASE WHEN r.revenue_yoy_pct >= 10 THEN 1 ELSE 0 END +
              CASE WHEN r.ebitda_margin_pct >= 20 THEN 1 ELSE 0 END +
              CASE WHEN r.net_debt_to_ebitda <= 2 THEN 1 ELSE 0 END +
              CASE WHEN r.fcf_margin_pct >= 10 THEN 1 ELSE 0 END +
              CASE WHEN r.roe_pct >= 15 THEN 1 ELSE 0 END) >= 2 THEN 'ADEQUATE PERFORMER'
        ELSE 'UNDERPERFORMER'
    END AS performance_band
FROM mart.v_financial_ratios r
JOIN dw.dim_company  c ON r.company_key = c.company_key AND c.is_current = 1
JOIN dw.dim_industry i ON c.industry_key = i.industry_key
JOIN dw.dim_country co ON c.country_key  = co.country_key;
GO
PRINT '✓ bi.v_executive_scorecard created.';
GO

-- ── credit.v_risk_dashboard ───────────────────────────────────
IF OBJECT_ID('credit.v_risk_dashboard','V') IS NOT NULL DROP VIEW credit.v_risk_dashboard;
GO
CREATE VIEW credit.v_risk_dashboard AS
SELECT
    b.borrower_id, b.borrower_name, b.borrower_type, b.internal_rating,
    lf.facility_id, lf.facility_type, lf.facility_status, lf.days_past_due,
    ROUND(lf.commitment_usd/1e6,3)      AS commitment_m,
    ROUND(lf.outstanding_balance/1e6,3) AS outstanding_m,
    ROUND(lf.undrawn_amount/1e6,3)      AS undrawn_m,
    ISNULL(lf.pd_pct, pm.pd_midpoint_pct)  AS effective_pd_pct,
    ISNULL(lf.lgd_pct, 45.0)               AS effective_lgd_pct,
    -- EAD = drawn + 75% of undrawn for revolvers
    CASE WHEN lf.facility_type = 'REVOLVER'
         THEN lf.outstanding_balance + 0.75 * lf.undrawn_amount
         ELSE lf.outstanding_balance
    END                                 AS ead_usd,
    ROUND(lf.expected_loss_usd,2)       AS expected_loss_usd,
    -- IFRS 9 Stage Classification
    CASE
        WHEN lf.facility_status = 'DEFAULT'             THEN 'STAGE 3'
        WHEN lf.days_past_due BETWEEN 30 AND 89         THEN 'STAGE 2'
        WHEN ISNULL(lf.pd_pct, pm.pd_midpoint_pct) > 1 THEN 'STAGE 2'
        ELSE 'STAGE 1'
    END AS ifrs9_stage,
    -- Risk Band
    CASE
        WHEN ISNULL(lf.pd_pct, pm.pd_midpoint_pct) < 0.5  THEN '1 - LOW RISK'
        WHEN ISNULL(lf.pd_pct, pm.pd_midpoint_pct) < 2.0  THEN '2 - MODERATE'
        WHEN ISNULL(lf.pd_pct, pm.pd_midpoint_pct) < 7.0  THEN '3 - ELEVATED'
        WHEN ISNULL(lf.pd_pct, pm.pd_midpoint_pct) < 20.0 THEN '4 - HIGH'
        ELSE '5 - CRITICAL'
    END AS risk_band
FROM credit.loan_facilities lf
JOIN credit.borrowers b ON lf.borrower_key = b.borrower_key
LEFT JOIN credit.pd_master_scale pm ON b.internal_rating = pm.rating;
GO
PRINT '✓ credit.v_risk_dashboard created.';
GO

-- ── fpa.v_variance_analysis ───────────────────────────────────
IF OBJECT_ID('fpa.v_variance_analysis','V') IS NOT NULL DROP VIEW fpa.v_variance_analysis;
GO
CREATE VIEW fpa.v_variance_analysis AS
SELECT
    a.company_key, cc.cost_center_name, ac.account_name, ac.account_type,
    a.fiscal_year, a.fiscal_month, a.actual_amount,
    b.budget_amount,
    a.actual_amount - ISNULL(b.budget_amount,0)                          AS variance_abs,
    ROUND(CAST(a.actual_amount - ISNULL(b.budget_amount,0) AS FLOAT)
          /NULLIF(ABS(b.budget_amount),0)*100,1)                         AS variance_pct,
    CASE ac.account_type
        WHEN 'EXPENSE' THEN CASE WHEN a.actual_amount < ISNULL(b.budget_amount,0) THEN 'FAVORABLE' ELSE 'UNFAVORABLE' END
        WHEN 'REVENUE' THEN CASE WHEN a.actual_amount > ISNULL(b.budget_amount,0) THEN 'FAVORABLE' ELSE 'UNFAVORABLE' END
        ELSE 'N/A'
    END AS variance_flag,
    SUM(a.actual_amount) OVER (
        PARTITION BY a.company_key, a.account_code, a.fiscal_year
        ORDER BY a.fiscal_month ROWS UNBOUNDED PRECEDING)                AS ytd_actual,
    SUM(ISNULL(b.budget_amount,0)) OVER (
        PARTITION BY a.company_key, a.account_code, a.fiscal_year
        ORDER BY a.fiscal_month ROWS UNBOUNDED PRECEDING)                AS ytd_budget
FROM fpa.actuals a
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
    WHERE budget_version = 'ORIGINAL'
) b ON a.company_key=b.company_key AND a.cost_center_key=b.cost_center_key
    AND a.account_code=b.account_code AND a.fiscal_year=b.fiscal_year
    AND a.fiscal_month=b.mon;
GO
PRINT '✓ fpa.v_variance_analysis created.';
GO

-- ── dw.fn_validate_warehouse ──────────────────────────────────
IF OBJECT_ID('dw.fn_validate_warehouse','IF') IS NOT NULL
    DROP FUNCTION dw.fn_validate_warehouse;
GO
CREATE FUNCTION dw.fn_validate_warehouse()
RETURNS TABLE AS RETURN
(
    SELECT 'Balance Sheet Equation' AS check_name,
           CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END AS status,
           'Mismatches: '+CAST(COUNT(*) AS VARCHAR) AS detail
    FROM dw.fact_balance_sheet
    WHERE ABS(ISNULL(total_assets,0)-ISNULL(total_liabilities,0)-ISNULL(total_equity,0)) > 1.0
    UNION ALL
    SELECT 'No Negative Revenue',
           CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END,
           'Violations: '+CAST(COUNT(*) AS VARCHAR)
    FROM dw.fact_income_statement WHERE total_revenue < 0
    UNION ALL
    SELECT 'Income Statement Records Exist',
           CASE WHEN COUNT(*)>0 THEN 'PASS' ELSE 'FAIL' END,
           'Records: '+CAST(COUNT(*) AS VARCHAR)
    FROM dw.fact_income_statement
    UNION ALL
    SELECT 'Balance Sheet Records Exist',
           CASE WHEN COUNT(*)>0 THEN 'PASS' ELSE 'FAIL' END,
           'Records: '+CAST(COUNT(*) AS VARCHAR)
    FROM dw.fact_balance_sheet
    UNION ALL
    SELECT 'Companies Loaded',
           CASE WHEN COUNT(*)>=5 THEN 'PASS' ELSE 'FAIL' END,
           'Active: '+CAST(COUNT(*) AS VARCHAR)
    FROM dw.dim_company WHERE is_current=1
    UNION ALL
    SELECT 'Loan Facilities Loaded',
           CASE WHEN COUNT(*)>=5 THEN 'PASS' ELSE 'FAIL' END,
           'Facilities: '+CAST(COUNT(*) AS VARCHAR)
    FROM credit.loan_facilities
    UNION ALL
    SELECT 'dim_date Coverage 2010-2030',
           CASE WHEN COUNT(*)>=7600 THEN 'PASS' ELSE 'FAIL' END,
           'Rows: '+CAST(COUNT(*) AS VARCHAR)
    FROM dw.dim_date
);
GO
PRINT '✓ dw.fn_validate_warehouse created.';
GO

-- ============================================================
-- STEP 13 – FINAL VERIFICATION (all 10 checks)
-- ============================================================
PRINT '';
PRINT '============================================';
PRINT '  FINAL VERIFICATION – 10 CHECKS';
PRINT '============================================';
GO

PRINT '-- CHECK 1: Dimension table row counts (expect: date=7670, company=10, industry=11, country=10, account=24)';
SELECT 'dim_date'     AS tbl, COUNT(*) AS rows FROM dw.dim_date     UNION ALL
SELECT 'dim_company',          COUNT(*)          FROM dw.dim_company UNION ALL
SELECT 'dim_industry',         COUNT(*)          FROM dw.dim_industry UNION ALL
SELECT 'dim_country',          COUNT(*)          FROM dw.dim_country  UNION ALL
SELECT 'dim_account',          COUNT(*)          FROM dw.dim_account;
GO

PRINT '-- CHECK 2: Fact table row counts (expect: IS=15, BS=10, CF=10)';
SELECT 'fact_income_statement' AS tbl, COUNT(*) AS rows FROM dw.fact_income_statement UNION ALL
SELECT 'fact_balance_sheet',           COUNT(*)          FROM dw.fact_balance_sheet    UNION ALL
SELECT 'fact_cash_flow',               COUNT(*)          FROM dw.fact_cash_flow;
GO

PRINT '-- CHECK 3: Financial Ratios (expect 10 rows - AAPL x5, MSFT x5. JPM is excluded: no BS/CF data seeded for banks in this dataset)';
SELECT
    ticker_symbol, company_name, fiscal_year,
    ROUND(total_revenue/1e6,1)  AS revenue_m,
    gross_margin_pct,
    ebitda_margin_pct,
    net_margin_pct,
    roe_pct,
    roa_pct,
    current_ratio,
    debt_to_equity,
    interest_coverage,
    revenue_yoy_pct,
    revenue_3yr_cagr,
    sector_roe_rank
FROM mart.v_financial_ratios
ORDER BY ticker_symbol, fiscal_year;
GO

PRINT '-- CHECK 4: Executive KPI Scorecard (expect 10 rows - AAPL x5, MSFT x5 - with GREEN/AMBER/RED)';
SELECT
    ticker_symbol, fiscal_year,
    revenue_usd_m, ebitda_usd_m, fcf_usd_m,
    ebitda_margin_pct, net_margin_pct, roe_pct,
    revenue_status, margin_status, leverage_status, roe_status,
    performance_band
FROM bi.v_executive_scorecard
ORDER BY ticker_symbol, fiscal_year;
GO

PRINT '-- CHECK 5: Credit Risk Dashboard (expect 5 rows)';
SELECT
    borrower_name, internal_rating, facility_type,
    facility_status, days_past_due,
    ROUND(outstanding_m,2)    AS outstanding_m,
    effective_pd_pct, effective_lgd_pct,
    ROUND(expected_loss_usd,0) AS expected_loss_usd,
    ifrs9_stage, risk_band
FROM credit.v_risk_dashboard
ORDER BY effective_pd_pct DESC;
GO

PRINT '-- CHECK 6: Amortisation Schedule (expect 60 rows: $5M, 7%, 60 months)';
EXEC credit.usp_amortisation_schedule
    @principal   = 5000000,
    @annual_rate = 7.0,
    @term_months = 60,
    @start_date  = '2024-01-01';
GO

PRINT '-- CHECK 7: Data Quality (all 7 checks should show PASS)';
SELECT * FROM dw.fn_validate_warehouse();
GO

PRINT '-- CHECK 8: Credit Risk Summary by Rating and Status';
EXEC credit.usp_credit_risk_summary;
GO

PRINT '-- CHECK 9: SCD Type 2 – update Apple market cap';
EXEC dw.usp_upsert_company_scd2
    @p_company_id = 'AAPL-US',
    @p_ticker     = 'AAPL',
    @p_name       = 'Apple Inc.',
    @p_market_cap = 3500000.00,
    @p_exchange   = 'NASDAQ';
SELECT company_key, ticker_symbol, market_cap_usd_m,
       scd_start_date, scd_end_date, is_current
FROM dw.dim_company WHERE company_id='AAPL-US' ORDER BY company_key;
GO

PRINT '-- CHECK 10: Full object inventory';
SELECT
    o.type_desc      AS object_type,
    s.name           AS schema_name,
    o.name           AS object_name,
    CONVERT(CHAR(10),o.create_date,23) AS created
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.type IN ('U','V','P','IF','TR')
  AND s.name NOT IN ('sys','INFORMATION_SCHEMA')
ORDER BY object_type, schema_name, object_name;
GO

PRINT '';
PRINT '============================================';
PRINT '  ALL STEPS COMPLETE';
PRINT '  FinancePortfolio is fully operational';
PRINT '============================================';
GO

