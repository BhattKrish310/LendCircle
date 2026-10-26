from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from app.auth import role_required
from app.db import query_db, execute_db, get_db

admin_bp = Blueprint('admin', __name__, url_prefix='/admin')

@admin_bp.route('/dashboard')
@role_required('admin')
def dashboard():
    metrics = query_db("SELECT * FROM platform_metrics_daily ORDER BY metric_date DESC LIMIT 1", one=True)
    recent_flags = query_db(
        "SELECT rf.*, u.full_name as user_name, u.role as user_role "
        "FROM risk_flags rf "
        "JOIN users u ON rf.user_id = u.id "
        "WHERE rf.status = 'Open' "
        "ORDER BY rf.created_at DESC LIMIT 5"
    )
    pending_kyc = query_db(
        "SELECT k.*, u.full_name, u.email, u.role "
        "FROM kyc_documents k "
        "JOIN users u ON k.user_id = u.id "
        "WHERE k.status = 'Pending' "
        "ORDER BY k.submitted_at ASC LIMIT 5"
    )
    recent_loans = query_db(
        "SELECT l.*, u.full_name as borrower_name, lr.title "
        "FROM loans l "
        "JOIN users u ON l.borrower_id = u.id "
        "JOIN loan_requests lr ON l.loan_request_id = lr.id "
        "ORDER BY l.created_at DESC LIMIT 5"
    )

    return render_template(
        'admin/dashboard.html',
        metrics=metrics,
        recent_flags=recent_flags,
        pending_kyc=pending_kyc,
        recent_loans=recent_loans
    )

@admin_bp.route('/kyc')
@role_required('admin')
def kyc_queue():
    status = request.args.get('status', 'Pending')
    if status in ['Pending', 'Verified', 'Rejected']:
        kyc_list = query_db(
            "SELECT k.*, u.full_name, u.email, u.phone, u.role, r.full_name as reviewer_name "
            "FROM kyc_documents k "
            "JOIN users u ON k.user_id = u.id "
            "LEFT JOIN users r ON k.reviewed_by = r.id "
            "WHERE k.status = %s "
            "ORDER BY k.submitted_at DESC",
            (status,)
        )
    else:
        kyc_list = query_db(
            "SELECT k.*, u.full_name, u.email, u.phone, u.role, r.full_name as reviewer_name "
            "FROM kyc_documents k "
            "JOIN users u ON k.user_id = u.id "
            "LEFT JOIN users r ON k.reviewed_by = r.id "
            "ORDER BY k.submitted_at DESC"
        )

    return render_template('admin/kyc_queue.html', kyc_list=kyc_list, current_status=status)

@admin_bp.route('/kyc/<int:kyc_id>/action', methods=['POST'])
@role_required('admin')
def kyc_action(kyc_id):
    admin_id = session['user_id']
    action = request.form.get('action')
    remarks = request.form.get('remarks', '').strip()

    if action not in ['Verified', 'Rejected']:
        flash('Invalid action specified.', 'danger')
        return redirect(url_for('admin.kyc_queue'))

    try:
        execute_db(
            "UPDATE kyc_documents "
            "SET status = %s, admin_remarks = %s, reviewed_by = %s, reviewed_at = CURRENT_TIMESTAMP "
            "WHERE id = %s",
            (action, remarks, admin_id, kyc_id)
        )
        flash(f'KYC marked as {action} successfully.', 'success')
    except Exception as e:
        flash(f'Error updating KYC: {str(e)}', 'danger')

    return redirect(url_for('admin.kyc_queue'))

@admin_bp.route('/users')
@role_required('admin')
def users():
    search = request.args.get('search', '').strip()
    role_filter = request.args.get('role', '').strip()

    query = (
        "SELECT u.*, w.balance, "
        "COALESCE(bp.credit_score, NULL) as credit_score, "
        "COALESCE(bp.risk_category, NULL) as risk_category, "
        "COALESCE(lp.total_invested, NULL) as total_invested "
        "FROM users u "
        "LEFT JOIN wallets w ON u.id = w.user_id "
        "LEFT JOIN borrower_profiles bp ON u.id = bp.user_id "
        "LEFT JOIN lender_profiles lp ON u.id = lp.user_id "
        "WHERE 1=1"
    )
    params = []

    if search:
        query += " AND (u.full_name LIKE %s OR u.email LIKE %s OR u.phone LIKE %s)"
        params.extend([f"%{search}%", f"%{search}%", f"%{search}%"])

    if role_filter in ['borrower', 'lender', 'admin']:
        query += " AND u.role = %s"
        params.append(role_filter)

    query += " ORDER BY u.created_at DESC"
    user_list = query_db(query, params)

    return render_template('admin/users.html', users=user_list, search=search, role_filter=role_filter)

@admin_bp.route('/users/<int:user_id>/toggle-status', methods=['POST'])
@role_required('admin')
def toggle_user_status(user_id):
    if user_id == session['user_id']:
        flash('You cannot suspend your own admin account.', 'danger')
        return redirect(url_for('admin.users'))

    user = query_db("SELECT status FROM users WHERE id = %s", (user_id,), one=True)
    if not user:
        flash('User not found.', 'danger')
        return redirect(url_for('admin.users'))

    new_status = 'suspended' if user['status'] == 'active' else 'active'
    try:
        execute_db("UPDATE users SET status = %s WHERE id = %s", (new_status, user_id))
        flash(f'User status changed to {new_status.upper()}.', 'success')
    except Exception as e:
        flash(f'Error updating user: {str(e)}', 'danger')

    return redirect(url_for('admin.users'))

@admin_bp.route('/loans')
@role_required('admin')
def loans():
    status = request.args.get('status', '').strip()
    query = (
        "SELECT l.*, u.full_name as borrower_name, lr.title, "
        "(SELECT COUNT(*) FROM repayment_schedules s WHERE s.loan_id = l.id AND s.status = 'Paid') as paid_installments, "
        "(SELECT COUNT(*) FROM repayment_schedules s WHERE s.loan_id = l.id AND s.status = 'Overdue') as overdue_installments "
        "FROM loans l "
        "JOIN users u ON l.borrower_id = u.id "
        "JOIN loan_requests lr ON l.loan_request_id = lr.id "
        "WHERE 1=1"
    )
    params = []
    if status in ['Active', 'Completed', 'Defaulted']:
        query += " AND l.status = %s"
        params.append(status)

    query += " ORDER BY l.created_at DESC"
    all_loans = query_db(query, params)

    open_requests = query_db(
        "SELECT lr.*, u.full_name as borrower_name, "
        "ROUND((lr.funded_amount / lr.requested_amount) * 100, 1) as funded_percent "
        "FROM loan_requests lr "
        "JOIN users u ON lr.borrower_id = u.id "
        "WHERE lr.status = 'Open' ORDER BY lr.created_at DESC"
    )

    return render_template('admin/loans.html', loans=all_loans, open_requests=open_requests, current_status=status)

@admin_bp.route('/risk-flags')
@role_required('admin')
def risk_flags():
    status = request.args.get('status', 'Open')
    query = (
        "SELECT rf.*, u.full_name as user_name, u.role as user_role, u.email as user_email, "
        "r.full_name as reviewer_name "
        "FROM risk_flags rf "
        "JOIN users u ON rf.user_id = u.id "
        "LEFT JOIN users r ON rf.reviewed_by = r.id "
        "WHERE 1=1"
    )
    params = []
    if status in ['Open', 'Reviewed', 'Dismissed']:
        query += " AND rf.status = %s"
        params.append(status)

    query += " ORDER BY rf.created_at DESC"
    flags = query_db(query, params)

    return render_template('admin/risk_flags.html', flags=flags, current_status=status)

@admin_bp.route('/risk-flags/<int:flag_id>/update', methods=['POST'])
@role_required('admin')
def update_risk_flag(flag_id):
    admin_id = session['user_id']
    new_status = request.form.get('status')
    if new_status not in ['Reviewed', 'Dismissed', 'Open']:
        flash('Invalid status.', 'danger')
        return redirect(url_for('admin.risk_flags'))

    try:
        execute_db(
            "UPDATE risk_flags SET status = %s, reviewed_by = %s, reviewed_at = CURRENT_TIMESTAMP WHERE id = %s",
            (new_status, admin_id, flag_id)
        )
        flash(f'Risk flag marked as {new_status}.', 'success')
    except Exception as e:
        flash(f'Error updating risk flag: {str(e)}', 'danger')

    return redirect(url_for('admin.risk_flags'))

@admin_bp.route('/reports')
@role_required('admin')
def reports():
    monthly_rev = query_db("SELECT * FROM vw_monthly_platform_revenue")
    top_lenders = query_db("SELECT * FROM vw_lender_portfolio_summary ORDER BY total_invested DESC LIMIT 5")
    borrower_risks = query_db("SELECT * FROM vw_borrower_risk_summary ORDER BY open_risk_flags DESC, total_overdue_installments DESC LIMIT 10")
    daily_history = query_db("SELECT * FROM platform_metrics_daily ORDER BY metric_date DESC LIMIT 30")

    return render_template(
        'admin/reports.html',
        monthly_rev=monthly_rev,
        top_lenders=top_lenders,
        borrower_risks=borrower_risks,
        daily_history=daily_history
    )

@admin_bp.route('/refresh-metrics', methods=['POST'])
@role_required('admin')
def refresh_metrics():
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("CALL sp_check_and_mark_overdue();")
            cur.execute("CALL sp_refresh_platform_metrics();")
        conn.commit()
        flash('Overdue installments checked, penalties assessed, and platform metrics refreshed!', 'success')
    except Exception as e:
        conn.rollback()
        flash(f'Error refreshing metrics: {str(e)}', 'danger')

    return redirect(request.referrer or url_for('admin.dashboard'))
