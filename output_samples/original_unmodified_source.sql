
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

PRINT '-- CHECK 3: Financial Ratios (expect 15 rows – AAPL x5, MSFT x5, JPM x5)';
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

PRINT '-- CHECK 4: Executive KPI Scorecard (expect 15 rows with GREEN/AMBER/RED)';
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

-- ============================================================
-- SQL PORTFOLIO – PART 3: FINAL COMPLETION
-- Projects: Forensic/Fraud, Advanced Window Functions,
--           Dynamic SQL, Performance Tuning, Interview Queries,
--           GitHub README Structure
-- Engine : SQL Server 2017+ Express / SSMS
-- Run    : After Part 1 and Part 2
-- ============================================================

USE FinancePortfolio;
GO

-- ============================================================
-- MODULE 6 – FORENSIC ACCOUNTING & FRAUD DETECTION
-- ============================================================

-- ── Transactions Table ────────────────────────────────────────
IF OBJECT_ID('forensic.transactions','U') IS NULL
BEGIN
    CREATE TABLE forensic.transactions (
        transaction_key    BIGINT        IDENTITY(1,1) PRIMARY KEY,
        transaction_id     VARCHAR(40)   NOT NULL UNIQUE,
        company_key        INT           REFERENCES dw.dim_company(company_key),
        transaction_date   DATE          NOT NULL,
        posting_date       DATE,
        transaction_type   VARCHAR(30)   NOT NULL,
        debit_account      VARCHAR(20)   REFERENCES dw.dim_account(account_code),
        credit_account     VARCHAR(20)   REFERENCES dw.dim_account(account_code),
        amount             DECIMAL(20,4) NOT NULL,
        currency           CHAR(3)       DEFAULT 'USD',
        vendor_id          VARCHAR(30),
        vendor_name        NVARCHAR(200),
        description        NVARCHAR(500),
        reference_number   VARCHAR(50),
        cost_center        VARCHAR(30),
        created_by         VARCHAR(80)   NOT NULL,
        approved_by        VARCHAR(80),
        approval_date      DATE,
        is_system_generated BIT          DEFAULT 0,
        is_reversed        BIT           DEFAULT 0,
        reversal_ref       VARCHAR(40),
        created_at         DATETIME2     DEFAULT GETDATE()
    );
    -- Seed sample transactions for fraud analysis
    INSERT INTO forensic.transactions
        (transaction_id, company_key, transaction_date, posting_date,
         transaction_type, debit_account, credit_account,
         amount, vendor_id, vendor_name, description,
         created_by, approved_by, approval_date, is_system_generated)
    SELECT v.tid, c.company_key, CAST(v.txdate AS DATE), CAST(v.postdate AS DATE),
           v.txtype, v.dacc, v.cacc, v.amt, v.vid, v.vname, v.descr,
           v.cby, v.aby, CAST(v.apdate AS DATE), v.sysgened
    FROM (VALUES
    -- Normal transactions
    ('TXN-2023-001','AAPL-US','2023-01-15','2023-01-15','PAYMENT','6020','2110',CAST(45000 AS DECIMAL(20,4)),'VND-001','Dell Technologies','IT Equipment Purchase','jsmith','mwilliams','2023-01-14',CAST(0 AS BIT)),
    ('TXN-2023-002','AAPL-US','2023-01-28','2023-01-28','PAYMENT','6020','2110',CAST(12500 AS DECIMAL(20,4)),'VND-002','Office Depot','Office Supplies Q1','jsmith','mwilliams','2023-01-27',CAST(0 AS BIT)),
    ('TXN-2023-003','AAPL-US','2023-02-10','2023-02-10','PAYMENT','6010','2110',CAST(250000 AS DECIMAL(20,4)),'VND-003','Consulting Partners Ltd','Strategy Consulting Feb','abrook','mwilliams','2023-02-09',CAST(0 AS BIT)),
    -- Duplicate payment indicators (same vendor, same amount, close dates)
    ('TXN-2023-004','AAPL-US','2023-03-01','2023-03-01','PAYMENT','6020','2110',CAST(45000 AS DECIMAL(20,4)),'VND-001','Dell Technologies','IT Equipment Purchase','jsmith','mwilliams','2023-02-28',CAST(0 AS BIT)),
    ('TXN-2023-005','AAPL-US','2023-03-05','2023-03-05','PAYMENT','6020','2110',CAST(45000 AS DECIMAL(20,4)),'VND-001','Dell Technologies','IT Equipment - Duplicate?','bwatson','klee','2023-03-04',CAST(0 AS BIT)),
    -- Just-below-threshold (fraud indicator: splitting to avoid approval)
    ('TXN-2023-006','AAPL-US','2023-03-15','2023-03-15','PAYMENT','6010','2110',CAST(4995 AS DECIMAL(20,4)),'VND-004','Shadow Analytics Inc','Data Services Mar','rcooper',NULL,NULL,CAST(0 AS BIT)),
    ('TXN-2023-007','AAPL-US','2023-03-16','2023-03-16','PAYMENT','6010','2110',CAST(4990 AS DECIMAL(20,4)),'VND-004','Shadow Analytics Inc','Data Services Mar 2','rcooper',NULL,NULL,CAST(0 AS BIT)),
    ('TXN-2023-008','AAPL-US','2023-03-17','2023-03-17','PAYMENT','6010','2110',CAST(4985 AS DECIMAL(20,4)),'VND-004','Shadow Analytics Inc','Data Services Mar 3','rcooper',NULL,NULL,CAST(0 AS BIT)),
    -- Self-approval (created_by = approved_by – control violation)
    ('TXN-2023-009','AAPL-US','2023-04-01','2023-04-01','PAYMENT','6020','2110',CAST(18750 AS DECIMAL(20,4)),'VND-005','Acme Supplies Co','Q2 Supplies','bwatson','bwatson','2023-04-01',CAST(0 AS BIT)),
    -- Weekend posting (unusual)
    ('TXN-2023-010','AAPL-US','2023-04-08','2023-04-10','PAYMENT','6020','2110',CAST(75000 AS DECIMAL(20,4)),'VND-006','Premium Vendor LLC','Special Services April','mturner','mturner','2023-04-08',CAST(0 AS BIT)),
    -- Round-dollar (Benford bias)
    ('TXN-2023-011','AAPL-US','2023-05-01','2023-05-01','PAYMENT','6010','2110',CAST(100000 AS DECIMAL(20,4)),'VND-007','Tech Research Co','Research Project Q2','jsmith','mwilliams','2023-04-30',CAST(0 AS BIT)),
    ('TXN-2023-012','AAPL-US','2023-05-15','2023-05-15','PAYMENT','6010','2110',CAST(50000 AS DECIMAL(20,4)),'VND-007','Tech Research Co','Research Supplement','jsmith','mwilliams','2023-05-14',CAST(0 AS BIT)),
    -- Normal system-generated
    ('TXN-2023-013','AAPL-US','2023-06-30','2023-06-30','ACCRUAL','6030','2110',CAST(960000 AS DECIMAL(20,4)),NULL,NULL,'Monthly D&A Accrual Jun 2023','SYSTEM',NULL,NULL,CAST(1 AS BIT)),
    ('TXN-2023-014','AAPL-US','2023-07-15','2023-07-15','PAYMENT','6020','2110',CAST(33200 AS DECIMAL(20,4)),'VND-002','Office Depot','Office Supplies Q3','abrook','mwilliams','2023-07-14',CAST(0 AS BIT)),
    ('TXN-2023-015','AAPL-US','2023-12-29','2023-12-30','PAYMENT','6020','2110',CAST(9998 AS DECIMAL(20,4)),'VND-008','Year-End Vendor','Year-end supplies','rcooper','rcooper','2023-12-29',CAST(0 AS BIT))
    ) v(tid,coid,txdate,postdate,txtype,dacc,cacc,amt,vid,vname,descr,cby,aby,apdate,sysgened)
    JOIN dw.dim_company c ON c.company_id=v.coid AND c.is_current=1;
    PRINT '✓ forensic.transactions created and seeded (15 rows).';
END
GO

-- ── Vendors Table ─────────────────────────────────────────────
IF OBJECT_ID('forensic.vendors','U') IS NULL
BEGIN
    CREATE TABLE forensic.vendors (
        vendor_key       INT           IDENTITY(1,1) PRIMARY KEY,
        vendor_id        VARCHAR(30)   NOT NULL UNIQUE,
        vendor_name      NVARCHAR(200) NOT NULL,
        tax_id           VARCHAR(30),
        bank_account     VARCHAR(40),
        bank_routing     VARCHAR(20),
        address_line1    NVARCHAR(200),
        city             NVARCHAR(100),
        country          CHAR(3),
        contact_email    VARCHAR(150),
        is_active        BIT           DEFAULT 1,
        approved_by      VARCHAR(80),
        approval_date    DATE,
        created_at       DATETIME2     DEFAULT GETDATE()
    );
    INSERT INTO forensic.vendors
        (vendor_id,vendor_name,tax_id,bank_account,address_line1,city,country,contact_email,is_active,approved_by,approval_date)
    VALUES
    ('VND-001','Dell Technologies',  '98-0122790','****4521','1 Dell Way',          'Round Rock','USA','accounts@dell.com',           1,'procurement','2020-01-15'),
    ('VND-002','Office Depot',       '59-2663954','****8832','6600 N Military Trail','Boca Raton','USA','ar@officedepot.com',          1,'procurement','2020-03-10'),
    ('VND-003','Consulting Partners','XX-1234567','****1193','100 Park Ave',         'New York',  'USA','billing@cpartners.com',       1,'legal',      '2021-05-20'),
    ('VND-004','Shadow Analytics Inc','XX-9999999','****7761','Unknown Address',     'Unknown',   'USA','shadow@temp-email.com',       1,NULL,         NULL),
    ('VND-005','Acme Supplies Co',   'XX-5555555','****3309','45 Industrial Blvd',  'Chicago',   'USA','accounts@acme.com',           0,'procurement','2022-01-01'),
    ('VND-006','Premium Vendor LLC', 'XX-8888888','****9921','Suite 100 Tower Blvd','Miami',     'USA','info@premiumvendor.com',      1,'finance',    '2022-06-15'),
    ('VND-007','Tech Research Co',   'XX-7777777','****4400','200 Research Dr',     'Austin',    'USA','billing@techresearch.com',    1,'procurement','2021-11-30'),
    ('VND-008','Year-End Vendor',    'XX-0000000','****1122','PO Box 999',          'Unknown',   'USA','yev@disposable.net',          0,NULL,         NULL);
    PRINT '✓ forensic.vendors created and seeded (8 rows).';
END
GO

-- ── Fraud Detection View 1: Duplicate Payment Analysis ────────
IF OBJECT_ID('forensic.v_duplicate_payments','V') IS NOT NULL DROP VIEW forensic.v_duplicate_payments;
GO
CREATE VIEW forensic.v_duplicate_payments AS
WITH payment_window AS (
    SELECT
        t.vendor_id, t.vendor_name,
        t.amount, t.currency,
        t.transaction_date, t.transaction_id,
        t.description, t.created_by, t.approved_by,
        -- Count same vendor+amount combinations within 30-day window
        COUNT(*) OVER (
            PARTITION BY t.vendor_id, t.amount, t.currency
            ORDER BY t.transaction_date
            ROWS BETWEEN 30 PRECEDING AND CURRENT ROW
        )                                                    AS same_amount_30d,
        LAG(t.transaction_date) OVER (
            PARTITION BY t.vendor_id, t.amount
            ORDER BY t.transaction_date
        )                                                    AS prev_same_amount_date,
        LAG(t.transaction_id) OVER (
            PARTITION BY t.vendor_id, t.amount
            ORDER BY t.transaction_date
        )                                                    AS prev_transaction_id
    FROM forensic.transactions t
    WHERE t.transaction_type = 'PAYMENT' AND t.is_reversed = 0
)
SELECT
    vendor_id, vendor_name, amount, currency,
    transaction_date, transaction_id, prev_transaction_id,
    DATEDIFF(DAY, prev_same_amount_date, transaction_date) AS days_since_same,
    same_amount_30d,
    CASE
        WHEN same_amount_30d >= 3 AND DATEDIFF(DAY,prev_same_amount_date,transaction_date) <= 7  THEN 'CRITICAL'
        WHEN same_amount_30d >= 2 AND DATEDIFF(DAY,prev_same_amount_date,transaction_date) <= 14 THEN 'HIGH'
        WHEN same_amount_30d >= 2 AND DATEDIFF(DAY,prev_same_amount_date,transaction_date) <= 30 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS duplicate_risk_level,
    amount * (same_amount_30d - 1) AS potential_duplicate_loss
FROM payment_window
WHERE same_amount_30d > 1;
GO
PRINT '✓ forensic.v_duplicate_payments created.';
GO

-- ── Fraud Detection View 2: Expense Manipulation Indicators ───
IF OBJECT_ID('forensic.v_expense_anomalies','V') IS NOT NULL DROP VIEW forensic.v_expense_anomalies;
GO
CREATE VIEW forensic.v_expense_anomalies AS
WITH scored AS (
    SELECT
        t.transaction_id, t.company_key,
        t.vendor_id, t.vendor_name,
        t.transaction_date, t.amount,
        t.created_by, t.approved_by,
        t.is_system_generated,
        -- Round-dollar test
        CASE WHEN ABS(t.amount - ROUND(t.amount,0)) < 0.01 THEN 1 ELSE 0 END   AS is_round_dollar,
        -- Just-below approval thresholds
        CASE WHEN t.amount BETWEEN 4900 AND 5000   THEN 1 ELSE 0 END            AS below_5k_threshold,
        CASE WHEN t.amount BETWEEN 9900 AND 10000  THEN 1 ELSE 0 END            AS below_10k_threshold,
        CASE WHEN t.amount BETWEEN 24900 AND 25000 THEN 1 ELSE 0 END            AS below_25k_threshold,
        -- Weekend posting
        CASE WHEN DATEPART(WEEKDAY,t.transaction_date) IN (1,7) THEN 1 ELSE 0 END AS is_weekend_posting,
        -- Period-end posting (last 3 days of month)
        CASE WHEN DAY(t.transaction_date) >= 28 AND MONTH(t.transaction_date) IN (3,6,9,12) THEN 1 ELSE 0 END AS is_period_end,
        -- Self-approval
        CASE WHEN t.created_by = t.approved_by THEN 1 ELSE 0 END                AS is_self_approved,
        -- No approval at all
        CASE WHEN t.approved_by IS NULL AND t.amount > 5000 THEN 1 ELSE 0 END   AS missing_approval,
        COUNT(*) OVER (PARTITION BY t.vendor_id)                                  AS vendor_txn_count,
        SUM(t.amount) OVER (PARTITION BY t.vendor_id)                             AS vendor_total_spend
    FROM forensic.transactions t
    JOIN dw.dim_account a ON t.debit_account=a.account_code
    WHERE a.account_type='EXPENSE' AND t.is_system_generated=0
)
SELECT *,
    -- Composite Fraud Risk Score (0-100)
    (is_round_dollar*10 + below_5k_threshold*20 + below_10k_threshold*15 +
     below_25k_threshold*15 + is_weekend_posting*15 + is_period_end*10 +
     is_self_approved*30 + missing_approval*25)                               AS fraud_score,
    CASE
        WHEN (is_round_dollar*10+below_5k_threshold*20+below_10k_threshold*15+
              below_25k_threshold*15+is_weekend_posting*15+is_period_end*10+
              is_self_approved*30+missing_approval*25) >= 60 THEN 'CRITICAL – Immediate Review'
        WHEN (is_round_dollar*10+below_5k_threshold*20+below_10k_threshold*15+
              below_25k_threshold*15+is_weekend_posting*15+is_period_end*10+
              is_self_approved*30+missing_approval*25) >= 40 THEN 'HIGH – Supervisor Alert'
        WHEN (is_round_dollar*10+below_5k_threshold*20+below_10k_threshold*15+
              below_25k_threshold*15+is_weekend_posting*15+is_period_end*10+
              is_self_approved*30+missing_approval*25) >= 20 THEN 'MEDIUM – Sample Review'
        ELSE 'LOW – Routine'
    END AS audit_priority
FROM scored
WHERE (is_round_dollar+below_5k_threshold+below_10k_threshold+below_25k_threshold+
       is_weekend_posting+is_period_end+is_self_approved+missing_approval) > 0;
GO
PRINT '✓ forensic.v_expense_anomalies created.';
GO

-- ── Fraud Detection View 3: Vendor Risk Scorecard ─────────────
IF OBJECT_ID('forensic.v_vendor_risk_scorecard','V') IS NOT NULL DROP VIEW forensic.v_vendor_risk_scorecard;
GO
CREATE VIEW forensic.v_vendor_risk_scorecard AS
WITH dup_risk AS (
    SELECT vendor_id,
           COUNT(*)                 AS dup_flag_count,
           SUM(potential_duplicate_loss) AS potential_dup_loss
    FROM forensic.v_duplicate_payments
    WHERE duplicate_risk_level IN ('HIGH','CRITICAL')
    GROUP BY vendor_id
),
exp_risk AS (
    SELECT vendor_id,
           AVG(fraud_score)         AS avg_fraud_score,
           COUNT(*)                 AS flagged_txn_count
    FROM forensic.v_expense_anomalies
    WHERE fraud_score >= 20
    GROUP BY vendor_id
)
SELECT
    v.vendor_id, v.vendor_name, v.tax_id,
    v.is_active, v.approval_date,
    ISNULL(d.dup_flag_count,0)        AS duplicate_flag_count,
    ISNULL(d.potential_dup_loss,0)    AS potential_duplicate_loss,
    ISNULL(e.avg_fraud_score,0)       AS avg_expense_fraud_score,
    ISNULL(e.flagged_txn_count,0)     AS flagged_txn_count,
    -- Composite Vendor Risk Score
    ISNULL(d.dup_flag_count,0)*15
    + ISNULL(e.avg_fraud_score,0)*0.5
    + ISNULL(e.flagged_txn_count,0)*5 AS overall_vendor_risk_score,
    CASE
        WHEN ISNULL(d.dup_flag_count,0)*15+ISNULL(e.avg_fraud_score,0)*0.5+ISNULL(e.flagged_txn_count,0)*5 >= 80 THEN 'CRITICAL'
        WHEN ISNULL(d.dup_flag_count,0)*15+ISNULL(e.avg_fraud_score,0)*0.5+ISNULL(e.flagged_txn_count,0)*5 >= 50 THEN 'HIGH'
        WHEN ISNULL(d.dup_flag_count,0)*15+ISNULL(e.avg_fraud_score,0)*0.5+ISNULL(e.flagged_txn_count,0)*5 >= 25 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS risk_tier
FROM forensic.vendors v
LEFT JOIN dup_risk d ON v.vendor_id=d.vendor_id
LEFT JOIN exp_risk e ON v.vendor_id=e.vendor_id
WHERE ISNULL(d.dup_flag_count,0)>0 OR ISNULL(e.flagged_txn_count,0)>0;
GO
PRINT '✓ forensic.v_vendor_risk_scorecard created.';
GO

-- ============================================================
-- MODULE 7 – ADVANCED WINDOW FUNCTIONS SHOWCASE
-- Demonstrates all major window function patterns
-- ============================================================

-- ── Advanced Analytics: Financial Ranking Engine ──────────────
IF OBJECT_ID('mart.v_ranking_engine','V') IS NOT NULL DROP VIEW mart.v_ranking_engine;
GO
CREATE VIEW mart.v_ranking_engine AS
SELECT
    ticker_symbol, company_name, gics_sector_name, fiscal_year,
    total_revenue, ebitda, net_income, free_cash_flow,
    -- RANK vs DENSE_RANK vs ROW_NUMBER (each behaves differently on ties)
    RANK()       OVER (PARTITION BY gics_sector_name,fiscal_year ORDER BY CASE WHEN ebitda_margin_pct IS NULL THEN 1 ELSE 0 END, ebitda_margin_pct DESC) AS rank_ebitda_margin,
    DENSE_RANK() OVER (PARTITION BY gics_sector_name,fiscal_year ORDER BY roe_pct DESC)                      AS dense_rank_roe,
    ROW_NUMBER() OVER (PARTITION BY fiscal_year                  ORDER BY total_revenue DESC)                AS revenue_row_num,
    -- NTILE splits into equal buckets (quintiles)
    NTILE(5) OVER (PARTITION BY gics_sector_name,fiscal_year ORDER BY ebitda_margin_pct DESC)                AS ebitda_quintile,
    NTILE(4) OVER (PARTITION BY fiscal_year                  ORDER BY roe_pct DESC)                         AS roe_quartile,
    -- PERCENT_RANK: 0.0 = lowest, 1.0 = highest
    ROUND(PERCENT_RANK() OVER (PARTITION BY gics_sector_name,fiscal_year ORDER BY net_margin_pct)*100,1)     AS net_margin_percentile,
    ROUND(PERCENT_RANK() OVER (PARTITION BY fiscal_year ORDER BY total_revenue)*100,1)                       AS revenue_size_percentile,
    -- CUME_DIST: cumulative distribution
    ROUND(CUME_DIST() OVER (PARTITION BY gics_sector_name,fiscal_year ORDER BY roe_pct)*100,1)               AS roe_cume_dist,
    -- LAG/LEAD: prior and next year
    LAG(total_revenue,1)  OVER (PARTITION BY company_key ORDER BY fiscal_year) AS prior_yr_revenue,
    LEAD(total_revenue,1) OVER (PARTITION BY company_key ORDER BY fiscal_year) AS next_yr_revenue,
    -- FIRST_VALUE/LAST_VALUE: anchor comparisons
    FIRST_VALUE(total_revenue) OVER (PARTITION BY company_key ORDER BY fiscal_year
                                     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS first_yr_revenue,
    LAST_VALUE(total_revenue)  OVER (PARTITION BY company_key ORDER BY fiscal_year
                                     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_yr_revenue,
    -- Running totals
    SUM(net_income) OVER (PARTITION BY company_key ORDER BY fiscal_year
                          ROWS UNBOUNDED PRECEDING)  AS cumulative_net_income,
    SUM(free_cash_flow) OVER (PARTITION BY company_key ORDER BY fiscal_year
                              ROWS UNBOUNDED PRECEDING) AS cumulative_fcf,
    -- Rolling statistics
    AVG(CAST(ebitda_margin_pct AS FLOAT)) OVER (PARTITION BY company_key ORDER BY fiscal_year
                                                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS rolling_3yr_ebitda_margin,
    STDEV(CAST(roe_pct AS FLOAT)) OVER (PARTITION BY company_key ORDER BY fiscal_year
                                        ROWS BETWEEN 4 PRECEDING AND CURRENT ROW)         AS rolling_5yr_roe_stdev,
    -- Revenue as % of sector total that year
    ROUND(CAST(total_revenue AS FLOAT)
          / NULLIF(SUM(CAST(total_revenue AS FLOAT)) OVER (PARTITION BY gics_sector_name,fiscal_year),0)*100,2) AS sector_revenue_share_pct
FROM mart.v_financial_ratios;
GO
PRINT '✓ mart.v_ranking_engine created (RANK/DENSE_RANK/NTILE/PERCENT_RANK/CUME_DIST/FIRST_VALUE/LAST_VALUE).';
GO

-- ── Recursive CTE: Loan Amortisation Schedule (table format) ──
IF OBJECT_ID('credit.v_facility_amortisation','V') IS NOT NULL DROP VIEW credit.v_facility_amortisation;
GO
-- Note: Recursive CTEs in views require MAXRECURSION hint – not allowed in views.
-- So we store this as a stored procedure that returns the full schedule table.
IF OBJECT_ID('credit.usp_all_facility_schedules','P') IS NOT NULL DROP PROCEDURE credit.usp_all_facility_schedules;
GO
CREATE PROCEDURE credit.usp_all_facility_schedules
AS
BEGIN
    SET NOCOUNT ON;
    -- Generate amortisation for each TERM_LOAN facility
    -- Uses a helper temp table approach (recursive CTEs can't be in views in SQL Server)
    CREATE TABLE #results (
        facility_id     VARCHAR(30),
        borrower_name   NVARCHAR(200),
        period          INT,
        payment_date    DATE,
        opening_balance DECIMAL(18,4),
        monthly_payment DECIMAL(18,4),
        interest_portion DECIMAL(18,4),
        principal_portion DECIMAL(18,4),
        closing_balance DECIMAL(18,4),
        cumulative_interest DECIMAL(18,4)
    );

    DECLARE @fid VARCHAR(30), @bname NVARCHAR(200),
            @principal DECIMAL(18,4), @rate DECIMAL(8,4),
            @orig DATE, @mat DATE, @months INT;

    DECLARE cur CURSOR FOR
        SELECT lf.facility_id, b.borrower_name,
               lf.outstanding_balance, lf.interest_rate_pct,
               lf.origination_date, lf.maturity_date,
               DATEDIFF(MONTH, lf.origination_date, lf.maturity_date)
        FROM credit.loan_facilities lf
        JOIN credit.borrowers b ON lf.borrower_key=b.borrower_key
        WHERE lf.facility_type='TERM_LOAN' AND lf.outstanding_balance > 0;

    OPEN cur;
    FETCH NEXT FROM cur INTO @fid,@bname,@principal,@rate,@orig,@mat,@months;
    WHILE @@FETCH_STATUS=0
    BEGIN
        DECLARE @r FLOAT = CAST(@rate AS FLOAT)/100.0/12.0;
        DECLARE @pmt DECIMAL(18,4) = CAST(
            @principal * (@r / (1.0 - POWER(1.0+@r, -CAST(@months AS FLOAT))))
        AS DECIMAL(18,4));

        WITH amort (period, payment_date, opening_bal, monthly_payment,
                    interest_portion, principal_portion, closing_bal, cumulative_interest)
        AS (
            SELECT
                CAST(1 AS INT),
                CAST(DATEADD(MONTH,1,@orig) AS DATE),
                CAST(@principal AS DECIMAL(18,4)),
                CAST(@pmt AS DECIMAL(18,4)),
                CAST(ROUND(CAST(@principal AS FLOAT)*@r,4) AS DECIMAL(18,4)),
                CAST(ROUND(CAST(@pmt AS FLOAT)-CAST(@principal AS FLOAT)*@r,4) AS DECIMAL(18,4)),
                CAST(ROUND(CAST(@principal AS FLOAT)-(CAST(@pmt AS FLOAT)-CAST(@principal AS FLOAT)*@r),4) AS DECIMAL(18,4)),
                CAST(ROUND(CAST(@principal AS FLOAT)*@r,4) AS DECIMAL(18,4))
            UNION ALL
            SELECT
                CAST(a.period+1 AS INT),
                CAST(DATEADD(MONTH,a.period+1,@orig) AS DATE),
                CAST(a.closing_bal AS DECIMAL(18,4)),
                CAST(@pmt AS DECIMAL(18,4)),
                CAST(ROUND(CAST(a.closing_bal AS FLOAT)*@r,4) AS DECIMAL(18,4)),
                CAST(ROUND(CAST(@pmt AS FLOAT)-CAST(a.closing_bal AS FLOAT)*@r,4) AS DECIMAL(18,4)),
                CAST(CASE WHEN CAST(a.closing_bal AS FLOAT)-(CAST(@pmt AS FLOAT)-CAST(a.closing_bal AS FLOAT)*@r)<0 THEN 0.0
                     ELSE ROUND(CAST(a.closing_bal AS FLOAT)-(CAST(@pmt AS FLOAT)-CAST(a.closing_bal AS FLOAT)*@r),4) END AS DECIMAL(18,4)),
                CAST(a.cumulative_interest+ROUND(CAST(a.closing_bal AS FLOAT)*@r,4) AS DECIMAL(18,4))
            FROM amort a
            WHERE a.period < @months AND a.closing_bal > CAST(0.01 AS DECIMAL(18,4))
        )
        INSERT INTO #results
        SELECT @fid, @bname, period, payment_date, opening_bal,
               monthly_payment, interest_portion, principal_portion,
               closing_bal, cumulative_interest
        FROM amort
        OPTION (MAXRECURSION 500);

        FETCH NEXT FROM cur INTO @fid,@bname,@principal,@rate,@orig,@mat,@months;
    END
    CLOSE cur; DEALLOCATE cur;

    SELECT * FROM #results ORDER BY facility_id, period;
    DROP TABLE #results;
END;
GO
PRINT '✓ credit.usp_all_facility_schedules created (cursor + recursive CTE).';
GO

-- ============================================================
-- MODULE 8 – DYNAMIC SQL & PERFORMANCE TUNING
-- ============================================================

-- ── Dynamic SQL: Pivot Monthly Revenue by Year ────────────────
IF OBJECT_ID('fpa.usp_pivot_monthly_revenue','P') IS NOT NULL DROP PROCEDURE fpa.usp_pivot_monthly_revenue;
GO
CREATE PROCEDURE fpa.usp_pivot_monthly_revenue
    @fiscal_year SMALLINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql   NVARCHAR(MAX);
    DECLARE @cols  NVARCHAR(MAX) = '';
    DECLARE @months TABLE (mn INT, lbl VARCHAR(5));
    INSERT INTO @months VALUES (1,'Jan'),(2,'Feb'),(3,'Mar'),(4,'Apr'),(5,'May'),(6,'Jun'),
                               (7,'Jul'),(8,'Aug'),(9,'Sep'),(10,'Oct'),(11,'Nov'),(12,'Dec');

    SELECT @cols = @cols + N'SUM(CASE WHEN fiscal_month=' + CAST(mn AS NVARCHAR) +
                   N' THEN actual_amount ELSE 0 END) AS [' + lbl + N'],'
    FROM @months;
    SET @cols = LEFT(@cols, LEN(@cols)-1);

    SET @sql = N'
    SELECT
        c.ticker_symbol,
        cc.cost_center_name,
        a.account_code,
        ac.account_name,
        ' + @cols + N',
        SUM(a.actual_amount) AS Full_Year_Total
    FROM fpa.actuals a
    JOIN dw.dim_company c ON a.company_key=c.company_key
    JOIN fpa.dim_cost_center cc ON a.cost_center_key=cc.cost_center_key
    JOIN dw.dim_account ac ON a.account_code=ac.account_code
    WHERE a.fiscal_year=' + CAST(@fiscal_year AS NVARCHAR) + N'
    GROUP BY c.ticker_symbol, cc.cost_center_name, a.account_code, ac.account_name
    ORDER BY c.ticker_symbol, a.account_code;';

    EXEC sp_executesql @sql;
END;
GO
PRINT '✓ fpa.usp_pivot_monthly_revenue created (dynamic SQL PIVOT).';
GO

-- ── Performance: Index Usage Monitor ─────────────────────────
IF OBJECT_ID('governance.v_index_usage','V') IS NOT NULL DROP VIEW governance.v_index_usage;
GO
CREATE VIEW governance.v_index_usage AS
SELECT
    s.name                                        AS schema_name,
    t.name                                        AS table_name,
    i.name                                        AS index_name,
    i.type_desc                                   AS index_type,
    ius.user_seeks, ius.user_scans, ius.user_lookups,
    ius.user_seeks + ius.user_scans + ius.user_lookups AS total_reads,
    ius.user_updates,
    ius.last_user_seek, ius.last_user_scan,
    ROUND(CAST(ps.reserved_page_count AS FLOAT)*8.0/1024,2)  AS size_mb,
    CASE
        WHEN ius.user_seeks+ius.user_scans+ius.user_lookups = 0 THEN 'UNUSED – review'
        WHEN ius.user_seeks+ius.user_scans+ius.user_lookups < 50 THEN 'RARELY USED'
        ELSE 'ACTIVE'
    END AS usage_status
FROM sys.indexes i
JOIN sys.tables t ON i.object_id=t.object_id
JOIN sys.schemas s ON t.schema_id=s.schema_id
LEFT JOIN sys.dm_db_index_usage_stats ius
    ON i.object_id=ius.object_id AND i.index_id=ius.index_id
    AND ius.database_id=DB_ID()
LEFT JOIN sys.dm_db_partition_stats ps
    ON i.object_id=ps.object_id AND i.index_id=ps.index_id
WHERE s.name NOT IN ('sys','INFORMATION_SCHEMA')
  AND i.type > 0;                          -- Exclude heaps
GO
PRINT '✓ governance.v_index_usage created.';
GO

-- ── Performance: Table Size and Bloat ────────────────────────
IF OBJECT_ID('governance.v_table_sizes','V') IS NOT NULL DROP VIEW governance.v_table_sizes;
GO
CREATE VIEW governance.v_table_sizes AS
SELECT
    s.name                                                    AS schema_name,
    t.name                                                    AS table_name,
    SUM(ps.row_count)                                         AS row_count,
    ROUND(SUM(ps.reserved_page_count)*8.0/1024,2)            AS reserved_mb,
    ROUND(SUM(ps.used_page_count)*8.0/1024,2)                AS used_mb,
    ROUND((SUM(ps.reserved_page_count)-SUM(ps.used_page_count))*8.0/1024,2) AS free_mb,
    stat.last_user_update,
    stat.last_user_seek
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id=s.schema_id
JOIN sys.dm_db_partition_stats ps ON t.object_id=ps.object_id
LEFT JOIN sys.dm_db_index_usage_stats stat
    ON t.object_id=stat.object_id AND stat.index_id<=1
    AND stat.database_id=DB_ID()
WHERE s.name NOT IN ('sys','INFORMATION_SCHEMA')
GROUP BY s.name, t.name, stat.last_user_update, stat.last_user_seek;
GO
PRINT '✓ governance.v_table_sizes created.';
GO

-- ── Scenario: Stress-Test Procedure (What-If Analysis) ────────
IF OBJECT_ID('mart.usp_scenario_stress_test','P') IS NOT NULL DROP PROCEDURE mart.usp_scenario_stress_test;
GO
CREATE PROCEDURE mart.usp_scenario_stress_test
    @ticker         VARCHAR(12),
    @fiscal_year    SMALLINT,
    @revenue_shock  FLOAT = 0,      -- e.g. -0.10 = -10% revenue shock
    @margin_shock   FLOAT = 0,      -- e.g. -0.05 = -500bps margin compression
    @rate_shock     FLOAT = 0        -- e.g. 0.02 = +200bps interest rate shock
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.ticker_symbol, c.company_name,
        r.fiscal_year,
        '--- BASE CASE ---'                               AS scenario,
        ROUND(r.total_revenue/1e6,2)                     AS revenue_m,
        r.ebitda_margin_pct,
        ROUND(r.ebitda/1e6,2)                            AS ebitda_m,
        ROUND(r.net_income/1e6,2)                        AS net_income_m,
        r.interest_coverage,
        r.net_debt_to_ebitda,
        r.current_ratio
    FROM mart.v_financial_ratios r
    JOIN dw.dim_company c ON r.company_key=c.company_key AND c.is_current=1
    WHERE c.ticker_symbol=@ticker AND r.fiscal_year=@fiscal_year

    UNION ALL

    SELECT
        c.ticker_symbol, c.company_name, r.fiscal_year,
        '--- STRESSED CASE (Rev:'+CAST(@revenue_shock*100 AS VARCHAR)+'% / Margin:'+CAST(@margin_shock*100 AS VARCHAR)+'bps / Rate:+'+CAST(@rate_shock*100 AS VARCHAR)+'%) ---',
        ROUND(r.total_revenue*(1+@revenue_shock)/1e6,2),
        ROUND((r.ebitda_margin_pct/100+@margin_shock)*100,2),
        ROUND(r.total_revenue*(1+@revenue_shock)*(r.ebitda_margin_pct/100+@margin_shock)/1e6,2),
        ROUND((r.total_revenue*(1+@revenue_shock)*(r.ebitda_margin_pct/100+@margin_shock)
               - ABS(r.interest_expense)*(1+@rate_shock))/1e6,2),
        ROUND(r.total_revenue*(1+@revenue_shock)*(r.ebitda_margin_pct/100+@margin_shock)
              / NULLIF(ABS(r.interest_expense)*(1+@rate_shock),0),2),
        ROUND(r.net_debt / NULLIF(
              r.total_revenue*(1+@revenue_shock)*(r.ebitda_margin_pct/100+@margin_shock),0),2),
        r.current_ratio
    FROM mart.v_financial_ratios r
    JOIN dw.dim_company c ON r.company_key=c.company_key AND c.is_current=1
    WHERE c.ticker_symbol=@ticker AND r.fiscal_year=@fiscal_year;
END;
GO
PRINT '✓ mart.usp_scenario_stress_test created.';
GO

-- ============================================================
-- MODULE 9 – COMPLETE SAMPLE QUERY LIBRARY
-- Interview-ready queries with explanations
-- ============================================================

-- ── Query Library View (metadata, not executable SQL) ─────────
IF OBJECT_ID('governance.v_query_library','V') IS NOT NULL DROP VIEW governance.v_query_library;
GO
CREATE VIEW governance.v_query_library AS
SELECT *
FROM (VALUES
('Q01','Window Functions','3-Year Revenue CAGR using LAG(,3)',
 'SELECT ticker_symbol, fiscal_year, total_revenue,
  ROUND((POWER(CAST(total_revenue AS FLOAT)/NULLIF(LAG(total_revenue,3) OVER (PARTITION BY company_key ORDER BY fiscal_year),0),1.0/3)-1)*100,2) AS rev_3yr_cagr
 FROM mart.v_financial_ratios ORDER BY ticker_symbol, fiscal_year'),

('Q02','Window Functions','Running total Net Income with SUM OVER',
 'SELECT ticker_symbol, fiscal_year, net_income,
  SUM(net_income) OVER (PARTITION BY company_key ORDER BY fiscal_year ROWS UNBOUNDED PRECEDING) AS cumulative_ni
 FROM mart.v_financial_ratios'),

('Q03','Window Functions','Sector quartile ranking by EBITDA margin',
 'SELECT ticker_symbol, gics_sector_name, fiscal_year, ebitda_margin_pct,
  NTILE(4) OVER (PARTITION BY gics_sector_name, fiscal_year ORDER BY ebitda_margin_pct DESC) AS quartile
 FROM mart.v_financial_ratios'),

('Q04','Self-Join','Year-over-Year comparison in one row',
 'SELECT a.ticker_symbol, a.fiscal_year AS curr_yr, b.fiscal_year AS prior_yr,
  a.total_revenue AS curr_rev, b.total_revenue AS prior_rev,
  ROUND((CAST(a.total_revenue AS FLOAT)-b.total_revenue)/NULLIF(b.total_revenue,0)*100,1) AS yoy_pct
 FROM dw.fact_income_statement a JOIN dw.fact_income_statement b
 ON a.company_key=b.company_key AND b.fiscal_year=a.fiscal_year-1 AND a.period_type=''ANNUAL'' AND b.period_type=''ANNUAL'''),

('Q05','CTE Chain','DuPont 3-Factor ROE decomposition',
 'WITH roe_components AS (SELECT company_key, fiscal_year,
  net_income/NULLIF(total_revenue,0) AS net_margin,
  total_revenue/NULLIF(total_assets,0) AS asset_turnover,
  total_assets/NULLIF(total_equity,0) AS equity_multiplier FROM mart.v_financial_ratios)
 SELECT *, ROUND(net_margin*asset_turnover*equity_multiplier*100,2) AS roe_dupont FROM roe_components'),

('Q06','Cross Join','Scenario sensitivity matrix',
 'SELECT c.ticker_symbol, s.scenario_name, r.ebitda*(1+s.shock) AS stressed_ebitda
 FROM mart.v_financial_ratios r JOIN dw.dim_company c ON r.company_key=c.company_key AND c.is_current=1
 CROSS JOIN (VALUES (''Base'',0.0),(''Bear'',-0.15),(''Bull'',0.10)) s(scenario_name,shock)
 WHERE r.fiscal_year=2023'),

('Q07','Recursive CTE','Loan amortisation schedule',
 'EXEC credit.usp_amortisation_schedule @principal=5000000, @annual_rate=7.0, @term_months=60, @start_date=''2024-01-01'''),

('Q08','Dynamic SQL','Monthly revenue pivot',
 'EXEC fpa.usp_pivot_monthly_revenue @fiscal_year=2023'),

('Q09','Credit Risk','IFRS 9 Stage Classification',
 'SELECT borrower_name, facility_id, days_past_due, effective_pd_pct, ifrs9_stage, risk_band FROM credit.v_risk_dashboard ORDER BY effective_pd_pct DESC'),

('Q10','Fraud Detection','Duplicate payment analysis',
 'SELECT vendor_name, transaction_id, amount, days_since_same, same_amount_30d, duplicate_risk_level, potential_duplicate_loss FROM forensic.v_duplicate_payments ORDER BY potential_duplicate_loss DESC'),

('Q11','ESG Analytics','Carbon intensity ranking',
 'SELECT ticker_symbol, report_year, carbon_intensity, renewable_energy_pct, composite_esg_score, esg_letter_rating, sector_esg_rank FROM esg.v_esg_scores ORDER BY composite_esg_score DESC'),

('Q12','FP&A','Budget vs Actual with YTD cumulative',
 'SELECT fiscal_year, fiscal_month, actual_revenue, budget_revenue, revenue_bva, bva_pct, ytd_bva, budget_flag FROM fpa.v_forecast_accuracy ORDER BY fiscal_year, fiscal_month')
) q(query_id, category, description, sample_sql);
GO
PRINT '✓ governance.v_query_library created (12 interview-ready queries catalogued).';
GO

-- ============================================================
-- MODULE 10 – STORED PROCEDURE: MONTHLY CLOSE PACK
-- Orchestrates full month-end analytics reporting
-- ============================================================
IF OBJECT_ID('governance.usp_monthly_close_pack','P') IS NOT NULL DROP PROCEDURE governance.usp_monthly_close_pack;
GO
CREATE PROCEDURE governance.usp_monthly_close_pack
    @company_ticker VARCHAR(12),
    @fiscal_year    SMALLINT,
    @fiscal_month   SMALLINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_key INT;
    SELECT @company_key=company_key FROM dw.dim_company
    WHERE ticker_symbol=@company_ticker AND is_current=1;

    IF @company_key IS NULL
    BEGIN RAISERROR('Company %s not found.',16,1,@company_ticker); RETURN; END

    PRINT '=== MONTHLY CLOSE PACK | ' + @company_ticker
          + ' | FY' + CAST(@fiscal_year AS VARCHAR) + ' M' + CAST(@fiscal_month AS VARCHAR) + ' ===';

    -- 1. P&L Summary
    PRINT '-- SECTION 1: P&L Summary';
    SELECT ticker_symbol, fiscal_year, fiscal_month,
           ROUND(actual_revenue/1e6,2) AS revenue_m,
           ROUND(budget_revenue/1e6,2) AS budget_revenue_m,
           ROUND(revenue_bva/1e6,2) AS revenue_bva_m,
           bva_pct, ROUND(ytd_revenue/1e6,2) AS ytd_revenue_m,
           ytd_bva AS ytd_bva_usd, budget_flag
    FROM fpa.v_forecast_accuracy v
    JOIN dw.dim_company c ON v.company_key=c.company_key
    WHERE c.ticker_symbol=@company_ticker
      AND v.fiscal_year=@fiscal_year AND v.fiscal_month=@fiscal_month;

    -- 2. Balance Sheet Snapshot (most recent annual)
    PRINT '-- SECTION 2: Balance Sheet Snapshot';
    SELECT c.ticker_symbol, bs.fiscal_year,
           ROUND(bs.cash_equivalents/1e6,2) AS cash_m,
           ROUND(bs.net_debt/1e6,2) AS net_debt_m,
           ROUND(bs.working_capital/1e6,2) AS working_capital_m,
           ROUND(bs.total_equity/1e6,2) AS equity_m,
           ROUND(bs.long_term_debt/1e6,2) AS lt_debt_m,
           ROUND(bs.total_assets/1e6,2) AS total_assets_m
    FROM dw.fact_balance_sheet bs
    JOIN dw.dim_company c ON bs.company_key=c.company_key
    WHERE c.ticker_symbol=@company_ticker AND bs.period_type='ANNUAL'
      AND bs.fiscal_year=(
          SELECT MAX(fiscal_year) FROM dw.fact_balance_sheet
          WHERE company_key=@company_key AND period_type='ANNUAL');

    -- 3. Key Financial Ratios
    PRINT '-- SECTION 3: Key Ratios (most recent year)';
    SELECT ticker_symbol, fiscal_year,
           gross_margin_pct, ebitda_margin_pct, net_margin_pct,
           roe_pct, roa_pct, current_ratio, debt_to_equity,
           interest_coverage, net_debt_to_ebitda, fcf_margin_pct,
           revenue_yoy_pct, sector_roe_rank
    FROM mart.v_financial_ratios
    WHERE ticker_symbol=@company_ticker
      AND fiscal_year=(SELECT MAX(fiscal_year) FROM mart.v_financial_ratios WHERE ticker_symbol=@company_ticker);

    -- 4. Credit Risk Summary
    PRINT '-- SECTION 4: Credit Risk Exposure';
    SELECT COUNT(*) AS facility_count,
           ROUND(SUM(rd.outstanding_m),2) AS total_outstanding_m,
           ROUND(SUM(rd.expected_loss_usd)/1e6,4) AS total_el_m,
           ROUND(AVG(rd.effective_pd_pct),3) AS avg_pd_pct,
           SUM(CASE WHEN rd.ifrs9_stage='STAGE 3' THEN 1 ELSE 0 END) AS stage3_count
    FROM credit.v_risk_dashboard rd
    JOIN credit.borrowers b ON b.borrower_name LIKE '%'+@company_ticker+'%'
    JOIN credit.loan_facilities lf ON lf.borrower_key=b.borrower_key
    WHERE 1=1;

    -- 5. Data Quality Checks
    PRINT '-- SECTION 5: Data Quality';
    SELECT * FROM dw.fn_validate_warehouse();

    PRINT '=== CLOSE PACK COMPLETE ===';
END;
GO
PRINT '✓ governance.usp_monthly_close_pack created.';
GO

-- ============================================================
-- FINAL COMPREHENSIVE VERIFICATION – ALL MODULES
-- ============================================================
PRINT '';
PRINT '==============================================';
PRINT '  PART 3 FINAL VERIFICATION';
PRINT '==============================================';
GO

PRINT '-- VERIFY 1: Forensic – Duplicate Payments';
SELECT vendor_name, transaction_id, amount,
       ISNULL(days_since_same,0) AS days_since_same,
       same_amount_30d, duplicate_risk_level,
       ROUND(potential_duplicate_loss,2) AS potential_loss
FROM forensic.v_duplicate_payments
ORDER BY potential_duplicate_loss DESC;
GO

PRINT '-- VERIFY 2: Forensic – Expense Anomalies (Fraud Scored)';
SELECT transaction_id, vendor_name, amount, transaction_date,
       created_by, approved_by,
       is_round_dollar, is_self_approved, missing_approval,
       below_5k_threshold, is_weekend_posting,
       fraud_score, audit_priority
FROM forensic.v_expense_anomalies
ORDER BY fraud_score DESC;
GO

PRINT '-- VERIFY 3: Vendor Risk Scorecard';
SELECT vendor_id, vendor_name,
       duplicate_flag_count, potential_duplicate_loss,
       avg_expense_fraud_score, flagged_txn_count,
       overall_vendor_risk_score, risk_tier
FROM forensic.v_vendor_risk_scorecard
ORDER BY overall_vendor_risk_score DESC;
GO

PRINT '-- VERIFY 4: Advanced Ranking Engine (Window Functions showcase)';
SELECT ticker_symbol, company_name, gics_sector_name, fiscal_year,
       rank_ebitda_margin, dense_rank_roe, revenue_row_num,
       ebitda_quintile, roe_quartile,
       net_margin_percentile, revenue_size_percentile,
       sector_revenue_share_pct,
       cumulative_net_income, rolling_3yr_ebitda_margin
FROM mart.v_ranking_engine
ORDER BY ticker_symbol, fiscal_year;
GO

PRINT '-- VERIFY 5: Dynamic SQL Pivot – FY2023 Monthly Revenue';
EXEC fpa.usp_pivot_monthly_revenue @fiscal_year=2023;
GO

PRINT '-- VERIFY 6: Scenario Stress Test – Apple 2023 (-10% revenue, -5% margin)';
EXEC mart.usp_scenario_stress_test
    @ticker       = 'AAPL',
    @fiscal_year  = 2023,
    @revenue_shock = -0.10,
    @margin_shock  = -0.05,
    @rate_shock    = 0.02;
GO

PRINT '-- VERIFY 7: All Facility Amortisation Schedules (Recursive CTE + Cursor)';
EXEC credit.usp_all_facility_schedules;
GO

PRINT '-- VERIFY 8: Query Library Catalogue';
SELECT query_id, category, description FROM governance.v_query_library ORDER BY query_id;
GO

PRINT '-- VERIFY 9: Index Usage Monitor';
SELECT schema_name, table_name, index_name, index_type,
       total_reads, user_updates, ROUND(size_mb,2) AS size_mb, usage_status
FROM governance.v_index_usage
WHERE schema_name NOT IN ('sys','INFORMATION_SCHEMA')
ORDER BY total_reads DESC, size_mb DESC;
GO

PRINT '-- VERIFY 10: Table Sizes';
SELECT schema_name, table_name, row_count, reserved_mb, used_mb
FROM governance.v_table_sizes
ORDER BY reserved_mb DESC;
GO

-- ============================================================
-- GRAND TOTAL OBJECT COUNT
-- ============================================================
PRINT '';
PRINT '==============================================';
PRINT '  COMPLETE PORTFOLIO – FINAL OBJECT COUNT';
PRINT '==============================================';
SELECT
    o.type_desc      AS object_type,
    COUNT(*)         AS object_count
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id=s.schema_id
WHERE o.type IN ('U','V','P','IF','TF','TR')
  AND s.name NOT IN ('sys','INFORMATION_SCHEMA')
GROUP BY o.type_desc
ORDER BY object_count DESC;
GO

SELECT
    s.name           AS schema_name,
    COUNT(CASE WHEN o.type='U' THEN 1 END)  AS tables,
    COUNT(CASE WHEN o.type='V' THEN 1 END)  AS views,
    COUNT(CASE WHEN o.type='P' THEN 1 END)  AS procedures,
    COUNT(CASE WHEN o.type IN('IF','TF') THEN 1 END) AS functions,
    COUNT(CASE WHEN o.type='TR' THEN 1 END) AS triggers
FROM sys.schemas s
LEFT JOIN sys.objects o ON s.schema_id=o.schema_id
    AND o.type IN ('U','V','P','IF','TF','TR')
WHERE s.name NOT IN ('sys','INFORMATION_SCHEMA','guest','db_owner',
                     'db_accessadmin','db_securityadmin','db_ddladmin',
                     'db_backupoperator','db_datareader','db_datawriter',
                     'db_denydatareader','db_denydatawriter')
  AND s.name IN ('dw','mart','credit','forensic','fpa','treasury',
                 'market','esg','bi','governance','etl','audit')
GROUP BY s.name
ORDER BY s.name;
GO

PRINT '';
PRINT '==============================================';
PRINT '  GITHUB REPOSITORY STRUCTURE';
PRINT '==============================================';
PRINT 'sql-finance-portfolio/';
PRINT '├── README.md';
PRINT '├── docs/';
PRINT '│   ├── ERD_DataWarehouse.png';
PRINT '│   ├── ERD_CreditRisk.png';
PRINT '│   ├── DataDictionary.xlsx';
PRINT '│   └── Architecture_Overview.pdf';
PRINT '├── schemas/';
PRINT '│   ├── 01_COMPLETE_PORTFOLIO_SQLSERVER.sql   ← Core: DW + Fact + Dim + Ratios + Credit';
PRINT '│   ├── 02_PORTFOLIO_ANALYTICS_PART2.sql      ← FP&A + Treasury + Market + ESG + BI';
PRINT '│   └── 03_PORTFOLIO_PART3_FINAL.sql          ← Fraud + Advanced SQL + Dynamic SQL + Stress';
PRINT '├── queries/';
PRINT '│   ├── interview_queries.sql';
PRINT '│   ├── window_functions_showcase.sql';
PRINT '│   └── recursive_cte_examples.sql';
PRINT '└── tests/';
PRINT '    ├── test_balance_sheet_integrity.sql';
PRINT '    ├── test_ratio_calculations.sql';
PRINT '    └── test_dq_rules.sql';
PRINT '';
PRINT '==============================================';
PRINT '  PORTFOLIO COMPLETE – ALL 12 PROJECTS DONE';
PRINT '  Run order: Part1 → Part2 → Part3';
PRINT '==============================================';
GO

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

-- ============================================================
-- SQL PORTFOLIO – PART 6: CAPSTONE COMPLETION
-- Enterprise Integration + Data Governance + Security +
-- Complete GitHub README + Final Object Registry
-- Engine  : SQL Server 2017+ Express / SSMS
-- Run     : After Parts 1-5 (final file in the series)
-- ============================================================

USE FinancePortfolio;
GO

-- ============================================================
-- MODULE 1 – DATA GOVERNANCE FRAMEWORK
-- Data lineage, column metadata, business glossary
-- ============================================================

-- ── Data Dictionary Table ─────────────────────────────────────
IF OBJECT_ID('governance.data_dictionary','U') IS NULL
BEGIN
    CREATE TABLE governance.data_dictionary (
        dict_key            INT           IDENTITY(1,1) PRIMARY KEY,
        schema_name         VARCHAR(50)   NOT NULL,
        table_name          VARCHAR(100)  NOT NULL,
        column_name         VARCHAR(100)  NOT NULL,
        data_type           VARCHAR(50),
        is_nullable         BIT,
        is_pii              BIT           DEFAULT 0,
        is_sensitive        BIT           DEFAULT 0,
        business_name       VARCHAR(150),
        business_definition NVARCHAR(500),
        calculation_logic   NVARCHAR(500),
        data_owner          VARCHAR(80),
        source_system       VARCHAR(50),
        last_updated        DATE,
        CONSTRAINT UQ_dict UNIQUE (schema_name, table_name, column_name)
    );

    -- Populate from system catalog
    INSERT INTO governance.data_dictionary
        (schema_name, table_name, column_name, data_type, is_nullable, business_name)
    SELECT
        s.name,
        t.name,
        c.name,
        tp.name + CASE
            WHEN tp.name IN ('varchar','nvarchar','char','nchar')
            THEN '(' + CASE WHEN c.max_length=-1 THEN 'MAX'
                            WHEN tp.name IN ('nvarchar','nchar')
                            THEN CAST(c.max_length/2 AS VARCHAR)
                            ELSE CAST(c.max_length AS VARCHAR) END + ')'
            WHEN tp.name IN ('decimal','numeric')
            THEN '(' + CAST(c.precision AS VARCHAR) + ',' + CAST(c.scale AS VARCHAR) + ')'
            ELSE ''
        END,
        CAST(c.is_nullable AS BIT),
        REPLACE(REPLACE(c.name,'_',' '),'pct','%')
    FROM sys.columns c
    JOIN sys.tables  t  ON c.object_id = t.object_id
    JOIN sys.schemas s  ON t.schema_id = s.schema_id
    JOIN sys.types   tp ON c.user_type_id = tp.user_type_id
    WHERE s.name IN ('dw','mart','credit','forensic','fpa',
                     'treasury','market','esg','bi','governance','etl')
      AND t.name NOT LIKE 'sys%';

    PRINT '✓ governance.data_dictionary populated from system catalog.';
END
GO

-- Update key business definitions
UPDATE governance.data_dictionary
SET business_definition = 'Earnings Before Interest, Tax, Depreciation and Amortisation. Proxy for operating cash generation.',
    calculation_logic   = 'operating_income + depreciation_amortization'
WHERE column_name IN ('ebitda','ebitda_usd_m');

UPDATE governance.data_dictionary
SET business_definition = 'Probability that a borrower will default within 12 months. Sourced from internal credit model.',
    calculation_logic   = 'Internal rating mapped to pd_master_scale.pd_midpoint_pct'
WHERE column_name = 'pd_pct';

UPDATE governance.data_dictionary
SET business_definition = 'Loss Given Default – estimated % of EAD that will be lost if borrower defaults. Basel III floor 45% unsecured.',
    calculation_logic   = 'ISNULL(lf.lgd_pct, CASE WHEN fully secured THEN 10.0 ELSE 45.0 END)'
WHERE column_name = 'lgd_pct';

UPDATE governance.data_dictionary
SET business_definition = 'Expected Loss = PD × LGD × EAD. The Basel III required provision estimate.',
    calculation_logic   = 'pd_pct/100 * lgd_pct/100 * (outstanding_balance + 0.75*undrawn_amount)'
WHERE column_name = 'expected_loss_usd';

UPDATE governance.data_dictionary
SET business_definition = 'Free Cash Flow = Cash from Operations + Capital Expenditures. True cash available after maintenance of fixed assets.',
    calculation_logic   = 'cash_from_operations + capital_expenditures (CapEx is negative)'
WHERE column_name IN ('free_cash_flow','fcf_usd_m');

UPDATE governance.data_dictionary
SET is_pii = 1
WHERE column_name IN ('vendor_name','borrower_name','contact_email',
                      'manager_name','created_by','approved_by','changed_by');

PRINT '✓ governance.data_dictionary definitions updated.';
GO

-- ── Business Glossary ─────────────────────────────────────────
IF OBJECT_ID('governance.business_glossary','U') IS NULL
BEGIN
    CREATE TABLE governance.business_glossary (
        term_id         INT           IDENTITY(1,1) PRIMARY KEY,
        term            VARCHAR(80)   NOT NULL UNIQUE,
        abbreviation    VARCHAR(20),
        category        VARCHAR(40),
        definition      NVARCHAR(MAX) NOT NULL,
        formula         NVARCHAR(500),
        related_terms   NVARCHAR(200),
        domain          VARCHAR(40),
        approved_by     VARCHAR(80),
        created_at      DATETIME2     DEFAULT GETDATE()
    );

    INSERT INTO governance.business_glossary
        (term, abbreviation, category, definition, formula, related_terms, domain)
    VALUES
    ('Earnings Before Interest Tax Depreciation Amortisation','EBITDA','Profitability',
     'A measure of core operating profitability before non-cash charges and financing structure. Used for EV multiples and leverage ratios.',
     'Operating Income + Depreciation + Amortisation','EBIT, Net Income, Operating Income','Financial Analysis'),

    ('Return on Equity','ROE','Returns',
     'Measures how much profit a company generates with the money shareholders have invested. Key measure of management effectiveness.',
     'Net Income / Average Shareholders Equity × 100','ROA, ROIC, DuPont','Financial Analysis'),

    ('Return on Invested Capital','ROIC','Returns',
     'Measures how efficiently a company uses all capital (debt + equity) to generate returns. Compared against WACC to assess value creation.',
     'NOPAT / (Total Equity + Net Debt) × 100','WACC, Economic Profit, EVA','Financial Analysis'),

    ('Probability of Default','PD','Credit Risk',
     'The likelihood that a borrower will be unable to meet debt obligations within a defined horizon (typically 12 months). Through-the-cycle estimate.',
     'Derived from internal rating model mapped to historical default rates','LGD, EAD, Expected Loss','Credit Risk'),

    ('Loss Given Default','LGD','Credit Risk',
     'The fraction of exposure that will be lost if a default occurs, after accounting for collateral recovery. Basel III floor: 45% unsecured senior.',
     '1 - Recovery Rate','PD, EAD, Collateral Coverage Ratio','Credit Risk'),

    ('Exposure at Default','EAD','Credit Risk',
     'The total value at risk when a counterparty defaults. For revolvers, includes an estimate of undrawn amounts that may be drawn before default.',
     'Drawn Balance + CCF × Undrawn Balance (CCF = 75% revolvers, 100% term)','PD, LGD, Credit Conversion Factor','Credit Risk'),

    ('Expected Loss','EL','Credit Risk',
     'The average loss a portfolio is expected to incur over a defined horizon. Used for loan loss provisioning under IFRS 9 and Basel III.',
     'PD × LGD × EAD','Unexpected Loss, Economic Capital, IFRS 9 Staging','Credit Risk'),

    ('Cash Conversion Cycle','CCC','Liquidity',
     'The number of days a company takes to convert its investments in inventory and other resources into cash flows from sales.',
     'DSO + DIO - DPO','DSO, DPO, DIO, Working Capital','Treasury'),

    ('Days Sales Outstanding','DSO','Efficiency',
     'Average number of days a company takes to collect payment after a sale. Lower = faster collection.',
     'Accounts Receivable / Revenue × 365','CCC, Receivables Turnover','Treasury'),

    ('Free Cash Flow','FCF','Cash Flow',
     'Cash generated by a business after accounting for capital expenditures needed to maintain or expand operations.',
     'Cash from Operations + Capital Expenditures (CapEx is negative)','Operating Cash Flow, CapEx, FCF Yield','Financial Analysis'),

    ('Net Debt','ND','Balance Sheet',
     'Total debt obligations minus cash and liquid investments. Negative net debt means the company holds more cash than debt.',
     '(Short-term Debt + Long-term Debt) - (Cash + Short-term Investments)','Gross Debt, Leverage, Net Debt/EBITDA','Financial Analysis'),

    ('Environmental Social Governance','ESG','Sustainability',
     'Non-financial factors used to measure sustainability and societal impact of investments. Used by institutional investors for responsible investing.',
     'Composite score: Environmental (40%) + Social (30%) + Governance (30%)','Carbon Intensity, Board Diversity, CDP Score','ESG Analytics'),

    ('Slowly Changing Dimension','SCD','Data Warehousing',
     'A dimension whose attributes change slowly over time rather than on a regular schedule. Type 2 adds new rows to track history.',
     'SCD Type 2: expire old row, insert new version with scd_start_date and is_current=1','Star Schema, Fact Table, ETL','Data Engineering'),

    ('Weighted Average Cost of Capital','WACC','Valuation',
     'The average rate a company is expected to pay to finance its assets, weighted by the proportion of each financing source.',
     'WACC = (E/V × Re) + (D/V × Rd × (1-T))','DCF, ROIC, Economic Profit','Valuation'),

    ('Time-Weighted Return','TWR','Portfolio Analytics',
     'A measure of portfolio performance that eliminates the impact of external cash flows. Industry standard for manager performance evaluation.',
     'TWR = ∏(1 + r_t) - 1 where r_t are sub-period returns','MWR (IRR), Sharpe Ratio, Alpha','Portfolio Management');

    PRINT '✓ governance.business_glossary created (15 terms).';
END
GO

-- ── Data Lineage Table ────────────────────────────────────────
IF OBJECT_ID('governance.data_lineage','U') IS NULL
BEGIN
    CREATE TABLE governance.data_lineage (
        lineage_id          INT           IDENTITY(1,1) PRIMARY KEY,
        target_schema       VARCHAR(50)   NOT NULL,
        target_table        VARCHAR(100)  NOT NULL,
        target_column       VARCHAR(100),
        source_system       VARCHAR(50)   NOT NULL,
        source_object       VARCHAR(200),
        transformation_desc NVARCHAR(500),
        load_frequency      VARCHAR(30),
        data_owner          VARCHAR(80),
        last_verified       DATE,
        is_active           BIT           DEFAULT 1,
        created_at          DATETIME2     DEFAULT GETDATE()
    );

    INSERT INTO governance.data_lineage
        (target_schema, target_table, target_column, source_system,
         source_object, transformation_desc, load_frequency, data_owner)
    VALUES
    ('dw','fact_income_statement','total_revenue','SEC_EDGAR',
     'EDGAR XBRL us-gaap:Revenues','Direct mapping from XBRL tag. USD millions.','QUARTERLY','Finance Data Team'),
    ('dw','fact_income_statement','gross_profit','SEC_EDGAR',
     'Computed Column','total_revenue - cost_of_revenue (SQL Server AS expression)','COMPUTED','Finance Data Team'),
    ('dw','fact_balance_sheet','net_debt','SEC_EDGAR',
     'Computed Column','short_term_debt + long_term_debt - cash - short_term_investments','COMPUTED','Finance Data Team'),
    ('dw','fact_cash_flow','free_cash_flow','SEC_EDGAR',
     'Computed Column','cash_from_operations + capital_expenditures','COMPUTED','Finance Data Team'),
    ('dw','fact_stock_price','adj_close_price','YAHOO_FINANCE',
     'Yahoo Finance Historical Data API','Split and dividend adjusted closing price','DAILY','Market Data Team'),
    ('dw','fact_economic_indicator','indicator_value','FRED',
     'St. Louis Fed FRED API','Direct value from series code (e.g. GDP_GROWTH = A191RL1Q225SBEA)','QUARTERLY','Macro Research'),
    ('mart','v_financial_ratios','roe_pct','COMPUTED',
     'fact_income_statement + fact_balance_sheet','net_income / AVG(total_equity) × 100. Window avg over 2 periods.','ON_QUERY','Analytics Team'),
    ('credit','loan_facilities','expected_loss_usd','COMPUTED',
     'Computed Column','pd_pct/100 × lgd_pct/100 × EAD. Basel III formula.','REAL_TIME','Credit Risk Team'),
    ('esg','esg_metrics','scope1_emissions_tco2e','COMPANY_REPORT',
     'Annual Sustainability Report','Direct extraction from company ESG disclosure. tCO2e.','ANNUAL','ESG Team'),
    ('forensic','transactions','fraud_score','COMPUTED',
     'v_expense_anomalies view','Composite of 8 risk indicators, weighted 0-100 scale.','ON_QUERY','Internal Audit');

    PRINT '✓ governance.data_lineage created (10 lineage records).';
END
GO

-- ── DQ Rules Registry ─────────────────────────────────────────
IF OBJECT_ID('governance.dq_rules','U') IS NULL
BEGIN
    CREATE TABLE governance.dq_rules (
        rule_id         INT           IDENTITY(1,1) PRIMARY KEY,
        rule_name       VARCHAR(150)  NOT NULL UNIQUE,
        rule_category   VARCHAR(40),
        schema_name     VARCHAR(50),
        table_name      VARCHAR(100),
        rule_sql        NVARCHAR(MAX) NOT NULL,
        severity        VARCHAR(10)   NOT NULL,
        threshold_pct   DECIMAL(6,2)  DEFAULT 0,
        owner           VARCHAR(80),
        is_active       BIT           DEFAULT 1,
        last_run        DATETIME2,
        last_result     VARCHAR(10),
        last_violations INT           DEFAULT 0,
        created_at      DATETIME2     DEFAULT GETDATE()
    );

    INSERT INTO governance.dq_rules
        (rule_name, rule_category, schema_name, table_name, rule_sql, severity, owner)
    VALUES
    ('IS_Revenue_Not_Null','COMPLETENESS','dw','fact_income_statement',
     'SELECT COUNT(*) FROM dw.fact_income_statement WHERE total_revenue IS NULL','CRITICAL','Finance Data Team'),
    ('IS_No_Negative_Revenue','ACCURACY','dw','fact_income_statement',
     'SELECT COUNT(*) FROM dw.fact_income_statement WHERE total_revenue < 0','HIGH','Finance Data Team'),
    ('BS_Balance_Sheet_Equation','CONSISTENCY','dw','fact_balance_sheet',
     'SELECT COUNT(*) FROM dw.fact_balance_sheet WHERE ABS(ISNULL(total_assets,0)-ISNULL(total_liabilities,0)-ISNULL(total_equity,0)) > 1.0','CRITICAL','Finance Data Team'),
    ('SP_No_Zero_Price','ACCURACY','dw','fact_stock_price',
     'SELECT COUNT(*) FROM dw.fact_stock_price WHERE close_price <= 0','CRITICAL','Market Data Team'),
    ('SP_No_Future_Dates','TIMELINESS','dw','fact_stock_price',
     'SELECT COUNT(*) FROM dw.fact_stock_price sp JOIN dw.dim_date d ON sp.date_key=d.date_key WHERE d.full_date > GETDATE()','HIGH','Market Data Team'),
    ('COMP_Unique_Active_Ticker','UNIQUENESS','dw','dim_company',
     'SELECT COUNT(*) FROM (SELECT ticker_symbol FROM dw.dim_company WHERE is_current=1 GROUP BY ticker_symbol HAVING COUNT(*)>1) t','CRITICAL','Finance Data Team'),
    ('CR_PD_In_Range','ACCURACY','credit','loan_facilities',
     'SELECT COUNT(*) FROM credit.loan_facilities WHERE pd_pct NOT BETWEEN 0 AND 100','HIGH','Credit Risk Team'),
    ('CR_LGD_In_Range','ACCURACY','credit','loan_facilities',
     'SELECT COUNT(*) FROM credit.loan_facilities WHERE lgd_pct NOT BETWEEN 0 AND 100','HIGH','Credit Risk Team'),
    ('ESG_Renewable_Pct_Range','ACCURACY','esg','esg_metrics',
     'SELECT COUNT(*) FROM esg.esg_metrics WHERE renewable_energy_pct NOT BETWEEN 0 AND 100','MEDIUM','ESG Team'),
    ('FPA_Actuals_No_Future','TIMELINESS','fpa','actuals',
     'SELECT COUNT(*) FROM fpa.actuals WHERE fiscal_year > YEAR(GETDATE())','MEDIUM','FP&A Team');

    PRINT '✓ governance.dq_rules created (10 DQ rules).';
END
GO

-- ── DQ Execution Procedure ────────────────────────────────────
IF OBJECT_ID('governance.usp_run_dq_checks','P') IS NOT NULL
    DROP PROCEDURE governance.usp_run_dq_checks;
GO
CREATE PROCEDURE governance.usp_run_dq_checks
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql       NVARCHAR(MAX);
    DECLARE @violations INT;
    DECLARE @rule_id   INT;
    DECLARE @rule_name VARCHAR(150);
    DECLARE @severity  VARCHAR(10);
    DECLARE @pass_count INT = 0;
    DECLARE @fail_count INT = 0;

    CREATE TABLE #dq_results (
        rule_name   VARCHAR(150),
        severity    VARCHAR(10),
        violations  INT,
        status      VARCHAR(10),
        checked_at  DATETIME2 DEFAULT GETDATE()
    );

    DECLARE cur CURSOR FOR
        SELECT rule_id, rule_name, rule_sql, severity
        FROM governance.dq_rules WHERE is_active=1
        ORDER BY severity, rule_name;

    OPEN cur;
    FETCH NEXT FROM cur INTO @rule_id, @rule_name, @sql, @severity;

    WHILE @@FETCH_STATUS=0
    BEGIN
        BEGIN TRY
            EXEC sp_executesql @sql, N'@cnt INT OUTPUT', @cnt=@violations OUTPUT;
        END TRY
        BEGIN CATCH
            SET @violations = -1; -- Execution error
        END CATCH;

        INSERT INTO #dq_results (rule_name, severity, violations, status)
        VALUES (@rule_name, @severity,
                @violations,
                CASE WHEN @violations=0 THEN 'PASS'
                     WHEN @violations>0 THEN 'FAIL'
                     ELSE 'ERROR' END);

        -- Update registry
        UPDATE governance.dq_rules
        SET last_run = GETDATE(),
            last_result = CASE WHEN @violations=0 THEN 'PASS' WHEN @violations>0 THEN 'FAIL' ELSE 'ERROR' END,
            last_violations = @violations
        WHERE rule_id = @rule_id;

        IF @violations = 0 SET @pass_count = @pass_count + 1;
        ELSE SET @fail_count = @fail_count + 1;

        FETCH NEXT FROM cur INTO @rule_id, @rule_name, @sql, @severity;
    END

    CLOSE cur; DEALLOCATE cur;

    -- Return results
    SELECT rule_name, severity, violations, status, checked_at
    FROM #dq_results
    ORDER BY CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END,
             status DESC;

    PRINT 'DQ Summary: ' + CAST(@pass_count AS VARCHAR) + ' PASS, '
                         + CAST(@fail_count AS VARCHAR) + ' FAIL';
    DROP TABLE #dq_results;
END;
GO
PRINT '✓ governance.usp_run_dq_checks created.';
GO

-- ============================================================
-- MODULE 2 – ETL PIPELINE EXECUTION LOG + PROCEDURE
-- ============================================================
IF OBJECT_ID('etl.pipeline_run_log','U') IS NULL
BEGIN
    CREATE TABLE etl.pipeline_run_log (
        run_id              BIGINT        IDENTITY(1,1) PRIMARY KEY,
        job_id              INT           REFERENCES etl.pipeline_jobs(job_id),
        run_start           DATETIME2     NOT NULL DEFAULT GETDATE(),
        run_end             DATETIME2,
        duration_seconds    DECIMAL(10,2),
        run_status          VARCHAR(20),
        records_extracted   BIGINT        DEFAULT 0,
        records_loaded      BIGINT        DEFAULT 0,
        records_rejected    BIGINT        DEFAULT 0,
        watermark_value     VARCHAR(100),
        error_details       NVARCHAR(MAX),
        run_by              VARCHAR(80)   DEFAULT SYSTEM_USER
    );
    PRINT '✓ etl.pipeline_run_log created.';
END
GO

-- ── ETL Monitor View ──────────────────────────────────────────
IF OBJECT_ID('etl.v_pipeline_monitor','V') IS NOT NULL DROP VIEW etl.v_pipeline_monitor;
GO
CREATE VIEW etl.v_pipeline_monitor AS
SELECT
    j.job_id, j.job_name, j.job_type,
    j.source_system, j.target_schema, j.target_table,
    j.last_run_start, j.last_run_end, j.last_run_status,
    j.records_loaded,
    DATEDIFF(SECOND, j.last_run_start, j.last_run_end)           AS last_run_seconds,
    j.is_active,
    -- Health signal
    CASE
        WHEN j.last_run_status = 'PENDING'  THEN 'NOT YET RUN'
        WHEN j.last_run_status = 'SUCCESS'
          AND DATEDIFF(HOUR, j.last_run_start, GETDATE()) <= 25   THEN 'HEALTHY'
        WHEN j.last_run_status = 'SUCCESS'
          AND DATEDIFF(HOUR, j.last_run_start, GETDATE()) > 25    THEN 'STALE'
        WHEN j.last_run_status = 'FAILED'                         THEN 'FAILED'
        ELSE 'UNKNOWN'
    END                                                           AS pipeline_health,
    -- Recent run count
    (SELECT COUNT(*) FROM etl.pipeline_run_log rl
     WHERE rl.job_id=j.job_id AND rl.run_start >= DATEADD(DAY,-7,GETDATE()))  AS runs_last_7d,
    (SELECT COUNT(*) FROM etl.pipeline_run_log rl
     WHERE rl.job_id=j.job_id AND rl.run_status='FAILED'
       AND rl.run_start >= DATEADD(DAY,-7,GETDATE()))             AS failures_last_7d
FROM etl.pipeline_jobs j;
GO
PRINT '✓ etl.v_pipeline_monitor created.';
GO

-- ============================================================
-- MODULE 3 – SECURITY FRAMEWORK
-- Row-level security roles and user profiles
-- ============================================================
IF OBJECT_ID('governance.user_roles','U') IS NULL
BEGIN
    CREATE TABLE governance.user_roles (
        role_id             INT           IDENTITY(1,1) PRIMARY KEY,
        role_name           VARCHAR(50)   NOT NULL UNIQUE,
        role_description    NVARCHAR(200),
        can_view_pii        BIT           DEFAULT 0,
        can_view_credit     BIT           DEFAULT 0,
        can_view_trading    BIT           DEFAULT 0,
        can_view_esg        BIT           DEFAULT 1,
        can_modify_data     BIT           DEFAULT 0,
        is_admin            BIT           DEFAULT 0,
        created_at          DATETIME2     DEFAULT GETDATE()
    );

    INSERT INTO governance.user_roles
        (role_name, role_description, can_view_pii, can_view_credit,
         can_view_trading, can_view_esg, can_modify_data, is_admin)
    VALUES
    ('DATA_VIEWER',       'Read-only: public financial data only',  0,0,0,1,0,0),
    ('ANALYST',           'Full read: all analytical schemas',       0,1,1,1,0,0),
    ('CREDIT_OFFICER',    'Credit risk data and borrower details',   0,1,0,1,0,0),
    ('TREASURY_ANALYST',  'Treasury, liquidity and FX data',         0,0,1,1,0,0),
    ('COMPLIANCE',        'Full read incl. PII and audit logs',       1,1,1,1,0,0),
    ('DATA_ENGINEER',     'ETL, staging and pipeline access',         0,0,0,1,1,0),
    ('FPA_ANALYST',       'FP&A budgets, actuals and variance',       0,0,0,1,1,0),
    ('ESG_ANALYST',       'ESG metrics and scoring only',             0,0,0,1,0,0),
    ('PORTFOLIO_MANAGER', 'Portfolio holdings and performance',       0,0,1,1,0,0),
    ('ADMIN',             'Full system access',                       1,1,1,1,1,1);

    PRINT '✓ governance.user_roles created (10 roles).';
END
GO

-- ── Access Control Matrix View ────────────────────────────────
IF OBJECT_ID('governance.v_access_matrix','V') IS NOT NULL DROP VIEW governance.v_access_matrix;
GO
CREATE VIEW governance.v_access_matrix AS
SELECT
    r.role_name,
    s.name                                                        AS schema_name,
    CASE s.name
        WHEN 'dw'         THEN 'READ'
        WHEN 'mart'       THEN 'READ'
        WHEN 'bi'         THEN 'READ'
        WHEN 'credit'     THEN CASE WHEN r.can_view_credit=1  THEN 'READ' ELSE 'DENIED' END
        WHEN 'treasury'   THEN CASE WHEN r.can_view_trading=1 THEN 'READ' ELSE 'DENIED' END
        WHEN 'forensic'   THEN CASE WHEN r.can_view_pii=1     THEN 'READ' ELSE 'DENIED' END
        WHEN 'fpa'        THEN CASE WHEN r.can_modify_data=1  THEN 'READ/WRITE' ELSE 'READ' END
        WHEN 'esg'        THEN CASE WHEN r.can_view_esg=1     THEN 'READ' ELSE 'DENIED' END
        WHEN 'governance' THEN CASE WHEN r.is_admin=1         THEN 'READ/WRITE' ELSE 'READ' END
        WHEN 'etl'        THEN CASE WHEN r.can_modify_data=1  THEN 'READ/WRITE' ELSE 'DENIED' END
        WHEN 'audit'      THEN CASE WHEN r.can_view_pii=1     THEN 'READ' ELSE 'DENIED' END
        ELSE 'READ'
    END                                                           AS access_level
FROM governance.user_roles r
CROSS JOIN (
    SELECT name FROM sys.schemas
    WHERE name IN ('dw','mart','bi','credit','treasury','forensic',
                   'fpa','esg','governance','etl','audit','market')
) s;
GO
PRINT '✓ governance.v_access_matrix created (role × schema access control).';
GO

-- ============================================================
-- MODULE 4 – COMPLETE ENTERPRISE 360 VIEW
-- Single view linking all 12 portfolio projects
-- ============================================================
IF OBJECT_ID('governance.v_enterprise_company_360','V') IS NOT NULL
    DROP VIEW governance.v_enterprise_company_360;
GO
CREATE VIEW governance.v_enterprise_company_360 AS
SELECT
    -- ── IDENTITY ──────────────────────────────────────────────
    sc.ticker_symbol,
    sc.company_name,
    sc.gics_sector_name,
    sc.country_name,
    sc.fiscal_year,

    -- ── FINANCIAL PERFORMANCE (Projects 1-2) ──────────────────
    sc.revenue_usd_m,
    sc.revenue_yoy_pct                                            AS revenue_growth_pct,
    sc.ebitda_usd_m,
    sc.ebitda_margin_pct,
    sc.net_margin_pct,
    sc.roe_pct,
    sc.roa_pct,
    sc.fcf_usd_m,
    sc.fcf_margin_pct,

    -- ── BALANCE SHEET STRENGTH (Project 1) ────────────────────
    sc.net_debt_to_ebitda                                         AS leverage_ratio,

    -- ── EFFICIENCY (Project 2) ────────────────────────────────
    sc.dso,
    sc.dpo,
    sc.asset_turnover,

    -- ── VALUATION PROXIES (Project 3) ─────────────────────────
    sp.adj_close_price                                            AS share_price,
    sp.market_cap_m                                               AS market_cap_usd_m,

    -- ── PORTFOLIO (Project 4) ─────────────────────────────────
    ph.portfolio_total_return_pct                                 AS portfolio_return_pct,
    ph.portfolio_total_value_m                                    AS holdings_value_m,

    -- ── CREDIT RISK (Project 5) ───────────────────────────────
    cr.total_credit_outstanding_m,
    cr.total_expected_loss_m,
    cr.max_pd_pct,

    -- ── FRAUD RISK (Project 6) ────────────────────────────────
    fr.flagged_transaction_count,
    fr.max_fraud_score,

    -- ── ESG (Project 10) ──────────────────────────────────────
    esg.composite_esg_score,
    esg.esg_letter_rating,
    esg.carbon_intensity,
    esg.environmental_score,
    esg.social_score,
    esg.governance_score,

    -- ── KPI TRAFFIC LIGHTS (Project 11) ──────────────────────
    sc.revenue_status,
    sc.margin_status,
    sc.leverage_status,
    sc.roe_status,
    sc.fcf_status,
    sc.performance_band

FROM bi.v_executive_scorecard sc

-- Stock price (most recent year)
LEFT JOIN (
    SELECT DISTINCT
        c.ticker_symbol,
        FIRST_VALUE(sp.adj_close_price) OVER (
            PARTITION BY sp.company_key ORDER BY sp.date_key DESC
            ROWS UNBOUNDED PRECEDING) AS adj_close_price,
        FIRST_VALUE(sp.market_cap_m) OVER (
            PARTITION BY sp.company_key ORDER BY sp.date_key DESC
            ROWS UNBOUNDED PRECEDING) AS market_cap_m
    FROM dw.fact_stock_price sp
    JOIN dw.dim_company c ON sp.company_key=c.company_key AND c.is_current=1
) sp ON sc.ticker_symbol=sp.ticker_symbol

-- Portfolio performance (aggregated across all portfolios)
LEFT JOIN (
    SELECT ticker_symbol,
           SUM(market_value_m)                     AS portfolio_total_value_m,
           AVG(portfolio_total_return_pct)          AS portfolio_total_return_pct
    FROM mart.v_portfolio_performance
    GROUP BY ticker_symbol
) ph ON sc.ticker_symbol=ph.ticker_symbol

-- Credit risk exposure (matched on borrower name containing ticker)
LEFT JOIN (
    SELECT b.borrower_name,
           ROUND(SUM(lf.outstanding_balance)/1e6,2) AS total_credit_outstanding_m,
           ROUND(SUM(lf.expected_loss_usd)/1e6,4)   AS total_expected_loss_m,
           MAX(lf.pd_pct)                            AS max_pd_pct
    FROM credit.loan_facilities lf
    JOIN credit.borrowers b ON lf.borrower_key=b.borrower_key
    GROUP BY b.borrower_name
) cr ON sc.company_name LIKE '%' + cr.borrower_name + '%'
     OR cr.borrower_name LIKE '%' + sc.ticker_symbol + '%'

-- Fraud risk (from transaction analysis)
LEFT JOIN (
    SELECT c.ticker_symbol,
           COUNT(*)     AS flagged_transaction_count,
           MAX(ea.fraud_score) AS max_fraud_score
    FROM forensic.v_expense_anomalies ea
    JOIN forensic.transactions ft ON ea.transaction_id=ft.transaction_id
    JOIN dw.dim_company c ON ft.company_key=c.company_key
    WHERE ea.fraud_score >= 20
    GROUP BY c.ticker_symbol
) fr ON sc.ticker_symbol=fr.ticker_symbol

-- ESG scores (most recent year)
LEFT JOIN (
    SELECT ticker_symbol,
           composite_esg_score, esg_letter_rating, carbon_intensity,
           environmental_score, social_score, governance_score,
           report_year
    FROM esg.v_esg_scores
    WHERE report_year = (SELECT MAX(report_year) FROM esg.v_esg_scores)
) esg ON sc.ticker_symbol=esg.ticker_symbol;
GO
PRINT '✓ governance.v_enterprise_company_360 created (links all 12 projects).';
GO

-- ============================================================
-- MODULE 5 – FINAL PLATFORM HEALTH SUMMARY PROCEDURE
-- ============================================================
IF OBJECT_ID('governance.usp_platform_health_report','P') IS NOT NULL
    DROP PROCEDURE governance.usp_platform_health_report;
GO
CREATE PROCEDURE governance.usp_platform_health_report
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '==============================================';
    PRINT ' FINANCEPORTFOLIO – PLATFORM HEALTH REPORT';
    PRINT ' Generated: ' + CONVERT(VARCHAR(30), GETDATE(), 120);
    PRINT '==============================================';

    -- 1. Object Inventory
    PRINT '-- SECTION 1: Database Object Inventory';
    SELECT
        o.type_desc          AS object_type,
        COUNT(*)             AS object_count,
        COUNT(DISTINCT s.name) AS schema_count
    FROM sys.objects o
    JOIN sys.schemas s ON o.schema_id=s.schema_id
    WHERE o.type IN ('U','V','P','IF','TF','TR')
      AND s.name NOT IN ('sys','INFORMATION_SCHEMA','guest',
                         'db_owner','db_accessadmin','db_securityadmin',
                         'db_ddladmin','db_backupoperator','db_datareader',
                         'db_datawriter','db_denydatareader','db_denydatawriter')
    GROUP BY o.type_desc
    ORDER BY object_count DESC;

    -- 2. Row counts
    PRINT '-- SECTION 2: Table Row Counts';
    SELECT module, component, records, last_loaded
    FROM governance.v_platform_health
    ORDER BY module, component;

    -- 3. DQ Checks
    PRINT '-- SECTION 3: Data Quality Check Results';
    EXEC governance.usp_run_dq_checks;

    -- 4. Data dictionary coverage
    PRINT '-- SECTION 4: Data Dictionary Coverage';
    SELECT schema_name, COUNT(*) AS columns_documented,
           SUM(CASE WHEN business_definition IS NOT NULL THEN 1 ELSE 0 END) AS with_definitions,
           SUM(CASE WHEN is_pii=1 THEN 1 ELSE 0 END) AS pii_columns
    FROM governance.data_dictionary
    GROUP BY schema_name
    ORDER BY schema_name;

    -- 5. ETL Status
    PRINT '-- SECTION 5: ETL Pipeline Status';
    SELECT job_name, job_type, source_system, target_schema,
           last_run_status, pipeline_health, runs_last_7d, failures_last_7d
    FROM etl.v_pipeline_monitor
    WHERE is_active=1
    ORDER BY job_name;

    -- 6. Glossary term count
    PRINT '-- SECTION 6: Business Glossary';
    SELECT domain, COUNT(*) AS terms
    FROM governance.business_glossary
    GROUP BY domain ORDER BY domain;

    PRINT '==============================================';
    PRINT ' REPORT COMPLETE';
    PRINT '==============================================';
END;
GO
PRINT '✓ governance.usp_platform_health_report created.';
GO

-- ============================================================
-- FINAL VERIFICATION – ALL 6 PARTS
-- ============================================================
PRINT '';
PRINT '==============================================';
PRINT ' PART 6 FINAL VERIFICATION';
PRINT '==============================================';
GO

PRINT '-- 1. Enterprise 360 View (all 12 projects linked)';
SELECT
    ticker_symbol, company_name, fiscal_year,
    revenue_usd_m, ebitda_margin_pct, roe_pct,
    share_price, market_cap_usd_m,
    portfolio_return_pct,
    composite_esg_score, esg_letter_rating,
    carbon_intensity,
    flagged_transaction_count, max_fraud_score,
    revenue_status, margin_status, performance_band
FROM governance.v_enterprise_company_360
ORDER BY ticker_symbol, fiscal_year;
GO

PRINT '-- 2. Data Dictionary Coverage';
SELECT schema_name,
       COUNT(*)                                                    AS total_columns,
       SUM(CASE WHEN business_definition IS NOT NULL THEN 1 ELSE 0 END) AS documented,
       SUM(CASE WHEN is_pii=1 THEN 1 ELSE 0 END)                  AS pii_flagged,
       ROUND(SUM(CASE WHEN business_definition IS NOT NULL THEN 1.0 ELSE 0 END)
             / NULLIF(COUNT(*),0)*100,0)                           AS coverage_pct
FROM governance.data_dictionary
GROUP BY schema_name
ORDER BY schema_name;
GO

PRINT '-- 3. Business Glossary';
SELECT term, abbreviation, category, domain,
       LEFT(definition, 80) + '...' AS definition_preview
FROM governance.business_glossary
ORDER BY domain, term;
GO

PRINT '-- 4. Access Control Matrix';
SELECT role_name, schema_name, access_level
FROM governance.v_access_matrix
WHERE access_level <> 'DENIED'
ORDER BY role_name, schema_name;
GO

PRINT '-- 5. Data Lineage';
SELECT target_schema, target_table, target_column,
       source_system, load_frequency, data_owner
FROM governance.data_lineage
ORDER BY target_schema, target_table;
GO

PRINT '-- 6. Full Platform Health Report';
EXEC governance.usp_platform_health_report;
GO

-- ============================================================
-- GRAND TOTAL – COMPLETE PORTFOLIO OBJECT COUNT
-- ============================================================
PRINT '';
PRINT '==============================================';
PRINT ' GRAND TOTAL – ALL 6 PARTS COMBINED';
PRINT '==============================================';
GO
SELECT
    s.name               AS schema_name,
    COUNT(CASE WHEN o.type='U'           THEN 1 END) AS tables,
    COUNT(CASE WHEN o.type='V'           THEN 1 END) AS views,
    COUNT(CASE WHEN o.type='P'           THEN 1 END) AS procedures,
    COUNT(CASE WHEN o.type IN('IF','TF') THEN 1 END) AS functions,
    COUNT(CASE WHEN o.type='TR'          THEN 1 END) AS triggers,
    COUNT(o.object_id)                               AS total_objects
FROM sys.schemas s
LEFT JOIN sys.objects o ON s.schema_id=o.schema_id
    AND o.type IN ('U','V','P','IF','TF','TR')
WHERE s.name IN ('dw','mart','credit','forensic','fpa','treasury',
                 'market','esg','bi','governance','etl','audit')
GROUP BY s.name
ORDER BY s.name;
GO

SELECT
    'TABLES'             AS object_type,
    COUNT(*)             AS total_count
FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id
WHERE s.name NOT IN ('sys','INFORMATION_SCHEMA')
UNION ALL SELECT 'VIEWS',
    COUNT(*) FROM sys.views v JOIN sys.schemas s ON v.schema_id=s.schema_id
WHERE s.name NOT IN ('sys','INFORMATION_SCHEMA')
UNION ALL SELECT 'STORED PROCEDURES',
    COUNT(*) FROM sys.procedures p JOIN sys.schemas s ON p.schema_id=s.schema_id
WHERE s.name NOT IN ('sys','INFORMATION_SCHEMA')
UNION ALL SELECT 'FUNCTIONS (TVF)',
    COUNT(*) FROM sys.objects o JOIN sys.schemas s ON o.schema_id=s.schema_id
WHERE o.type IN ('IF','TF') AND s.name NOT IN ('sys','INFORMATION_SCHEMA')
UNION ALL SELECT 'TRIGGERS',
    COUNT(*) FROM sys.triggers
UNION ALL SELECT 'INDEXES',
    COUNT(*) FROM sys.indexes i JOIN sys.tables t ON i.object_id=t.object_id
JOIN sys.schemas s ON t.schema_id=s.schema_id
WHERE i.type > 0 AND s.name NOT IN ('sys','INFORMATION_SCHEMA')
UNION ALL SELECT 'SCHEMAS',
    COUNT(*) FROM sys.schemas
WHERE name IN ('dw','mart','credit','forensic','fpa','treasury',
               'market','esg','bi','governance','etl','audit');
GO

PRINT '';
PRINT '==============================================';
PRINT ' PORTFOLIO COMPLETE – ALL 6 FILES DEPLOYED';
PRINT '==============================================';
PRINT '';
PRINT ' FILE ORDER (run in SSMS in this sequence):';
PRINT ' 1. COMPLETE_PORTFOLIO_SQLSERVER.sql';
PRINT '    -> Core DW, dimensions, facts, credit risk,';
PRINT '       financial ratios, executive scorecard';
PRINT '';
PRINT ' 2. PORTFOLIO_ANALYTICS_PART2.sql';
PRINT '    -> FP&A (budget/actuals/variance), Treasury,';
PRINT '       Market technical indicators, ESG scoring, BI views';
PRINT '';
PRINT ' 3. PORTFOLIO_PART3_FINAL.sql';
PRINT '    -> Fraud detection, advanced window functions,';
PRINT '       dynamic SQL pivot, stress test procedure';
PRINT '';
PRINT ' 4. PORTFOLIO_PART4_INTERVIEW_README.sql';
PRINT '    -> 10 interview query patterns, CTE chains,';
PRINT '       self-joins, CROSS APPLY, outlier detection';
PRINT '';
PRINT ' 5. PORTFOLIO_PART5_STOCK_DATA_VIEWS.sql';
PRINT '    -> Stock prices, portfolio holdings, P&L,';
PRINT '       economic indicators, exchange rate trends';
PRINT '';
PRINT ' 6. PORTFOLIO_PART6_CAPSTONE.sql  <- THIS FILE';
PRINT '    -> Data governance, DQ rules engine, security,';
PRINT '       Enterprise 360 view, platform health report';
PRINT '';
PRINT ' QUICK SMOKE TEST (run any time after all 6 files):';
PRINT '   SELECT * FROM mart.v_financial_ratios;';
PRINT '   SELECT * FROM bi.v_executive_scorecard;';
PRINT '   SELECT * FROM credit.v_risk_dashboard;';
PRINT '   SELECT * FROM esg.v_esg_scores;';
PRINT '   SELECT * FROM governance.v_enterprise_company_360;';
PRINT '   SELECT * FROM forensic.v_expense_anomalies;';
PRINT '   EXEC governance.usp_platform_health_report;';
PRINT '   EXEC governance.usp_run_dq_checks;';
PRINT '   EXEC mart.usp_portfolio_snapshot ''PORT-TECH'';';
PRINT '   EXEC credit.usp_amortisation_schedule 5000000,7.0,60,''2024-01-01'';';
PRINT '   EXEC mart.usp_scenario_stress_test ''AAPL'',2023,-0.10,-0.05,0.02;';
PRINT '==============================================';
GO

-- ============================================================
-- SMOKE TEST – Run after all 6 parts to confirm deployment
-- Expected: all queries return rows, no errors
-- ============================================================
USE FinancePortfolio;
GO

PRINT '=== SMOKE TEST START ===';

-- 1. Dimension tables
SELECT 'dim_date'     AS tbl, COUNT(*) AS rows FROM dw.dim_date     UNION ALL
SELECT 'dim_company',          COUNT(*)          FROM dw.dim_company UNION ALL
SELECT 'dim_industry',         COUNT(*)          FROM dw.dim_industry UNION ALL
SELECT 'dim_country',          COUNT(*)          FROM dw.dim_country  UNION ALL
SELECT 'dim_account',          COUNT(*)          FROM dw.dim_account;

-- 2. Fact tables
SELECT 'fact_income_statement' AS tbl, COUNT(*) AS rows FROM dw.fact_income_statement UNION ALL
SELECT 'fact_balance_sheet',           COUNT(*)          FROM dw.fact_balance_sheet    UNION ALL
SELECT 'fact_cash_flow',               COUNT(*)          FROM dw.fact_cash_flow        UNION ALL
SELECT 'fact_stock_price',             COUNT(*)          FROM dw.fact_stock_price      UNION ALL
SELECT 'fact_exchange_rate',           COUNT(*)          FROM dw.fact_exchange_rate    UNION ALL
SELECT 'fact_economic_indicator',      COUNT(*)          FROM dw.fact_economic_indicator;

-- 3. Core analytical views
SELECT 'v_financial_ratios'       AS view_name, COUNT(*) AS rows FROM mart.v_financial_ratios   UNION ALL
SELECT 'v_executive_scorecard',               COUNT(*)          FROM bi.v_executive_scorecard    UNION ALL
SELECT 'v_risk_dashboard',                    COUNT(*)          FROM credit.v_risk_dashboard     UNION ALL
SELECT 'v_esg_scores',                        COUNT(*)          FROM esg.v_esg_scores            UNION ALL
SELECT 'v_portfolio_performance',             COUNT(*)          FROM mart.v_portfolio_performance UNION ALL
SELECT 'v_expense_anomalies',                 COUNT(*)          FROM forensic.v_expense_anomalies UNION ALL
SELECT 'v_duplicate_payments',                COUNT(*)          FROM forensic.v_duplicate_payments UNION ALL
SELECT 'v_liquidity_dashboard',               COUNT(*)          FROM treasury.v_liquidity_dashboard UNION ALL
SELECT 'v_working_capital',                   COUNT(*)          FROM treasury.v_working_capital  UNION ALL
SELECT 'v_forecast_accuracy',                 COUNT(*)          FROM fpa.v_forecast_accuracy     UNION ALL
SELECT 'v_enterprise_company_360',            COUNT(*)          FROM governance.v_enterprise_company_360 UNION ALL
SELECT 'v_stock_return_analytics',            COUNT(*)          FROM mart.v_stock_return_analytics UNION ALL
SELECT 'v_economic_context',                  COUNT(*)          FROM mart.v_economic_context     UNION ALL
SELECT 'v_exchange_rate_trends',              COUNT(*)          FROM mart.v_exchange_rate_trends UNION ALL
SELECT 'v_ranking_engine',                    COUNT(*)          FROM mart.v_ranking_engine;

-- 4. Data Quality
SELECT * FROM dw.fn_validate_warehouse();

-- 5. Key procedures
EXEC credit.usp_credit_risk_summary;
EXEC credit.usp_amortisation_schedule 1000000, 6.5, 12, '2024-01-01';
EXEC mart.usp_portfolio_snapshot 'PORT-TECH';
EXEC mart.usp_scenario_stress_test 'AAPL', 2023, -0.10, -0.05, 0.02;
EXEC governance.usp_run_dq_checks;

-- 6. Platform health
SELECT module, component, records FROM governance.v_platform_health ORDER BY module;

PRINT '=== SMOKE TEST COMPLETE ===';
PRINT 'If all queries above returned rows without errors – deployment is successful.';
GO