<<<<<<< HEAD
# LendCircle
Peer-to-peer lending platform built with Python Flask and MySQL, featuring borrower loan requests, lender funding, repayment tracking, and a relational database design.
=======
# LendCircle — Transparent P2P Lending Platform

> **DBMS Course Project · FinTech · Version 1.0**  
> *Built with Python/Flask, MySQL 8.0+, HTML5/CSS3 (Navy & Green Palette), and Vanilla JavaScript.*

---

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

## 3. Pre-Configured Demo Accounts

All demo accounts use the standard test password: `password123` (Admin uses `admin123`).

| Role | Email | Password | Persona & Status |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin@p2plending.com` | `admin123` | System Administrator (full access to queue, flags, analytics) |
| **Borrower** | `rahul.sharma@example.com` | `password123` | Verified KYC, Active loan on schedule, 760 Credit Score |
| **Borrower** | `priya.patel@example.com` | `password123` | Verified KYC, Open marketplace loan request (partially funded) |
| **Borrower** | `amit.verma@example.com` | `password123` | Verified KYC, Overdue EMI with penalty, Risk flag generated |
| **Lender** | `arun.mehta@example.com` | `password123` | Verified KYC, ₹2,45,000 wallet balance, multiple investments |
| **Lender** | `neha.gupta@example.com` | `password123` | Verified KYC, ₹1,82,000 wallet balance, active investments |
| **Lender** | `karan.johal@example.com` | `password123` | Verified KYC, ₹3,10,000 wallet balance, funded multiple loans |

---

## 4. Setup & Running the Application

### 4.1 Prerequisites
- Python 3.10+
- MySQL Server 8.0+ running on port 3306

### 4.2 Installation & Dependencies
1. Clone this repository:
   ```powershell
   git clone <your-repository-url>
   cd "P2P Lending"
   ```
2. Create and activate a Python virtual environment (recommended):
   ```powershell
   python -m venv venv
   .\venv\Scripts\Activate.ps1
   ```
3. Install dependencies:
   ```powershell
   pip install -r requirements.txt
   ```

### 4.3 Configuration (`.env`)
Copy the sample environment file to `.env`:
```powershell
copy .env.example .env
```
Update `.env` with your local MySQL credentials:
```ini
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=p2p_lending_db
SECRET_KEY=your_secure_secret_key
```

### 4.4 Initialize Database (Schema, Triggers, Views & Seed Data)
Run the automated initialization script:
```powershell
python database/init_db.py
```
This executes:
1. `database/01_schema.sql` (Tables, constraints, primary & foreign keys)
2. `database/02_procedures_triggers_views.sql` (Stored procedures, triggers, views, functions)
3. `database/03_seed_data.sql` (Realistic sample dataset)

### 4.5 Run Integration Tests
Verify all procedures, views, and routes:
```powershell
python -m unittest test_app.py
```

### 4.6 Start the Web Application
```powershell
python run.py
```
Open your browser and navigate to:
**`http://127.0.0.1:5000`**
>>>>>>> 4ce2cfa (Initial commit: LendCircle P2P Lending Platform)
