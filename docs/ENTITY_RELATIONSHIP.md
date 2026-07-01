# 🗺️ Entity Relationship Diagram

> Text-based ERD for the `dw` schema star schema core, plus the major satellite schemas.
> Rendered as Mermaid — view this file directly on GitHub for the interactive diagram.

---

## Core Star Schema (`dw`)

```mermaid
erDiagram
    dim_company ||--o{ fact_income_statement : "company_key"
    dim_company ||--o{ fact_balance_sheet : "company_key"
    dim_company ||--o{ fact_cash_flow : "company_key"
    dim_company ||--o{ fact_stock_price : "company_key"
    dim_date ||--o{ fact_income_statement : "date_key"
    dim_date ||--o{ fact_balance_sheet : "date_key"
    dim_date ||--o{ fact_cash_flow : "date_key"
    dim_date ||--o{ fact_stock_price : "date_key"
    dim_industry ||--o{ dim_company : "industry_key"
    dim_country ||--o{ dim_company : "country_key"
    dim_account ||--o{ fpa_actuals : "account_code"
    dim_account ||--o{ fpa_budgets : "account_code"

    dim_company {
        int company_key PK
        varchar company_id UK
        varchar ticker_symbol
        int industry_key FK
        int country_key FK
        bit is_current
        date scd_start_date
        date scd_end_date
    }

    dim_date {
        int date_key PK
        date full_date UK
        smallint fiscal_year
        smallint fiscal_quarter
        bit is_weekend
    }

    dim_industry {
        int industry_key PK
        char gics_sector_code
        varchar gics_sector_name
    }

    dim_country {
        int country_key PK
        char country_id UK
        nvarchar country_name
        decimal gdp_usd_bn
    }

    fact_income_statement {
        bigint income_stmt_key PK
        int company_key FK
        int date_key FK
        decimal total_revenue
        decimal gross_profit "computed"
        decimal operating_income
        decimal net_income
    }

    fact_balance_sheet {
        bigint balance_sheet_key PK
        int company_key FK
        int date_key FK
        decimal total_assets
        decimal total_liabilities
        decimal total_equity
        decimal net_debt "computed"
    }

    fact_cash_flow {
        bigint cash_flow_key PK
        int company_key FK
        int date_key FK
        decimal cash_from_operations
        decimal capital_expenditures
        decimal free_cash_flow "computed"
    }

    fact_stock_price {
        bigint stock_price_key PK
        int company_key FK
        int date_key FK
        decimal close_price
        decimal adj_close_price
        decimal market_cap_m
    }
```

---

## Credit Risk Domain (`credit`)

```mermaid
erDiagram
    borrowers ||--o{ loan_facilities : "borrower_key"
    loan_facilities ||--o{ repayment_history : "facility_key"
    pd_master_scale ||--o{ borrowers : "internal_rating = rating"

    borrowers {
        int borrower_key PK
        varchar borrower_id UK
        nvarchar borrower_name
        varchar internal_rating
    }

    loan_facilities {
        bigint facility_key PK
        varchar facility_id UK
        int borrower_key FK
        decimal commitment_usd
        decimal outstanding_balance
        decimal undrawn_amount "computed"
        decimal pd_pct
        decimal lgd_pct
        decimal expected_loss_usd "computed: PD x LGD x EAD"
    }

    pd_master_scale {
        varchar rating PK
        decimal pd_midpoint_pct
        varchar basel_class
    }

    repayment_history {
        bigint repayment_key PK
        int facility_key FK
        date scheduled_date
        decimal total_paid "computed"
        int days_late "computed"
    }
```

---

## Fraud Detection Domain (`forensic`)

```mermaid
erDiagram
    vendors ||--o{ transactions : "vendor_id"
    dim_account ||--o{ transactions : "debit_account / credit_account"

    vendors {
        int vendor_key PK
        varchar vendor_id UK
        nvarchar vendor_name
        bit is_active
    }

    transactions {
        bigint transaction_key PK
        varchar transaction_id UK
        varchar vendor_id FK
        decimal amount
        varchar created_by
        varchar approved_by
        bit is_system_generated
    }
```

---

## Schema Dependency Graph

```mermaid
graph TD
    dw[dw — Core Warehouse] --> mart[mart — Analytics]
    dw --> credit[credit — Basel III]
    dw --> forensic[forensic — Fraud]
    dw --> fpa[fpa — FP&A]
    dw --> treasury[treasury — Treasury]
    dw --> market[market — Market Data]
    dw --> esg[esg — ESG Scoring]
    mart --> bi[bi — CFO Dashboards]
    credit --> bi
    esg --> bi
    forensic --> governance[governance — Capstone]
    fpa --> governance
    treasury --> governance
    mart --> governance
    credit --> governance
    esg --> governance
    governance --> etl[etl — Pipeline Monitor]
    dw --> audit[audit — Change Log]

    style dw fill:#0078D4,color:#fff
    style governance fill:#7c3aed,color:#fff
    style bi fill:#22c55e,color:#fff
```

---

## Reading the Diagrams on GitHub

GitHub natively renders [Mermaid](https://mermaid.js.org/) diagrams inside Markdown files —
no extra setup needed. If viewing this file outside GitHub (e.g. a plain text editor), paste
the code blocks above into the [Mermaid Live Editor](https://mermaid.live) to render them.
