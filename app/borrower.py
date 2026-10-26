import os
from flask import Blueprint, render_template, request, redirect, url_for, flash, session, current_app
from app.auth import login_required, role_required
from app.db import query_db, execute_db, get_db

borrower_bp = Blueprint('borrower', __name__, url_prefix='/borrower')

@borrower_bp.route('/dashboard')
@role_required('borrower')
def dashboard():
    user_id = session['user_id']

    profile = query_db("SELECT * FROM borrower_profiles WHERE user_id = %s", (user_id,), one=True)
    wallet = query_db("SELECT * FROM wallets WHERE user_id = %s", (user_id,), one=True)
    kyc = query_db("SELECT * FROM kyc_documents WHERE user_id = %s ORDER BY id DESC LIMIT 1", (user_id,), one=True)

    # Active loans
    active_loans = query_db(
        "SELECT l.*, lr.title, lr.purpose "
        "FROM loans l "
        "JOIN loan_requests lr ON l.loan_request_id = lr.id "
        "WHERE l.borrower_id = %s AND l.status = 'Active' "
        "ORDER BY l.created_at DESC",
        (user_id,)
    )

    # Upcoming and overdue EMIs
    upcoming_emis = query_db(
        "SELECT s.*, l.id as loan_id, lr.title "
        "FROM repayment_schedules s "
        "JOIN loans l ON s.loan_id = l.id "
        "JOIN loan_requests lr ON l.loan_request_id = lr.id "
        "WHERE l.borrower_id = %s AND s.status IN ('Pending', 'Overdue') "
        "ORDER BY s.due_date ASC LIMIT 5",
        (user_id,)
    )

    # Open requests
    open_requests = query_db(
        "SELECT *, ROUND((funded_amount / requested_amount) * 100, 1) as funded_percent "
        "FROM loan_requests WHERE borrower_id = %s AND status = 'Open' ORDER BY created_at DESC",
        (user_id,)
    )

    return render_template(
        'borrower/dashboard.html',
        profile=profile,
        wallet=wallet,
        kyc=kyc,
        active_loans=active_loans,
        upcoming_emis=upcoming_emis,
        open_requests=open_requests
    )

@borrower_bp.route('/loans/create', methods=['GET', 'POST'])
@role_required('borrower')
def create_loan():
    user_id = session['user_id']
    kyc = query_db("SELECT status FROM kyc_documents WHERE user_id = %s ORDER BY id DESC LIMIT 1", (user_id,), one=True)

    if not kyc or kyc['status'] != 'Verified':
        flash('You must complete and have your KYC verified by an Admin before requesting loans.', 'warning')
        return redirect(url_for('borrower.kyc'))

    profile = query_db("SELECT * FROM borrower_profiles WHERE user_id = %s", (user_id,), one=True)

    if request.method == 'POST':
        title = request.form.get('title', '').strip()
        purpose = request.form.get('purpose', '').strip()
        try:
            amount = float(request.form.get('requested_amount', 0))
            interest_rate = float(request.form.get('interest_rate', 0))
            tenure_months = int(request.form.get('tenure_months', 0))
        except ValueError:
            amount = 0
            interest_rate = 0
            tenure_months = 0

        if not title or not purpose:
            flash('Please provide both loan title and detailed purpose.', 'danger')
            return render_template('borrower/create_loan.html', profile=profile)

        if amount < 1000 or amount > 2000000:
            flash('Loan amount must be between ₹1,000 and ₹20,00,000.', 'danger')
            return render_template('borrower/create_loan.html', profile=profile)

        if interest_rate < 5.0 or interest_rate > 36.0:
            flash('Offered interest rate must be between 5.0% and 36.0% per annum.', 'danger')
            return render_template('borrower/create_loan.html', profile=profile)

        if tenure_months not in [3, 6, 9, 12, 18, 24, 36, 48, 60]:
            flash('Please select a valid tenure (3, 6, 9, 12, 18, 24, 36, 48, or 60 months).', 'danger')
            return render_template('borrower/create_loan.html', profile=profile)

        try:
            req_id = execute_db(
                "INSERT INTO loan_requests (borrower_id, title, purpose, requested_amount, interest_rate, tenure_months, funded_amount, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, 0.00, 'Open')",
                (user_id, title, purpose, amount, interest_rate, tenure_months)
            )
            flash('Loan request successfully listed on the marketplace! Lenders can now discover and fund it.', 'success')
            return redirect(url_for('borrower.my_loans'))
        except Exception as e:
            flash(f'Failed to create loan request: {str(e)}', 'danger')
            return render_template('borrower/create_loan.html', profile=profile)

    return render_template('borrower/create_loan.html', profile=profile)

@borrower_bp.route('/loans')
@role_required('borrower')
def my_loans():
    user_id = session['user_id']
    requests = query_db(
        "SELECT *, ROUND((funded_amount / requested_amount) * 100, 1) as funded_percent "
        "FROM loan_requests WHERE borrower_id = %s ORDER BY created_at DESC",
        (user_id,)
    )
    loans = query_db(
        "SELECT l.*, lr.title, lr.purpose, "
        "(SELECT COUNT(*) FROM repayment_schedules s WHERE s.loan_id = l.id AND s.status = 'Paid') as paid_installments, "
        "(SELECT COUNT(*) FROM repayment_schedules s WHERE s.loan_id = l.id AND s.status = 'Overdue') as overdue_installments "
        "FROM loans l "
        "JOIN loan_requests lr ON l.loan_request_id = lr.id "
        "WHERE l.borrower_id = %s ORDER BY l.created_at DESC",
        (user_id,)
    )
    return render_template('borrower/my_loans.html', requests=requests, loans=loans)

@borrower_bp.route('/loans/<int:request_id>/cancel', methods=['POST'])
@role_required('borrower')
def cancel_loan_request(request_id):
    user_id = session['user_id']
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("CALL sp_cancel_loan_request(%s, %s, @p_status, @p_msg);", (request_id, user_id))
            cur.execute("SELECT @p_status as status, @p_msg as message;")
            result = cur.fetchone()

        status = result['status']
        msg = result['message']

        if status == 'SUCCESS':
            conn.commit()
            flash(msg, 'success')
        else:
            conn.rollback()
            flash(msg, 'danger')
    except Exception as e:
        conn.rollback()
        flash(f'Error cancelling loan request: {str(e)}', 'danger')

    return redirect(url_for('borrower.my_loans'))

@borrower_bp.route('/loans/<int:loan_id>')
@role_required('borrower')
def loan_details(loan_id):
    user_id = session['user_id']
    loan = query_db(
        "SELECT l.*, lr.title, lr.purpose "
        "FROM loans l "
        "JOIN loan_requests lr ON l.loan_request_id = lr.id "
        "WHERE l.id = %s AND l.borrower_id = %s",
        (loan_id, user_id),
        one=True
    )
    if not loan:
        flash('Loan record not found.', 'danger')
        return redirect(url_for('borrower.my_loans'))

    schedule = query_db(
        "SELECT * FROM repayment_schedules WHERE loan_id = %s ORDER BY installment_number ASC",
        (loan_id,)
    )
    wallet = query_db("SELECT balance FROM wallets WHERE user_id = %s", (user_id,), one=True)

    return render_template('borrower/loan_details.html', loan=loan, schedule=schedule, wallet=wallet)

@borrower_bp.route('/pay-emi/<int:schedule_id>', methods=['POST'])
@role_required('borrower')
def pay_emi(schedule_id):
    user_id = session['user_id']
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("CALL sp_pay_emi_installment(%s, %s, @p_status, @p_msg);", (schedule_id, user_id))
            cur.execute("SELECT @p_status as status, @p_msg as message;")
            result = cur.fetchone()

        status = result['status']
        msg = result['message']

        if status == 'SUCCESS':
            conn.commit()
            flash(msg, 'success')
        else:
            conn.rollback()
            flash(msg, 'danger')
    except Exception as e:
        conn.rollback()
        flash(f'Error processing repayment: {str(e)}', 'danger')

    next_url = request.referrer or url_for('borrower.dashboard')
    return redirect(next_url)

@borrower_bp.route('/credit-score')
@role_required('borrower')
def credit_score():
    user_id = session['user_id']
    profile = query_db("SELECT * FROM borrower_profiles WHERE user_id = %s", (user_id,), one=True)
    history = query_db(
        "SELECT * FROM credit_score_histories WHERE borrower_id = %s ORDER BY changed_at DESC",
        (user_id,)
    )
    return render_template('borrower/credit_score.html', profile=profile, history=history)

@borrower_bp.route('/kyc', methods=['GET', 'POST'])
@role_required('borrower')
def kyc():
    user_id = session['user_id']
    current_kyc = query_db("SELECT * FROM kyc_documents WHERE user_id = %s ORDER BY id DESC LIMIT 1", (user_id,), one=True)

    if request.method == 'POST':
        doc_type = request.form.get('document_type', '').strip()
        doc_number = request.form.get('document_number', '').strip()

        if not doc_type or not doc_number:
            flash('Document type and document number are required.', 'danger')
            return render_template('borrower/kyc.html', kyc=current_kyc)

        if doc_type not in ['Aadhaar', 'PAN', 'Passport', 'Driving License']:
            flash('Invalid document type selected.', 'danger')
            return render_template('borrower/kyc.html', kyc=current_kyc)

        try:
            execute_db(
                "INSERT INTO kyc_documents (user_id, document_type, document_number, status) "
                "VALUES (%s, %s, %s, 'Pending')",
                (user_id, doc_type, doc_number)
            )
            flash('KYC submission received! Our administrators will review and verify your identity shortly.', 'success')
            return redirect(url_for('borrower.kyc'))
        except Exception as e:
            flash(f'Error submitting KYC: {str(e)}', 'danger')

    return render_template('borrower/kyc.html', kyc=current_kyc)
