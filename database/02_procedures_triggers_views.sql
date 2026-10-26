-- =====================================================================
-- P2P Lending Platform: Stored Functions, Procedures, Triggers & Views
-- =====================================================================

USE p2p_lending_db;

-- ---------------------------------------------------------------------
-- 1. STORED FUNCTIONS
-- ---------------------------------------------------------------------

DROP FUNCTION IF EXISTS fn_calculate_emi;
DELIMITER $$
CREATE FUNCTION fn_calculate_emi(
    p_principal DECIMAL(12,2),
    p_annual_rate DECIMAL(5,2),
    p_tenure_months INT
) RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_monthly_rate DOUBLE;
    DECLARE v_emi DOUBLE;
    DECLARE v_factor DOUBLE;

    IF p_tenure_months <= 0 OR p_principal <= 0 THEN
        RETURN 0.00;
    END IF;

    IF p_annual_rate = 0.00 THEN
        RETURN ROUND(p_principal / p_tenure_months, 2);
    END IF;

    SET v_monthly_rate = (p_annual_rate / 12.0) / 100.0;
    SET v_factor = POW(1.0 + v_monthly_rate, p_tenure_months);
    SET v_emi = (p_principal * v_monthly_rate * v_factor) / (v_factor - 1.0);

    RETURN ROUND(v_emi, 2);
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_calculate_lender_returns;
DELIMITER $$
CREATE FUNCTION fn_calculate_lender_returns(p_lender_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total_earned DECIMAL(12,2);
    SELECT COALESCE(SUM(amount), 0.00) INTO v_total_earned
    FROM transactions t
    JOIN wallets w ON t.wallet_id = w.id
    WHERE w.user_id = p_lender_id AND t.type = 'Repayment Received';
    RETURN v_total_earned;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- 2. STORED PROCEDURES
-- ---------------------------------------------------------------------

-- Procedure: Generate complete EMI Amortization Schedule for a Loan
DROP PROCEDURE IF EXISTS sp_generate_emi_schedule;
DELIMITER $$
CREATE PROCEDURE sp_generate_emi_schedule(IN p_loan_id INT)
BEGIN
    DECLARE v_principal DECIMAL(12,2);
    DECLARE v_rate DECIMAL(5,2);
    DECLARE v_tenure INT;
    DECLARE v_emi DECIMAL(12,2);
    DECLARE v_monthly_rate DOUBLE;
    DECLARE v_start_date DATE;
    DECLARE v_remaining_balance DECIMAL(12,2);
    DECLARE v_interest_comp DECIMAL(12,2);
    DECLARE v_principal_comp DECIMAL(12,2);
    DECLARE i INT DEFAULT 1;
    DECLARE v_due_date DATE;

    SELECT principal_amount, interest_rate, tenure_months, monthly_emi, start_date
    INTO v_principal, v_rate, v_tenure, v_emi, v_start_date
    FROM loans WHERE id = p_loan_id;

    SET v_remaining_balance = v_principal;
    SET v_monthly_rate = (v_rate / 12.0) / 100.0;

    -- Clean any existing schedule if regenerating
    DELETE FROM repayment_schedules WHERE loan_id = p_loan_id;

    WHILE i <= v_tenure DO
        SET v_due_date = DATE_ADD(v_start_date, INTERVAL i MONTH);
        SET v_interest_comp = ROUND(v_remaining_balance * v_monthly_rate, 2);

        IF i = v_tenure THEN
            SET v_principal_comp = v_remaining_balance;
            SET v_emi = v_principal_comp + v_interest_comp;
        ELSE
            SET v_principal_comp = v_emi - v_interest_comp;
            IF v_principal_comp > v_remaining_balance THEN
                SET v_principal_comp = v_remaining_balance;
            END IF;
        END IF;

        INSERT INTO repayment_schedules (
            loan_id, installment_number, due_date, principal_component,
            interest_component, emi_amount, penalty_amount, status
        ) VALUES (
            p_loan_id, i, v_due_date, v_principal_comp,
            v_interest_comp, v_emi, 0.00, 'Pending'
        );

        SET v_remaining_balance = v_remaining_balance - v_principal_comp;
        SET i = i + 1;
    END WHILE;
END$$
DELIMITER ;

-- Procedure: Lender funds a loan request with atomic transactions and automatic loan creation
DROP PROCEDURE IF EXISTS sp_fund_loan_request;
DELIMITER $$
CREATE PROCEDURE sp_fund_loan_request(
    IN p_request_id INT,
    IN p_lender_id INT,
    IN p_amount DECIMAL(12,2),
    OUT p_status VARCHAR(20),
    OUT p_message VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_req_status VARCHAR(20);
    DECLARE v_req_amount DECIMAL(12,2);
    DECLARE v_curr_funded DECIMAL(12,2);
    DECLARE v_borrower_id INT;
    DECLARE v_rate DECIMAL(5,2);
    DECLARE v_tenure INT;
    DECLARE v_needed DECIMAL(12,2);
    DECLARE v_lender_bal DECIMAL(15,2);
    DECLARE v_lender_wallet_id INT;
    DECLARE v_borrower_wallet_id INT;
    DECLARE v_new_loan_id INT;
    DECLARE v_monthly_emi DECIMAL(12,2);
    DECLARE v_total_repayable DECIMAL(12,2);

    -- Check lender KYC status
    DECLARE v_lender_kyc VARCHAR(20);
    SELECT status INTO v_lender_kyc FROM kyc_documents WHERE user_id = p_lender_id ORDER BY id DESC LIMIT 1;
    IF v_lender_kyc IS NULL OR v_lender_kyc != 'Verified' THEN
        SET p_status = 'ERROR';
        SET p_message = 'Lender KYC is not verified. Please complete KYC verification before investing.';
        LEAVE proc_label;
    END IF;

    -- Fetch and lock loan request
    SELECT status, requested_amount, funded_amount, borrower_id, interest_rate, tenure_months
    INTO v_req_status, v_req_amount, v_curr_funded, v_borrower_id, v_rate, v_tenure
    FROM loan_requests
    WHERE id = p_request_id FOR UPDATE;

    IF v_req_status IS NULL THEN
        SET p_status = 'ERROR';
        SET p_message = 'Loan request does not exist.';
        LEAVE proc_label;
    END IF;

    IF v_req_status != 'Open' THEN
        SET p_status = 'ERROR';
        SET p_message = 'Loan request is no longer accepting investments.';
        LEAVE proc_label;
    END IF;

    IF v_borrower_id = p_lender_id THEN
        SET p_status = 'ERROR';
        SET p_message = 'Borrower cannot invest in their own loan request.';
        LEAVE proc_label;
    END IF;

    SET v_needed = v_req_amount - v_curr_funded;
    IF p_amount <= 0 OR p_amount > v_needed THEN
        SET p_status = 'ERROR';
        SET p_message = CONCAT('Invalid amount. Maximum investment allowed is ₹', FORMAT(v_needed, 2));
        LEAVE proc_label;
    END IF;

    -- Check lender wallet balance and lock wallet
    SELECT id, balance INTO v_lender_wallet_id, v_lender_bal
    FROM wallets
    WHERE user_id = p_lender_id FOR UPDATE;

    IF v_lender_bal < p_amount THEN
        SET p_status = 'ERROR';
        SET p_message = 'Insufficient wallet balance to complete this investment.';
        LEAVE proc_label;
    END IF;

    -- 1. Deduct funds from lender wallet
    UPDATE wallets SET balance = balance - p_amount WHERE id = v_lender_wallet_id;
    INSERT INTO transactions (wallet_id, amount, type, direction, reference_id, balance_after, description)
    VALUES (v_lender_wallet_id, p_amount, 'Investment', 'Debit', CONCAT('REQ-', p_request_id), v_lender_bal - p_amount, CONCAT('Investment in Loan Request #', p_request_id));

    -- 2. Update lender profile total_invested
    UPDATE lender_profiles SET total_invested = total_invested + p_amount WHERE user_id = p_lender_id;

    -- 3. Record investment record
    INSERT INTO investments (loan_request_id, lender_id, amount)
    VALUES (p_request_id, p_lender_id, p_amount);

    -- 4. Update funded amount on loan request
    UPDATE loan_requests SET funded_amount = funded_amount + p_amount WHERE id = p_request_id;
    SET v_curr_funded = v_curr_funded + p_amount;

    -- 5. If fully funded, create Loan, disburse amount to borrower, and generate EMI schedule
    IF v_curr_funded >= v_req_amount THEN
        UPDATE loan_requests SET status = 'Funded' WHERE id = p_request_id;

        SET v_monthly_emi = fn_calculate_emi(v_req_amount, v_rate, v_tenure);
        SET v_total_repayable = v_monthly_emi * v_tenure;

        INSERT INTO loans (
            loan_request_id, borrower_id, principal_amount, interest_rate,
            tenure_months, monthly_emi, total_repayable, status, start_date, end_date
        ) VALUES (
            p_request_id, v_borrower_id, v_req_amount, v_rate,
            v_tenure, v_monthly_emi, v_total_repayable, 'Active', CURDATE(), DATE_ADD(CURDATE(), INTERVAL v_tenure MONTH)
        );
        SET v_new_loan_id = LAST_INSERT_ID();

        -- Disburse funds to borrower wallet
        SELECT id, balance INTO v_borrower_wallet_id, v_lender_bal FROM wallets WHERE user_id = v_borrower_id FOR UPDATE;
        UPDATE wallets SET balance = balance + v_req_amount WHERE id = v_borrower_wallet_id;
        INSERT INTO transactions (wallet_id, amount, type, direction, reference_id, balance_after, description)
        VALUES (v_borrower_wallet_id, v_req_amount, 'Disbursement', 'Credit', CONCAT('LOAN-', v_new_loan_id), v_lender_bal + v_req_amount, CONCAT('Loan Disbursement for Loan #', v_new_loan_id));

        -- Generate Amortization Schedule
        CALL sp_generate_emi_schedule(v_new_loan_id);

        SET p_status = 'SUCCESS_FUNDED';
        SET p_message = 'Investment successful! Loan request is now 100% funded and disbursed.';
    ELSE
        SET p_status = 'SUCCESS_PARTIAL';
        SET p_message = CONCAT('Investment of ₹', FORMAT(p_amount, 2), ' recorded successfully.');
    END IF;

END$$
DELIMITER ;

-- Procedure: Pay EMI installment with proportional distribution to fractional lenders
DROP PROCEDURE IF EXISTS sp_pay_emi_installment;
DELIMITER $$
CREATE PROCEDURE sp_pay_emi_installment(
    IN p_schedule_id INT,
    IN p_borrower_id INT,
    OUT p_status VARCHAR(20),
    OUT p_message VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_loan_id INT;
    DECLARE v_installment_no INT;
    DECLARE v_due_date DATE;
    DECLARE v_emi_amount DECIMAL(12,2);
    DECLARE v_penalty DECIMAL(12,2);
    DECLARE v_total_due DECIMAL(12,2);
    DECLARE v_sched_status VARCHAR(20);
    DECLARE v_loan_borrower_id INT;
    DECLARE v_principal_amount DECIMAL(12,2);
    DECLARE v_borrower_wallet_id INT;
    DECLARE v_borrower_bal DECIMAL(15,2);
    DECLARE v_req_id INT;

    -- Proportional distribution variables
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_lender_id INT;
    DECLARE v_inv_amount DECIMAL(12,2);
    DECLARE v_lender_share DECIMAL(12,2);
    DECLARE v_lender_wallet_id INT;
    DECLARE v_lender_bal DECIMAL(15,2);

    DECLARE cur_lenders CURSOR FOR
        SELECT lender_id, amount FROM investments WHERE loan_request_id = v_req_id;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- Lock schedule
    SELECT s.loan_id, s.installment_number, s.due_date, s.emi_amount, s.penalty_amount, s.status,
           l.borrower_id, l.principal_amount, l.loan_request_id
    INTO v_loan_id, v_installment_no, v_due_date, v_emi_amount, v_penalty, v_sched_status,
         v_loan_borrower_id, v_principal_amount, v_req_id
    FROM repayment_schedules s
    JOIN loans l ON s.loan_id = l.id
    WHERE s.id = p_schedule_id FOR UPDATE;

    IF v_loan_id IS NULL THEN
        SET p_status = 'ERROR';
        SET p_message = 'Installment schedule row not found.';
        LEAVE proc_label;
    END IF;

    IF v_loan_borrower_id != p_borrower_id THEN
        SET p_status = 'ERROR';
        SET p_message = 'Unauthorized: this loan does not belong to you.';
        LEAVE proc_label;
    END IF;

    IF v_sched_status = 'Paid' THEN
        SET p_status = 'ERROR';
        SET p_message = 'This installment has already been paid.';
        LEAVE proc_label;
    END IF;

    SET v_total_due = v_emi_amount + v_penalty;

    -- Check borrower wallet
    SELECT id, balance INTO v_borrower_wallet_id, v_borrower_bal
    FROM wallets WHERE user_id = p_borrower_id FOR UPDATE;

    IF v_borrower_bal < v_total_due THEN
        SET p_status = 'ERROR';
        SET p_message = CONCAT('Insufficient wallet balance. Total due is ₹', FORMAT(v_total_due, 2));
        LEAVE proc_label;
    END IF;

    -- 1. Deduct EMI from borrower wallet
    UPDATE wallets SET balance = balance - v_total_due WHERE id = v_borrower_wallet_id;
    INSERT INTO transactions (wallet_id, amount, type, direction, reference_id, balance_after, description)
    VALUES (v_borrower_wallet_id, v_total_due, 'EMI Payment', 'Debit', CONCAT('SCHED-', p_schedule_id), v_borrower_bal - v_total_due, CONCAT('EMI Payment for Loan #', v_loan_id, ' (Instalment #', v_installment_no, ')'));

    -- 2. Mark installment as Paid
    UPDATE repayment_schedules SET status = 'Paid', paid_at = CURRENT_TIMESTAMP WHERE id = p_schedule_id;

    -- 3. Proportional distribution to each investor
    OPEN cur_lenders;
    read_loop: LOOP
        FETCH cur_lenders INTO v_lender_id, v_inv_amount;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SET v_lender_share = ROUND((v_inv_amount / v_principal_amount) * v_total_due, 2);

        -- Credit lender wallet
        SELECT id, balance INTO v_lender_wallet_id, v_lender_bal FROM wallets WHERE user_id = v_lender_id FOR UPDATE;
        UPDATE wallets SET balance = balance + v_lender_share WHERE id = v_lender_wallet_id;
        UPDATE lender_profiles SET total_earned = total_earned + v_lender_share WHERE user_id = v_lender_id;

        INSERT INTO transactions (wallet_id, amount, type, direction, reference_id, balance_after, description)
        VALUES (v_lender_wallet_id, v_lender_share, 'Repayment Received', 'Credit', CONCAT('SCHED-', p_schedule_id), v_lender_bal + v_lender_share, CONCAT('Repayment received for Loan #', v_loan_id, ' (Instalment #', v_installment_no, ')'));
    END LOOP;
    CLOSE cur_lenders;

    -- 4. Credit Score boost (+10 points for on-time payment, +5 if was overdue)
    IF v_sched_status = 'Overdue' THEN
        UPDATE borrower_profiles
        SET credit_score = LEAST(900, credit_score + 5)
        WHERE user_id = p_borrower_id;
        INSERT INTO credit_score_histories (borrower_id, previous_score, new_score, change_reason)
        SELECT user_id, credit_score - 5, credit_score, CONCAT('Paid overdue EMI for Loan #', v_loan_id)
        FROM borrower_profiles WHERE user_id = p_borrower_id;
    ELSE
        UPDATE borrower_profiles
        SET credit_score = LEAST(900, credit_score + 10)
        WHERE user_id = p_borrower_id;
        INSERT INTO credit_score_histories (borrower_id, previous_score, new_score, change_reason)
        SELECT user_id, credit_score - 10, credit_score, CONCAT('On-time EMI payment for Loan #', v_loan_id)
        FROM borrower_profiles WHERE user_id = p_borrower_id;
    END IF;

    -- 5. Check if all installments for this loan are now paid
    IF (SELECT COUNT(*) FROM repayment_schedules WHERE loan_id = v_loan_id AND status != 'Paid') = 0 THEN
        UPDATE loans SET status = 'Completed' WHERE id = v_loan_id;
        UPDATE loan_requests SET status = 'Closed' WHERE id = v_req_id;
    END IF;

    SET p_status = 'SUCCESS';
    SET p_message = 'EMI payment processed successfully and distributed to lenders.';
END$$
DELIMITER ;

-- Procedure: Cancel an open loan request with atomic refund to any partial fractional backers
DROP PROCEDURE IF EXISTS sp_cancel_loan_request;
DELIMITER $$
CREATE PROCEDURE sp_cancel_loan_request(
    IN p_request_id INT,
    IN p_user_id INT,
    OUT p_status VARCHAR(20),
    OUT p_message VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_borrower_id INT;
    DECLARE v_status VARCHAR(20);
    DECLARE v_user_role VARCHAR(20);
    DECLARE v_funded DECIMAL(12,2);
    
    -- Refund cursor variables
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_lender_id INT;
    DECLARE v_inv_amount DECIMAL(12,2);
    DECLARE v_lender_wallet_id INT;
    DECLARE v_lender_bal DECIMAL(15,2);

    DECLARE cur_refund CURSOR FOR
        SELECT lender_id, amount FROM investments WHERE loan_request_id = p_request_id;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- Fetch user role
    SELECT role INTO v_user_role FROM users WHERE id = p_user_id;

    -- Lock and check loan request
    SELECT borrower_id, status, funded_amount
    INTO v_borrower_id, v_status, v_funded
    FROM loan_requests
    WHERE id = p_request_id FOR UPDATE;

    IF v_status IS NULL THEN
        SET p_status = 'ERROR';
        SET p_message = 'Loan request not found.';
        LEAVE proc_label;
    END IF;

    -- Only borrower who created it or admin can cancel
    IF v_borrower_id != p_user_id AND (v_user_role IS NULL OR v_user_role != 'admin') THEN
        SET p_status = 'ERROR';
        SET p_message = 'Unauthorized: You can only cancel your own loan request.';
        LEAVE proc_label;
    END IF;

    IF v_status != 'Open' THEN
        IF v_status = 'Funded' OR v_status = 'Closed' THEN
            SET p_status = 'ERROR';
            SET p_message = 'Cannot cancel a loan that is already funded or closed. Disbursed loans must be repaid.';
        ELSE
            SET p_status = 'ERROR';
            SET p_message = CONCAT('Cannot cancel loan request with status: ', v_status);
        END IF;
        LEAVE proc_label;
    END IF;

    -- If there were any partial investments, refund every lender
    OPEN cur_refund;
    refund_loop: LOOP
        FETCH cur_refund INTO v_lender_id, v_inv_amount;
        IF done THEN
            LEAVE refund_loop;
        END IF;

        -- Credit lender wallet
        SELECT id, balance INTO v_lender_wallet_id, v_lender_bal FROM wallets WHERE user_id = v_lender_id FOR UPDATE;
        UPDATE wallets SET balance = balance + v_inv_amount WHERE id = v_lender_wallet_id;
        UPDATE lender_profiles SET total_invested = GREATEST(0.00, total_invested - v_inv_amount) WHERE user_id = v_lender_id;

        INSERT INTO transactions (wallet_id, amount, type, direction, reference_id, balance_after, description)
        VALUES (v_lender_wallet_id, v_inv_amount, 'Deposit', 'Credit', CONCAT('REFUND-REQ-', p_request_id), v_lender_bal + v_inv_amount, CONCAT('Refund for cancelled Loan Request #', p_request_id));
    END LOOP;
    CLOSE cur_refund;

    -- Mark loan request as Cancelled
    UPDATE loan_requests SET status = 'Cancelled' WHERE id = p_request_id;

    SET p_status = 'SUCCESS';
    SET p_message = 'Loan request has been cancelled successfully. Any invested funds have been refunded to lenders.';
END$$
DELIMITER ;

-- Procedure: Overdue detection & Penalty calculation (Run daily or on demand)
DROP PROCEDURE IF EXISTS sp_check_and_mark_overdue;
DELIMITER $$
CREATE PROCEDURE sp_check_and_mark_overdue()
BEGIN
    -- 1. Mark overdue installments and apply standard late penalty (2% of EMI)
    UPDATE repayment_schedules
    SET status = 'Overdue',
        penalty_amount = ROUND(emi_amount * 0.02, 2)
    WHERE status = 'Pending' AND due_date < CURDATE();

    -- 2. Deduct credit score for borrowers with new overdue installments
    -- (-25 points for overdue installment)
    UPDATE borrower_profiles bp
    JOIN loans l ON l.borrower_id = bp.user_id
    JOIN repayment_schedules s ON s.loan_id = l.id
    SET bp.credit_score = GREATEST(300, bp.credit_score - 25)
    WHERE s.status = 'Overdue' AND s.paid_at IS NULL AND s.due_date = DATE_SUB(CURDATE(), INTERVAL 1 DAY);

    -- 3. Trigger Risk Flags for borrowers with 2+ overdue installments
    INSERT INTO risk_flags (user_id, loan_request_id, flag_type, severity, description, status)
    SELECT l.borrower_id, l.loan_request_id, 'MULTIPLE_OVERDUE_EMIS', 'High',
           CONCAT('Borrower has ', COUNT(*), ' overdue installments on Loan #', l.id), 'Open'
    FROM repayment_schedules s
    JOIN loans l ON s.loan_id = l.id
    WHERE s.status = 'Overdue'
    GROUP BY l.borrower_id, l.loan_request_id, l.id
    HAVING COUNT(*) >= 2
    AND NOT EXISTS (
        SELECT 1 FROM risk_flags rf
        WHERE rf.user_id = l.borrower_id
          AND rf.flag_type = 'MULTIPLE_OVERDUE_EMIS'
          AND rf.status = 'Open'
    );
END$$
DELIMITER ;

-- Procedure: Refresh materialized platform metrics summary
DROP PROCEDURE IF EXISTS sp_refresh_platform_metrics;
DELIMITER $$
CREATE PROCEDURE sp_refresh_platform_metrics()
BEGIN
    DECLARE v_users INT;
    DECLARE v_borrowers INT;
    DECLARE v_lenders INT;
    DECLARE v_active_loans INT;
    DECLARE v_disbursed DECIMAL(15,2);
    DECLARE v_repaid DECIMAL(15,2);
    DECLARE v_defaulted DECIMAL(15,2);
    DECLARE v_overdue_count INT;
    DECLARE v_risk_flags INT;

    SELECT COUNT(*) INTO v_users FROM users;
    SELECT COUNT(*) INTO v_borrowers FROM users WHERE role = 'borrower';
    SELECT COUNT(*) INTO v_lenders FROM users WHERE role = 'lender';
    SELECT COUNT(*) INTO v_active_loans FROM loans WHERE status = 'Active';
    SELECT COALESCE(SUM(principal_amount), 0.00) INTO v_disbursed FROM loans;
    SELECT COALESCE(SUM(emi_amount + penalty_amount), 0.00) INTO v_repaid FROM repayment_schedules WHERE status = 'Paid';
    SELECT COALESCE(SUM(principal_amount), 0.00) INTO v_defaulted FROM loans WHERE status = 'Defaulted';
    SELECT COUNT(*) INTO v_overdue_count FROM repayment_schedules WHERE status = 'Overdue';
    SELECT COUNT(*) INTO v_risk_flags FROM risk_flags WHERE status = 'Open';

    INSERT INTO platform_metrics_daily (
        metric_date, total_users, total_borrowers, total_lenders, total_active_loans,
        total_disbursed, total_repaid, total_defaulted, total_overdue_count, open_risk_flags_count
    ) VALUES (
        CURDATE(), v_users, v_borrowers, v_lenders, v_active_loans,
        v_disbursed, v_repaid, v_defaulted, v_overdue_count, v_risk_flags
    )
    ON DUPLICATE KEY UPDATE
        total_users = v_users,
        total_borrowers = v_borrowers,
        total_lenders = v_lenders,
        total_active_loans = v_active_loans,
        total_disbursed = v_disbursed,
        total_repaid = v_repaid,
        total_defaulted = v_defaulted,
        total_overdue_count = v_overdue_count,
        open_risk_flags_count = v_risk_flags,
        updated_at = CURRENT_TIMESTAMP;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- 3. TRIGGERS
-- ---------------------------------------------------------------------

-- Trigger: Automatically create wallet & respective profile when user is created
DROP TRIGGER IF EXISTS trg_after_user_insert;
DELIMITER $$
CREATE TRIGGER trg_after_user_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    -- Create digital wallet for every registered user
    INSERT INTO wallets (user_id, balance) VALUES (NEW.id, 0.00);

    -- Create profile based on role
    IF NEW.role = 'borrower' THEN
        INSERT INTO borrower_profiles (user_id, annual_income, credit_score, risk_category)
        VALUES (NEW.id, 300000.00, 650, 'Moderate');
    ELSEIF NEW.role = 'lender' THEN
        INSERT INTO lender_profiles (user_id, investment_limit, total_invested, total_earned)
        VALUES (NEW.id, 1000000.00, 0.00, 0.00);
    END IF;
END$$
DELIMITER ;

-- Trigger: Update risk category dynamically when credit score changes
DROP TRIGGER IF EXISTS trg_before_borrower_profile_update;
DELIMITER $$
CREATE TRIGGER trg_before_borrower_profile_update
BEFORE UPDATE ON borrower_profiles
FOR EACH ROW
BEGIN
    IF NEW.credit_score >= 750 THEN
        SET NEW.risk_category = 'Low';
    ELSEIF NEW.credit_score >= 600 THEN
        SET NEW.risk_category = 'Moderate';
    ELSE
        SET NEW.risk_category = 'High';
    END IF;
END$$
DELIMITER ;

-- Trigger: Audit credit score change to credit_score_histories
DROP TRIGGER IF EXISTS trg_after_borrower_profile_update;
DELIMITER $$
CREATE TRIGGER trg_after_borrower_profile_update
AFTER UPDATE ON borrower_profiles
FOR EACH ROW
BEGIN
    IF OLD.credit_score != NEW.credit_score THEN
        INSERT INTO credit_score_histories (borrower_id, previous_score, new_score, change_reason)
        VALUES (NEW.user_id, OLD.credit_score, NEW.credit_score, 'Credit score adjusted based on repayment activity');
    END IF;
END$$
DELIMITER ;

-- Trigger: High Debt-to-Income Risk Flag on Loan Request creation
DROP TRIGGER IF EXISTS trg_after_loan_request_insert;
DELIMITER $$
CREATE TRIGGER trg_after_loan_request_insert
AFTER INSERT ON loan_requests
FOR EACH ROW
BEGIN
    DECLARE v_income DECIMAL(12,2);
    SELECT annual_income INTO v_income FROM borrower_profiles WHERE user_id = NEW.borrower_id;

    -- If requested amount is greater than 80% of annual income, flag as high debt-to-income
    IF v_income > 0 AND NEW.requested_amount > (v_income * 0.80) THEN
        INSERT INTO risk_flags (user_id, loan_request_id, flag_type, severity, description, status)
        VALUES (NEW.borrower_id, NEW.id, 'HIGH_DEBT_TO_INCOME', 'High',
                CONCAT('Requested amount (₹', FORMAT(NEW.requested_amount, 2), ') exceeds 80% of reported annual income (₹', FORMAT(v_income, 2), ')'), 'Open');
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- 4. VIEWS
-- ---------------------------------------------------------------------

-- View: Open Loan Marketplace for Lenders
CREATE OR REPLACE VIEW vw_loan_marketplace AS
SELECT
    lr.id AS request_id,
    lr.title,
    lr.purpose,
    lr.requested_amount,
    lr.interest_rate,
    lr.tenure_months,
    lr.funded_amount,
    (lr.requested_amount - lr.funded_amount) AS remaining_amount,
    ROUND((lr.funded_amount / lr.requested_amount) * 100, 1) AS funded_percent,
    lr.status,
    lr.created_at,
    u.id AS borrower_id,
    u.full_name AS borrower_name,
    bp.credit_score,
    bp.risk_category,
    bp.employment_status,
    fn_calculate_emi(lr.requested_amount, lr.interest_rate, lr.tenure_months) AS estimated_monthly_emi
FROM loan_requests lr
JOIN users u ON lr.borrower_id = u.id
JOIN borrower_profiles bp ON u.id = bp.user_id
WHERE lr.status = 'Open';

-- View: Borrower Risk Summary for Underwriting and Admins
CREATE OR REPLACE VIEW vw_borrower_risk_summary AS
SELECT
    u.id AS borrower_id,
    u.full_name,
    u.email,
    u.phone,
    u.status AS account_status,
    bp.annual_income,
    bp.employment_status,
    bp.credit_score,
    bp.risk_category,
    COUNT(DISTINCT l.id) AS total_loans_taken,
    SUM(CASE WHEN l.status = 'Active' THEN 1 ELSE 0 END) AS active_loans_count,
    COALESCE(SUM(CASE WHEN l.status = 'Active' THEN l.principal_amount ELSE 0 END), 0.00) AS total_active_debt,
    COALESCE(SUM(CASE WHEN rs.status = 'Overdue' THEN 1 ELSE 0 END), 0) AS total_overdue_installments,
    COALESCE(SUM(CASE WHEN rf.status = 'Open' THEN 1 ELSE 0 END), 0) AS open_risk_flags
FROM users u
JOIN borrower_profiles bp ON u.id = bp.user_id
LEFT JOIN loans l ON u.id = l.borrower_id
LEFT JOIN repayment_schedules rs ON l.id = rs.loan_id
LEFT JOIN risk_flags rf ON u.id = rf.user_id
WHERE u.role = 'borrower'
GROUP BY u.id, u.full_name, u.email, u.phone, u.status, bp.annual_income, bp.employment_status, bp.credit_score, bp.risk_category;

-- View: Monthly Platform Revenue & Loan Volume
CREATE OR REPLACE VIEW vw_monthly_platform_revenue AS
SELECT
    DATE_FORMAT(t.created_at, '%Y-%m') AS month_year,
    COUNT(DISTINCT t.id) AS total_transactions,
    SUM(CASE WHEN t.type = 'Disbursement' THEN t.amount ELSE 0.00 END) AS monthly_disbursed,
    SUM(CASE WHEN t.type = 'EMI Payment' THEN t.amount ELSE 0.00 END) AS monthly_repaid,
    SUM(CASE WHEN t.type = 'Penalty' THEN t.amount ELSE 0.00 END) AS total_penalties_collected,
    COUNT(DISTINCT l.id) AS new_loans_originated
FROM transactions t
LEFT JOIN wallets w ON t.wallet_id = w.id
LEFT JOIN loans l ON DATE_FORMAT(l.created_at, '%Y-%m') = DATE_FORMAT(t.created_at, '%Y-%m')
GROUP BY DATE_FORMAT(t.created_at, '%Y-%m')
ORDER BY month_year DESC;

-- View: Lender Portfolio Summary
CREATE OR REPLACE VIEW vw_lender_portfolio_summary AS
SELECT
    u.id AS lender_id,
    u.full_name AS lender_name,
    u.email,
    w.balance AS wallet_balance,
    lp.investment_limit,
    lp.total_invested,
    lp.total_earned,
    COUNT(DISTINCT inv.id) AS total_investments_made,
    COUNT(DISTINCT inv.loan_request_id) AS funded_requests_count,
    COALESCE(SUM(inv.amount), 0.00) AS live_invested_amount
FROM users u
JOIN lender_profiles lp ON u.id = lp.user_id
JOIN wallets w ON u.id = w.user_id
LEFT JOIN investments inv ON u.id = inv.lender_id
WHERE u.role = 'lender'
GROUP BY u.id, u.full_name, u.email, w.balance, lp.investment_limit, lp.total_invested, lp.total_earned;
