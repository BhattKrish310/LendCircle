-- =====================================================================
-- P2P Lending Platform: Realistic Seed Data for DBMS Course Project
-- =====================================================================

USE p2p_lending_db;

-- Passwords:
-- Admin: admin123 -> scrypt:32768:8:1$jNYwTLeXKLCW9pfL$7ac6dc689d771d4de61151b83bba522f0f2eb5dec85a898778c8ada5b12dfe6db25f521d11d7d6b971ee21df46e53e5c05fd236d093837f8c19f828d8033fdd8
-- All other demo users: password123 -> scrypt:32768:8:1$oe0AhsTKXhLJmxgF$070573b3c621d647469e59002bcca0a0c53d310f222a7eeb15235dfbdcb759fd512a705caea8e124af623a4640303f5e113a5c7135e9a6e94d28526b26a6fa6a

-- Temporarily disable triggers or insert users carefully (trigger creates empty wallets and default profiles)
-- 1. Insert Users
INSERT INTO users (id, full_name, email, phone, password_hash, role, status) VALUES
(1, 'System Administrator', 'admin@p2plending.com', '+91 9800000001', 'scrypt:32768:8:1$jNYwTLeXKLCW9pfL$7ac6dc689d771d4de61151b83bba522f0f2eb5dec85a898778c8ada5b12dfe6db25f521d11d7d6b971ee21df46e53e5c05fd236d093837f8c19f828d8033fdd8', 'admin', 'active'),
(2, 'Rahul Sharma', 'rahul.sharma@example.com', '+91 9811122334', 'scrypt:32768:8:1$oe0AhsTKXhLJmxgF$070573b3c621d647469e59002bcca0a0c53d310f222a7eeb15235dfbdcb759fd512a705caea8e124af623a4640303f5e113a5c7135e9a6e94d28526b26a6fa6a', 'borrower', 'active'),
(3, 'Priya Patel', 'priya.patel@example.com', '+91 9822233445', 'scrypt:32768:8:1$oe0AhsTKXhLJmxgF$070573b3c621d647469e59002bcca0a0c53d310f222a7eeb15235dfbdcb759fd512a705caea8e124af623a4640303f5e113a5c7135e9a6e94d28526b26a6fa6a', 'borrower', 'active'),
(4, 'Amit Verma', 'amit.verma@example.com', '+91 9833344556', 'scrypt:32768:8:1$oe0AhsTKXhLJmxgF$070573b3c621d647469e59002bcca0a0c53d310f222a7eeb15235dfbdcb759fd512a705caea8e124af623a4640303f5e113a5c7135e9a6e94d28526b26a6fa6a', 'borrower', 'active'),
(5, 'Sneha Reddy', 'sneha.reddy@example.com', '+91 9844455667', 'scrypt:32768:8:1$oe0AhsTKXhLJmxgF$070573b3c621d647469e59002bcca0a0c53d310f222a7eeb15235dfbdcb759fd512a705caea8e124af623a4640303f5e113a5c7135e9a6e94d28526b26a6fa6a', 'borrower', 'active'),
(6, 'Vikram Singh', 'vikram.singh@example.com', '+91 9855566778', 'scrypt:32768:8:1$oe0AhsTKXhLJmxgF$070573b3c621d647469e59002bcca0a0c53d310f222a7eeb15235dfbdcb759fd512a705caea8e124af623a4640303f5e113a5c7135e9a6e94d28526b26a6fa6a', 'borrower', 'active'),
(7, 'Arun Mehta', 'arun.mehta@example.com', '+91 9866677889', 'scrypt:32768:8:1$oe0AhsTKXhLJmxgF$070573b3c621d647469e59002bcca0a0c53d310f222a7eeb15235dfbdcb759fd512a705caea8e124af623a4640303f5e113a5c7135e9a6e94d28526b26a6fa6a', 'lender', 'active'),
(8, 'Neha Gupta', 'neha.gupta@example.com', '+91 9877788990', 'scrypt:32768:8:1$oe0AhsTKXhLJmxgF$070573b3c621d647469e59002bcca0a0c53d310f222a7eeb15235dfbdcb759fd512a705caea8e124af623a4640303f5e113a5c7135e9a6e94d28526b26a6fa6a', 'lender', 'active'),
(9, 'Karan Johal', 'karan.johal@example.com', '+91 9888899001', 'scrypt:32768:8:1$oe0AhsTKXhLJmxgF$070573b3c621d647469e59002bcca0a0c53d310f222a7eeb15235dfbdcb759fd512a705caea8e124af623a4640303f5e113a5c7135e9a6e94d28526b26a6fa6a', 'lender', 'active'),
(10, 'Pooja Nair', 'pooja.nair@example.com', '+91 9899900112', 'scrypt:32768:8:1$oe0AhsTKXhLJmxgF$070573b3c621d647469e59002bcca0a0c53d310f222a7eeb15235dfbdcb759fd512a705caea8e124af623a4640303f5e113a5c7135e9a6e94d28526b26a6fa6a', 'lender', 'active'),
(11, 'Rohit Malhotra', 'rohit.malhotra@example.com', '+91 9812345678', 'scrypt:32768:8:1$oe0AhsTKXhLJmxgF$070573b3c621d647469e59002bcca0a0c53d310f222a7eeb15235dfbdcb759fd512a705caea8e124af623a4640303f5e113a5c7135e9a6e94d28526b26a6fa6a', 'lender', 'active');

-- 2. Update Borrower Profiles
UPDATE borrower_profiles SET annual_income = 850000.00, employment_status = 'Salaried', credit_score = 760, risk_category = 'Low', address = '402, Green Glen Heights, Bengaluru' WHERE user_id = 2;
UPDATE borrower_profiles SET annual_income = 600000.00, employment_status = 'Salaried', credit_score = 710, risk_category = 'Moderate', address = 'B-12, Sunshine Towers, Ahmedabad' WHERE user_id = 3;
UPDATE borrower_profiles SET annual_income = 420000.00, employment_status = 'Business', credit_score = 580, risk_category = 'High', address = '78, Chandni Chowk, Delhi' WHERE user_id = 4;
UPDATE borrower_profiles SET annual_income = 720000.00, employment_status = 'Freelancer', credit_score = 650, risk_category = 'Moderate', address = '12, Jubilee Hills, Hyderabad' WHERE user_id = 5;
UPDATE borrower_profiles SET annual_income = 1200000.00, employment_status = 'Salaried', credit_score = 820, risk_category = 'Low', address = '22-B, Marine Drive, Mumbai' WHERE user_id = 6;

-- 3. Update Lender Profiles
UPDATE lender_profiles SET investment_limit = 2000000.00, total_invested = 150000.00, total_earned = 12500.00 WHERE user_id = 7;
UPDATE lender_profiles SET investment_limit = 1500000.00, total_invested = 100000.00, total_earned = 7800.00 WHERE user_id = 8;
UPDATE lender_profiles SET investment_limit = 2500000.00, total_invested = 200000.00, total_earned = 19400.00 WHERE user_id = 9;
UPDATE lender_profiles SET investment_limit = 500000.00, total_invested = 25000.00, total_earned = 1200.00 WHERE user_id = 10;
UPDATE lender_profiles SET investment_limit = 1000000.00, total_invested = 0.00, total_earned = 0.00 WHERE user_id = 11;

-- 4. KYC Documents
INSERT INTO kyc_documents (id, user_id, document_type, document_number, document_url, status, admin_remarks, reviewed_by, reviewed_at) VALUES
(1, 2, 'Aadhaar', 'XXXX-XXXX-4589', '/static/uploads/kyc/doc_2.pdf', 'Verified', 'All identity parameters matched with UIDAI records.', 1, '2026-09-01 10:00:00'),
(2, 3, 'PAN', 'ABCDE1234F', '/static/uploads/kyc/doc_3.pdf', 'Verified', 'PAN verification successful.', 1, '2026-09-05 11:30:00'),
(3, 4, 'Aadhaar', 'XXXX-XXXX-9912', '/static/uploads/kyc/doc_4.pdf', 'Verified', 'Documents valid.', 1, '2026-09-10 14:15:00'),
(4, 5, 'Passport', 'Z1234567', '/static/uploads/kyc/doc_5.pdf', 'Pending', NULL, NULL, NULL),
(5, 6, 'Aadhaar', 'XXXX-XXXX-6677', '/static/uploads/kyc/doc_6.pdf', 'Verified', 'High grade KYC verified.', 1, '2026-08-15 09:45:00'),
(6, 7, 'PAN', 'FGHIJ5678K', '/static/uploads/kyc/doc_7.pdf', 'Verified', 'Investor KYC verified.', 1, '2026-08-10 12:00:00'),
(7, 8, 'Aadhaar', 'XXXX-XXXX-3344', '/static/uploads/kyc/doc_8.pdf', 'Verified', 'Investor KYC approved.', 1, '2026-08-12 16:30:00'),
(8, 9, 'Passport', 'M9876543', '/static/uploads/kyc/doc_9.pdf', 'Verified', 'Accredited lender verified.', 1, '2026-08-14 15:20:00'),
(9, 10, 'Driving License', 'DL-0420110012345', '/static/uploads/kyc/doc_10.pdf', 'Verified', 'Verified successfully.', 1, '2026-09-20 17:00:00'),
(10, 11, 'PAN', 'KLMNO9988P', '/static/uploads/kyc/doc_11.pdf', 'Pending', NULL, NULL, NULL);

-- 5. Set Initial Wallet Balances
UPDATE wallets SET balance = 15000.00 WHERE user_id = 2; -- Borrower Rahul
UPDATE wallets SET balance = 2500.00 WHERE user_id = 3;  -- Borrower Priya
UPDATE wallets SET balance = 800.00 WHERE user_id = 4;   -- Borrower Amit (low balance)
UPDATE wallets SET balance = 5000.00 WHERE user_id = 5;  -- Borrower Sneha
UPDATE wallets SET balance = 85000.00 WHERE user_id = 6; -- Borrower Vikram
UPDATE wallets SET balance = 245000.00 WHERE user_id = 7; -- Lender Arun
UPDATE wallets SET balance = 182000.00 WHERE user_id = 8; -- Lender Neha
UPDATE wallets SET balance = 310000.00 WHERE user_id = 9; -- Lender Karan
UPDATE wallets SET balance = 48000.00 WHERE user_id = 10; -- Lender Pooja
UPDATE wallets SET balance = 50000.00 WHERE user_id = 11; -- Lender Rohit

-- 6. Insert Historical Transactions for Initial Deposits
INSERT INTO transactions (wallet_id, amount, type, direction, reference_id, balance_after, description, created_at)
SELECT w.id, w.balance, 'Deposit', 'Credit', 'TX-INIT-DEP', w.balance, 'Initial account deposit via NetBanking simulation', '2026-09-01 10:00:00'
FROM wallets w WHERE w.balance > 0;

-- 7. Insert Loan Requests
-- Loan Request 1: Closed & fully repaid (Vikram Singh)
INSERT INTO loan_requests (id, borrower_id, title, purpose, requested_amount, interest_rate, tenure_months, funded_amount, status, created_at)
VALUES (1, 6, 'Home Renovation Loan', 'Living room and modular kitchen renovation', 100000.00, 11.50, 6, 100000.00, 'Closed', '2026-03-01 10:00:00');

-- Loan Request 2: Active funded loan (Rahul Sharma)
INSERT INTO loan_requests (id, borrower_id, title, purpose, requested_amount, interest_rate, tenure_months, funded_amount, status, created_at)
VALUES (2, 2, 'Professional Tech Upskilling', 'Tuition fee for Advanced Cloud & DevOps Certification', 50000.00, 12.00, 6, 50000.00, 'Funded', '2026-08-01 14:00:00');

-- Loan Request 3: Active funded loan with Overdue installment (Amit Verma)
INSERT INTO loan_requests (id, borrower_id, title, purpose, requested_amount, interest_rate, tenure_months, funded_amount, status, created_at)
VALUES (3, 4, 'Small Business Working Capital', 'Restocking retail inventory ahead of festive season', 60000.00, 14.50, 6, 60000.00, 'Funded', '2026-07-15 11:30:00');

-- Loan Request 4: Open Marketplace request (Priya Patel, partially funded)
INSERT INTO loan_requests (id, borrower_id, title, purpose, requested_amount, interest_rate, tenure_months, funded_amount, status, created_at)
VALUES (4, 3, 'Medical Equipment & Family Health', 'Hospitalization medical bills and post-op care equipment', 80000.00, 10.50, 12, 35000.00, 'Open', '2026-10-15 09:30:00');

-- Loan Request 5: Open Marketplace request (Rahul Sharma, open fresh)
INSERT INTO loan_requests (id, borrower_id, title, purpose, requested_amount, interest_rate, tenure_months, funded_amount, status, created_at)
VALUES (5, 2, 'Laptop & Workstation Upgrade', 'High performance developer workstation for freelance projects', 45000.00, 11.00, 6, 0.00, 'Open', '2026-10-20 16:45:00');

-- 8. Investments
-- For Request 1 (Vikram - 100,000)
INSERT INTO investments (id, loan_request_id, lender_id, amount, funded_at) VALUES
(1, 1, 7, 50000.00, '2026-03-02 11:00:00'),
(2, 1, 9, 50000.00, '2026-03-02 15:30:00');

-- For Request 2 (Rahul - 50,000)
INSERT INTO investments (id, loan_request_id, lender_id, amount, funded_at) VALUES
(3, 2, 7, 25000.00, '2026-08-02 10:30:00'),
(4, 2, 8, 25000.00, '2026-08-02 14:15:00');

-- For Request 3 (Amit - 60,000)
INSERT INTO investments (id, loan_request_id, lender_id, amount, funded_at) VALUES
(5, 3, 9, 40000.00, '2026-07-16 12:00:00'),
(6, 3, 10, 20000.00, '2026-07-16 16:45:00');

-- For Request 4 (Priya - 35,000 partial funded)
INSERT INTO investments (id, loan_request_id, lender_id, amount, funded_at) VALUES
(7, 4, 8, 20000.00, '2026-10-16 10:00:00'),
(8, 4, 7, 15000.00, '2026-10-17 11:20:00');

-- 9. Loans
-- Loan 1 (Completed)
INSERT INTO loans (id, loan_request_id, borrower_id, principal_amount, interest_rate, tenure_months, monthly_emi, total_repayable, status, start_date, end_date, created_at)
VALUES (1, 1, 6, 100000.00, 11.50, 6, 17232.00, 103392.00, 'Completed', '2026-03-03', '2026-09-03', '2026-03-03 16:00:00');

-- Loan 2 (Active - on track)
INSERT INTO loans (id, loan_request_id, borrower_id, principal_amount, interest_rate, tenure_months, monthly_emi, total_repayable, status, start_date, end_date, created_at)
VALUES (2, 2, 2, 50000.00, 12.00, 6, 8627.00, 51762.00, 'Active', '2026-08-03', '2027-02-03', '2026-08-03 15:00:00');

-- Loan 3 (Active - with overdue installment)
INSERT INTO loans (id, loan_request_id, borrower_id, principal_amount, interest_rate, tenure_months, monthly_emi, total_repayable, status, start_date, end_date, created_at)
VALUES (3, 3, 4, 60000.00, 14.50, 6, 10430.00, 62580.00, 'Active', '2026-07-17', '2027-01-17', '2026-07-17 17:00:00');

-- 10. Generate EMI Schedules for existing loans
-- Schedule for Loan 1 (All 6 Paid)
INSERT INTO repayment_schedules (loan_id, installment_number, due_date, principal_component, interest_component, emi_amount, penalty_amount, status, paid_at) VALUES
(1, 1, '2026-04-03', 16273.67, 958.33, 17232.00, 0.00, 'Paid', '2026-04-02 11:20:00'),
(1, 2, '2026-05-03', 16429.62, 802.38, 17232.00, 0.00, 'Paid', '2026-05-01 10:15:00'),
(1, 3, '2026-06-03', 16587.07, 644.93, 17232.00, 0.00, 'Paid', '2026-06-03 14:00:00'),
(1, 4, '2026-07-03', 16746.03, 485.97, 17232.00, 0.00, 'Paid', '2026-07-02 09:30:00'),
(1, 5, '2026-08-03', 16906.51, 325.49, 17232.00, 0.00, 'Paid', '2026-08-01 16:40:00'),
(1, 6, '2026-09-03', 17057.10, 163.63, 17220.73, 0.00, 'Paid', '2026-09-03 12:00:00');

-- Schedule for Loan 2 (Rahul - 2 Paid on time, 4 Pending)
INSERT INTO repayment_schedules (loan_id, installment_number, due_date, principal_component, interest_component, emi_amount, penalty_amount, status, paid_at) VALUES
(2, 1, '2026-09-03', 8127.00, 500.00, 8627.00, 0.00, 'Paid', '2026-09-02 10:00:00'),
(2, 2, '2026-10-03', 8208.27, 418.73, 8627.00, 0.00, 'Paid', '2026-10-01 15:30:00'),
(2, 3, '2026-11-03', 8290.35, 336.65, 8627.00, 0.00, 'Pending', NULL),
(2, 4, '2026-12-03', 8373.26, 253.74, 8627.00, 0.00, 'Pending', NULL),
(2, 5, '2027-01-03', 8456.99, 170.01, 8627.00, 0.00, 'Pending', NULL),
(2, 6, '2027-02-03', 8544.13, 85.44, 8629.57, 0.00, 'Pending', NULL);

-- Schedule for Loan 3 (Amit - 1 Paid, 2 Overdue with penalty, 3 Pending)
INSERT INTO repayment_schedules (loan_id, installment_number, due_date, principal_component, interest_component, emi_amount, penalty_amount, status, paid_at) VALUES
(3, 1, '2026-08-17', 9705.00, 725.00, 10430.00, 0.00, 'Paid', '2026-08-16 11:00:00'),
(3, 2, '2026-09-17', 9822.27, 607.73, 10430.00, 208.60, 'Overdue', NULL),
(3, 3, '2026-10-17', 9940.96, 489.04, 10430.00, 208.60, 'Overdue', NULL),
(3, 4, '2026-11-17', 10061.08, 368.92, 10430.00, 0.00, 'Pending', NULL),
(3, 5, '2026-12-17', 10182.65, 247.35, 10430.00, 0.00, 'Pending', NULL),
(3, 6, '2027-01-17', 10288.04, 124.32, 10412.36, 0.00, 'Pending', NULL);

-- 11. Credit Score History
INSERT INTO credit_score_histories (borrower_id, previous_score, new_score, change_reason, changed_at) VALUES
(6, 750, 780, 'Consecutive on-time EMI repayments for Loan #1', '2026-06-03 14:05:00'),
(6, 780, 820, 'Loan #1 fully repaid without any default', '2026-09-03 12:05:00'),
(2, 640, 650, 'Account verification and KYC verified', '2026-09-01 10:05:00'),
(2, 650, 760, 'Timely payments on Loan #2 (Installments 1 and 2)', '2026-10-01 15:35:00'),
(4, 630, 580, 'Missed scheduled EMI payment on September 17 and October 17', '2026-10-18 00:05:00');

-- 12. Risk Flags
INSERT INTO risk_flags (user_id, loan_request_id, flag_type, severity, description, status, created_at) VALUES
(4, 3, 'MULTIPLE_OVERDUE_EMIS', 'High', 'Borrower has 2 consecutive overdue installments on Loan #3 with zero payment attempts.', 'Open', '2026-10-18 01:00:00');

-- 13. Populate Initial Materialized Platform Metrics
CALL sp_refresh_platform_metrics();
