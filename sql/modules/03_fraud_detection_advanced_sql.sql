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

