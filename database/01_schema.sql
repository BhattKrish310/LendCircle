-- =====================================================================
-- P2P Lending Platform Database Schema (MySQL 8.0+)
-- Normalized to 3NF, Enforced Constraints, Audit Fields & Ledger Integrity
-- =====================================================================

CREATE DATABASE IF NOT EXISTS p2p_lending_db
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE p2p_lending_db;

-- 1. Users Table (Core entity for authentication and role management)
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('borrower', 'lender', 'admin') NOT NULL,
    status ENUM('active', 'suspended') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_role (role),
    INDEX idx_user_status (status)
) ENGINE=InnoDB;

-- 2. Borrower Profiles (Extends User for borrower-specific metrics)
CREATE TABLE IF NOT EXISTS borrower_profiles (
    user_id INT PRIMARY KEY,
    annual_income DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    employment_status ENUM('Salaried', 'Self-Employed', 'Business', 'Freelancer', 'Unemployed') NOT NULL DEFAULT 'Salaried',
    credit_score INT NOT NULL DEFAULT 650,
    risk_category ENUM('Low', 'Moderate', 'High') NOT NULL DEFAULT 'Moderate',
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_borrower_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_credit_score_range CHECK (credit_score BETWEEN 300 AND 900),
    CONSTRAINT chk_income_nonneg CHECK (annual_income >= 0.00)
) ENGINE=InnoDB;

-- 3. Lender Profiles (Extends User for lender-specific metrics)
CREATE TABLE IF NOT EXISTS lender_profiles (
    user_id INT PRIMARY KEY,
    investment_limit DECIMAL(12,2) NOT NULL DEFAULT 1000000.00,
    total_invested DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_earned DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_lender_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_lender_limit_nonneg CHECK (investment_limit >= 0.00)
) ENGINE=InnoDB;

-- 4. KYC Documents
CREATE TABLE IF NOT EXISTS kyc_documents (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    document_type ENUM('Aadhaar', 'PAN', 'Passport', 'Driving License') NOT NULL,
    document_number VARCHAR(50) NOT NULL,
    document_url VARCHAR(255),
    status ENUM('Pending', 'Verified', 'Rejected') NOT NULL DEFAULT 'Pending',
    admin_remarks TEXT,
    reviewed_by INT NULL,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP NULL,
    CONSTRAINT fk_kyc_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_kyc_reviewer FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_kyc_status (status)
) ENGINE=InnoDB;

-- 5. Digital Wallets
CREATE TABLE IF NOT EXISTS wallets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_wallet_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_wallet_balance_nonnegative CHECK (balance >= 0.00)
) ENGINE=InnoDB;

-- 6. Loan Requests
CREATE TABLE IF NOT EXISTS loan_requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    borrower_id INT NOT NULL,
    title VARCHAR(150) NOT NULL,
    purpose VARCHAR(255) NOT NULL,
    requested_amount DECIMAL(12,2) NOT NULL,
    interest_rate DECIMAL(5,2) NOT NULL,
    tenure_months INT NOT NULL,
    funded_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    status ENUM('Open', 'Funded', 'Closed', 'Cancelled') NOT NULL DEFAULT 'Open',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    CONSTRAINT fk_request_borrower FOREIGN KEY (borrower_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT chk_loan_req_amount CHECK (requested_amount >= 1000.00),
    CONSTRAINT chk_loan_req_rate CHECK (interest_rate > 0.00 AND interest_rate <= 40.00),
    CONSTRAINT chk_loan_req_tenure CHECK (tenure_months >= 1 AND tenure_months <= 120),
    CONSTRAINT chk_loan_funded_amount CHECK (funded_amount >= 0.00 AND funded_amount <= requested_amount),
    INDEX idx_loan_req_status (status),
    INDEX idx_loan_req_borrower (borrower_id)
) ENGINE=InnoDB;

-- 7. Investments (M:N junction between Lenders and Loan Requests)
CREATE TABLE IF NOT EXISTS investments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    loan_request_id INT NOT NULL,
    lender_id INT NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    funded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_inv_request FOREIGN KEY (loan_request_id) REFERENCES loan_requests(id) ON DELETE RESTRICT,
    CONSTRAINT fk_inv_lender FOREIGN KEY (lender_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT chk_inv_amount CHECK (amount > 0.00),
    INDEX idx_inv_request (loan_request_id),
    INDEX idx_inv_lender (lender_id)
) ENGINE=InnoDB;

-- 8. Loans (Generated once a loan request reaches 100% funding)
CREATE TABLE IF NOT EXISTS loans (
    id INT AUTO_INCREMENT PRIMARY KEY,
    loan_request_id INT NOT NULL UNIQUE,
    borrower_id INT NOT NULL,
    principal_amount DECIMAL(12,2) NOT NULL,
    interest_rate DECIMAL(5,2) NOT NULL,
    tenure_months INT NOT NULL,
    monthly_emi DECIMAL(12,2) NOT NULL,
    total_repayable DECIMAL(12,2) NOT NULL,
    status ENUM('Active', 'Completed', 'Defaulted') NOT NULL DEFAULT 'Active',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_loan_request FOREIGN KEY (loan_request_id) REFERENCES loan_requests(id) ON DELETE RESTRICT,
    CONSTRAINT fk_loan_borrower FOREIGN KEY (borrower_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT chk_loan_principal CHECK (principal_amount > 0.00),
    CONSTRAINT chk_loan_emi CHECK (monthly_emi > 0.00),
    INDEX idx_loan_status (status),
    INDEX idx_loan_borrower (borrower_id)
) ENGINE=InnoDB;

-- 9. Repayment Schedules (Amortization Schedule per Loan)
CREATE TABLE IF NOT EXISTS repayment_schedules (
    id INT AUTO_INCREMENT PRIMARY KEY,
    loan_id INT NOT NULL,
    installment_number INT NOT NULL,
    due_date DATE NOT NULL,
    principal_component DECIMAL(12,2) NOT NULL,
    interest_component DECIMAL(12,2) NOT NULL,
    emi_amount DECIMAL(12,2) NOT NULL,
    penalty_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    status ENUM('Pending', 'Paid', 'Overdue') NOT NULL DEFAULT 'Pending',
    paid_at TIMESTAMP NULL,
    CONSTRAINT fk_schedule_loan FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE CASCADE,
    CONSTRAINT chk_installment_no CHECK (installment_number > 0),
    CONSTRAINT chk_emi_components CHECK (emi_amount >= 0.00 AND penalty_amount >= 0.00),
    UNIQUE KEY uq_loan_installment (loan_id, installment_number),
    INDEX idx_schedule_status (status),
    INDEX idx_schedule_due_date (due_date)
) ENGINE=InnoDB;

-- 10. Financial Transactions Ledger
CREATE TABLE IF NOT EXISTS transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    wallet_id INT NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    type ENUM('Deposit', 'Withdrawal', 'Disbursement', 'EMI Payment', 'Investment', 'Repayment Received', 'Penalty') NOT NULL,
    direction ENUM('Credit', 'Debit') NOT NULL,
    reference_id VARCHAR(100) NULL,
    balance_after DECIMAL(15,2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_tx_wallet FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE RESTRICT,
    CONSTRAINT chk_tx_amount CHECK (amount > 0.00),
    INDEX idx_tx_wallet (wallet_id),
    INDEX idx_tx_type (type),
    INDEX idx_tx_created (created_at)
) ENGINE=InnoDB;

-- 11. Credit Score History
CREATE TABLE IF NOT EXISTS credit_score_histories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    borrower_id INT NOT NULL,
    previous_score INT NOT NULL,
    new_score INT NOT NULL,
    change_reason VARCHAR(255) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_score_borrower FOREIGN KEY (borrower_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_csh_borrower (borrower_id)
) ENGINE=InnoDB;

-- 12. Risk Flags (Risk and fraud monitoring)
CREATE TABLE IF NOT EXISTS risk_flags (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    loan_request_id INT NULL,
    flag_type VARCHAR(100) NOT NULL,
    severity ENUM('Low', 'Medium', 'High', 'Critical') NOT NULL DEFAULT 'Medium',
    description TEXT NOT NULL,
    status ENUM('Open', 'Reviewed', 'Dismissed') NOT NULL DEFAULT 'Open',
    reviewed_by INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP NULL,
    CONSTRAINT fk_flag_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_flag_request FOREIGN KEY (loan_request_id) REFERENCES loan_requests(id) ON DELETE SET NULL,
    CONSTRAINT fk_flag_reviewer FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_risk_status (status),
    INDEX idx_risk_severity (severity)
) ENGINE=InnoDB;

-- 13. Platform Metrics Daily (Materialized View table for fast analytical reports)
CREATE TABLE IF NOT EXISTS platform_metrics_daily (
    metric_date DATE PRIMARY KEY,
    total_users INT NOT NULL DEFAULT 0,
    total_borrowers INT NOT NULL DEFAULT 0,
    total_lenders INT NOT NULL DEFAULT 0,
    total_active_loans INT NOT NULL DEFAULT 0,
    total_disbursed DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    total_repaid DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    total_defaulted DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    total_overdue_count INT NOT NULL DEFAULT 0,
    open_risk_flags_count INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;
