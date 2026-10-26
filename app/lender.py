from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from app.auth import role_required
from app.db import query_db, execute_db, get_db

lender_bp = Blueprint('lender', __name__, url_prefix='/lender')

@lender_bp.route('/dashboard')
@role_required('lender')
def dashboard():
    user_id = session['user_id']
    profile = query_db("SELECT * FROM lender_profiles WHERE user_id = %s", (user_id,), one=True)
    wallet = query_db("SELECT * FROM wallets WHERE user_id = %s", (user_id,), one=True)
    kyc = query_db("SELECT * FROM kyc_documents WHERE user_id = %s ORDER BY id DESC LIMIT 1", (user_id,), one=True)

    # Active investments
    investments = query_db(
        "SELECT inv.*, lr.title, lr.interest_rate, lr.status as request_status, l.id as loan_id, l.status as loan_status "
        "FROM investments inv "
        "JOIN loan_requests lr ON inv.loan_request_id = lr.id "
        "LEFT JOIN loans l ON lr.id = l.loan_request_id "
        "WHERE inv.lender_id = %s "
        "ORDER BY inv.funded_at DESC LIMIT 5",
        (user_id,)
    )

    # Marketplace highlights (top 3 open requests)
    featured_requests = query_db(
        "SELECT * FROM vw_loan_marketplace ORDER BY created_at DESC LIMIT 3"
    )

    # Summary metrics
    portfolio = query_db(
        "SELECT * FROM vw_lender_portfolio_summary WHERE lender_id = %s",
        (user_id,),
        one=True
    )

    return render_template(
        'lender/dashboard.html',
        profile=profile,
        wallet=wallet,
        kyc=kyc,
        investments=investments,
        featured_requests=featured_requests,
        portfolio=portfolio
    )

@lender_bp.route('/marketplace')
@role_required('lender')
def marketplace():
    # Filter parameters
    min_rate = request.args.get('min_rate', type=float)
    max_amount = request.args.get('max_amount', type=float)
    tenure = request.args.get('tenure', type=int)
    risk_category = request.args.get('risk_category', '').strip()
    min_score = request.args.get('min_score', type=int)

    query = "SELECT * FROM vw_loan_marketplace WHERE 1=1"
    params = []

    if min_rate is not None and min_rate > 0:
        query += " AND interest_rate >= %s"
        params.append(min_rate)

    if max_amount is not None and max_amount > 0:
        query += " AND remaining_amount <= %s"
        params.append(max_amount)

    if tenure is not None and tenure > 0:
        query += " AND tenure_months = %s"
        params.append(tenure)

    if risk_category in ['Low', 'Moderate', 'High']:
        query += " AND risk_category = %s"
        params.append(risk_category)

    if min_score is not None and min_score > 0:
        query += " AND credit_score >= %s"
        params.append(min_score)

    query += " ORDER BY created_at DESC"
    requests = query_db(query, params)

    return render_template(
        'lender/marketplace.html',
        requests=requests,
        filters={
            'min_rate': min_rate or '',
            'max_amount': max_amount or '',
            'tenure': tenure or '',
            'risk_category': risk_category,
            'min_score': min_score or ''
        }
    )

@lender_bp.route('/loans/<int:request_id>')
@role_required('lender')
def loan_view(request_id):
    user_id = session['user_id']
    req = query_db("SELECT * FROM vw_loan_marketplace WHERE request_id = %s", (request_id,), one=True)
    if not req:
        flash('Loan request is either closed or no longer accepting investments.', 'warning')
        return redirect(url_for('lender.marketplace'))

    borrower_stats = query_db(
        "SELECT * FROM vw_borrower_risk_summary WHERE borrower_id = %s",
        (req['borrower_id'],),
        one=True
    )
    wallet = query_db("SELECT balance FROM wallets WHERE user_id = %s", (user_id,), one=True)
    existing_investments = query_db(
        "SELECT inv.*, u.full_name as lender_name "
        "FROM investments inv "
        "JOIN users u ON inv.lender_id = u.id "
        "WHERE inv.loan_request_id = %s "
        "ORDER BY inv.funded_at ASC",
        (request_id,)
    )
    kyc = query_db("SELECT status FROM kyc_documents WHERE user_id = %s ORDER BY id DESC LIMIT 1", (user_id,), one=True)

    return render_template(
        'lender/loan_view.html',
        req=req,
        borrower_stats=borrower_stats,
        wallet=wallet,
        existing_investments=existing_investments,
        kyc=kyc
    )

@lender_bp.route('/invest/<int:request_id>', methods=['POST'])
@role_required('lender')
def invest(request_id):
    user_id = session['user_id']
    try:
        amount = float(request.form.get('amount', 0))
    except ValueError:
        amount = 0

    if amount <= 0:
        flash('Investment amount must be greater than zero.', 'danger')
        return redirect(url_for('lender.loan_view', request_id=request_id))

    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("CALL sp_fund_loan_request(%s, %s, %s, @p_status, @p_msg);", (request_id, user_id, amount))
            cur.execute("SELECT @p_status as status, @p_msg as message;")
            result = cur.fetchone()

        status = result['status']
        msg = result['message']

        if status in ['SUCCESS_FUNDED', 'SUCCESS_PARTIAL']:
            conn.commit()
            flash(msg, 'success')
            return redirect(url_for('lender.my_investments'))
        else:
            conn.rollback()
            flash(msg, 'danger')
            return redirect(url_for('lender.loan_view', request_id=request_id))
    except Exception as e:
        conn.rollback()
        flash(f'Error processing investment: {str(e)}', 'danger')
        return redirect(url_for('lender.loan_view', request_id=request_id))

@lender_bp.route('/my-investments')
@role_required('lender')
def my_investments():
    user_id = session['user_id']
    investments = query_db(
        "SELECT inv.*, lr.title, lr.requested_amount, lr.interest_rate, lr.tenure_months, lr.status as request_status, "
        "l.id as loan_id, l.status as loan_status, "
        "(SELECT COALESCE(SUM(t.amount), 0) FROM transactions t "
        " JOIN wallets w ON t.wallet_id = w.id "
        " WHERE w.user_id = %s AND t.type = 'Repayment Received' AND t.reference_id LIKE CONCAT('%%LOAN-', l.id, '%%')) as returns_received "
        "FROM investments inv "
        "JOIN loan_requests lr ON inv.loan_request_id = lr.id "
        "LEFT JOIN loans l ON lr.id = l.loan_request_id "
        "WHERE inv.lender_id = %s "
        "ORDER BY inv.funded_at DESC",
        (user_id, user_id)
    )
    portfolio = query_db(
        "SELECT * FROM vw_lender_portfolio_summary WHERE lender_id = %s",
        (user_id,),
        one=True
    )
    return render_template('lender/my_investments.html', investments=investments, portfolio=portfolio)

@lender_bp.route('/kyc', methods=['GET', 'POST'])
@role_required('lender')
def kyc():
    user_id = session['user_id']
    current_kyc = query_db("SELECT * FROM kyc_documents WHERE user_id = %s ORDER BY id DESC LIMIT 1", (user_id,), one=True)

    if request.method == 'POST':
        doc_type = request.form.get('document_type', '').strip()
        doc_number = request.form.get('document_number', '').strip()

        if not doc_type or not doc_number:
            flash('Document type and document number are required.', 'danger')
            return render_template('lender/kyc.html', kyc=current_kyc)

        if doc_type not in ['Aadhaar', 'PAN', 'Passport', 'Driving License']:
            flash('Invalid document type selected.', 'danger')
            return render_template('lender/kyc.html', kyc=current_kyc)

        try:
            execute_db(
                "INSERT INTO kyc_documents (user_id, document_type, document_number, status) "
                "VALUES (%s, %s, %s, 'Pending')",
                (user_id, doc_type, doc_number)
            )
            flash('KYC document submitted successfully! Admin verification is in progress.', 'success')
            return redirect(url_for('lender.kyc'))
        except Exception as e:
            flash(f'Error submitting KYC: {str(e)}', 'danger')

    return render_template('lender/kyc.html', kyc=current_kyc)
