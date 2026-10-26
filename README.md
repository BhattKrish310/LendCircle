<<<<<<< HEAD
# LendCircle
Peer-to-peer lending platform built with Python Flask and MySQL, featuring borrower loan requests, lender funding, repayment tracking, and a relational database design.
=======

## 1. Overview

LendCircle is a full-featured, mobile-friendly FinTech web application connecting borrowers directly with individual lenders across India. The platform manages the entire loan lifecycle:
- **Dedicated Lending & Blog Hubs** with clear borrower & lender journeys
- **7 Comprehensive Educational Guides** covering due diligence, cost structures, repayment planning, risk factors, and scam protection
- **Transparent Fee & Risk Disclosures** with zero hidden pre-payment penalties and realistic non-guaranteed risk notices
- **KYC Submission & Verification** with admin workflow
- **Digital Wallet** with non-negative balance constraints (`balance >= 0.00`) and double-entry style financial transaction ledger
- **Loan Requests & Marketplace** with real-time dynamic EMI calculator
- **Fractional / Full Investment Funding** with atomic wallet transfers
- **Automatic Loan Origination** upon 100% funding
- **EMI Amortization Schedules** generated via Stored Procedure
- **Proportional Repayment Distribution** among fractional backers
- **Dynamic Credit Scoring** (+10 for on-time payments, -25 for missed payments)
- **Automated Risk Flagging** for high debt-to-income and multiple overdue installments
- **Admin Control Panel** with live supervision, user management, KYC queue, and financial analytics
- **Responsive Interface** in a clean **Navy-and-Green** palette with an instant **Light & Dark Theme Toggle**

---

## 2. Database Architecture & DBMS Concepts

The MySQL database (`p2p_lending_db`) demonstrates advanced relational database concepts:

### 2.1 Schema & Normalization (3NF)
- **`users`**: Base authentication table (full name, email, phone, hashed password, role, status).
- **`borrower_profiles`**: 1:1 extension storing annual income, employment status, credit score, and risk rating.
- **`lender_profiles`**: 1:1 extension storing self-imposed investment limit, total capital deployed, and total earnings.
- **`kyc_documents`**: Identity verification records (`Aadhaar`, `PAN`, `Passport`, `Driving License`) with admin review audit fields.
- **`wallets`**: 1:1 user wallet with non-negative check constraints (`balance >= 0.00`).
- **`transactions`**: Complete audit ledger recording every Credit/Debit (Deposits, Disbursements, Investments, EMI Payments, Returns, Penalties).
- **`loan_requests`**: Loan listings created by borrowers with target amount, interest rate, tenure, and live funding progress.
- **`investments`**: M:N junction recording fractional or full funding contributions by lenders.
- **`loans`**: Active, completed, or defaulted contracts created automatically once a request reaches 100% funding.
- **`repayment_schedules`**: Full monthly amortization schedule tracking principal component, interest component, due date, status, and late penalties.
- **`credit_score_histories`**: Historical audit log of every credit score change and its triggering event.
- **`risk_flags`**: Underwriting supervision alerts generated for high debt-to-income or consecutive overdue payments.
- **`platform_metrics_daily`**: Materialized summary table refreshed periodically for high-speed reporting.

### 2.2 Stored Functions & Procedures
1. **`fn_calculate_emi(principal, annual_rate, tenure_months)`**: Computes exact monthly amortized EMI payments using the standard financial reducing balance formula:
   $$\text{EMI} = \frac{P \cdot r \cdot (1 + r)^n}{(1 + r)^n - 1}$$
   *(where $P$ is principal, $r$ is monthly rate, and $n$ is tenure in months)*
2. **`fn_calculate_lender_returns(lender_id)`**: Computes total realized returns for an investor.
3. **`sp_generate_emi_schedule(loan_id)`**: Generates the complete month-by-month principal and interest amortization breakdown.
4. **`sp_fund_loan_request(request_id, lender_id, amount, OUT status, OUT msg)`**: Atomically transfers investment funds, records ledger transactions, and automatically creates the loan contract and amortizes the schedule upon 100% funding.
5. **`sp_pay_emi_installment(schedule_id, borrower_id, OUT status, OUT msg)`**: Deducts EMI from the borrower's wallet, distributes funds proportionally to fractional lenders, audits ledger entries, and increases the borrower's credit score.
6. **`sp_check_and_mark_overdue()`**: Identifies overdue payments, calculates late penalties (2%), adjusts credit score downward (-25 points), and generates risk flags for delinquent accounts.
7. **`sp_refresh_platform_metrics()`**: Re-aggregates system-wide analytics into `platform_metrics_daily`.

### 2.3 Triggers
- **`trg_after_user_insert`**: Automatically initializes a digital wallet and corresponding role profile upon new user registration.
- **`trg_before_borrower_profile_update`**: Automatically updates risk category (`Low`, `Moderate`, `High`) based on the credit score.
- **`trg_after_borrower_profile_update`**: Automatically logs an entry into `credit_score_histories` whenever a score changes.
- **`trg_after_loan_request_insert`**: Raises an automated high-debt-to-income risk flag if a borrower requests more than 80% of their annual income.

### 2.4 Views
- **`vw_loan_marketplace`**: Clean view of open requests, remaining capital needed, borrower credit metrics, and estimated EMIs.
- **`vw_borrower_risk_summary`**: Comprehensive borrower underwriting profile, active debt, overdue count, and open risk flags.
- **`vw_monthly_platform_revenue`**: Aggregated monthly disbursements, repayments, penalties collected, and origination count.
- **`vw_lender_portfolio_summary`**: Investor portfolio yields, active investments, and return ratios.

---
