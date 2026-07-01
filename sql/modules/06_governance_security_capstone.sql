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
    -- BUGFIX: every rule_sql below was originally a bare "SELECT COUNT(*) FROM ..."
    -- which does not satisfy the @cnt OUTPUT parameter that
    -- governance.usp_run_dq_checks passes to sp_executesql. That caused all
    -- 10 rules to throw "Procedure expects parameter '@cnt' which was not
    -- supplied" inside the TRY/CATCH, reported as ERROR for every rule.
    -- Fixed by assigning directly to @cnt instead of returning a result set.
    ('IS_Revenue_Not_Null','COMPLETENESS','dw','fact_income_statement',
     'SELECT @cnt = COUNT(*) FROM dw.fact_income_statement WHERE total_revenue IS NULL','CRITICAL','Finance Data Team'),
    ('IS_No_Negative_Revenue','ACCURACY','dw','fact_income_statement',
     'SELECT @cnt = COUNT(*) FROM dw.fact_income_statement WHERE total_revenue < 0','HIGH','Finance Data Team'),
    ('BS_Balance_Sheet_Equation','CONSISTENCY','dw','fact_balance_sheet',
     'SELECT @cnt = COUNT(*) FROM dw.fact_balance_sheet WHERE ABS(ISNULL(total_assets,0)-ISNULL(total_liabilities,0)-ISNULL(total_equity,0)) > 1.0','CRITICAL','Finance Data Team'),
    ('SP_No_Zero_Price','ACCURACY','dw','fact_stock_price',
     'SELECT @cnt = COUNT(*) FROM dw.fact_stock_price WHERE close_price <= 0','CRITICAL','Market Data Team'),
    ('SP_No_Future_Dates','TIMELINESS','dw','fact_stock_price',
     'SELECT @cnt = COUNT(*) FROM dw.fact_stock_price sp JOIN dw.dim_date d ON sp.date_key=d.date_key WHERE d.full_date > GETDATE()','HIGH','Market Data Team'),
    ('COMP_Unique_Active_Ticker','UNIQUENESS','dw','dim_company',
     'SELECT @cnt = COUNT(*) FROM (SELECT ticker_symbol FROM dw.dim_company WHERE is_current=1 GROUP BY ticker_symbol HAVING COUNT(*)>1) t','CRITICAL','Finance Data Team'),
    ('CR_PD_In_Range','ACCURACY','credit','loan_facilities',
     'SELECT @cnt = COUNT(*) FROM credit.loan_facilities WHERE pd_pct NOT BETWEEN 0 AND 100','HIGH','Credit Risk Team'),
    ('CR_LGD_In_Range','ACCURACY','credit','loan_facilities',
     'SELECT @cnt = COUNT(*) FROM credit.loan_facilities WHERE lgd_pct NOT BETWEEN 0 AND 100','HIGH','Credit Risk Team'),
    ('ESG_Renewable_Pct_Range','ACCURACY','esg','esg_metrics',
     'SELECT @cnt = COUNT(*) FROM esg.esg_metrics WHERE renewable_energy_pct NOT BETWEEN 0 AND 100','MEDIUM','ESG Team'),
    ('FPA_Actuals_No_Future','TIMELINESS','fpa','actuals',
     'SELECT @cnt = COUNT(*) FROM fpa.actuals WHERE fiscal_year > YEAR(GETDATE())','MEDIUM','FP&A Team');

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
