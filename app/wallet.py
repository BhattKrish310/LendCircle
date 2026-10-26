from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from app.auth import login_required
from app.db import query_db, execute_db, get_db

wallet_bp = Blueprint('wallet', __name__, url_prefix='/wallet')

@wallet_bp.route('/')
@login_required
def index():
    user_id = session['user_id']
    wallet = query_db("SELECT * FROM wallets WHERE user_id = %s", (user_id,), one=True)
    if not wallet:
        flash("Wallet not found.", "danger")
        return redirect(url_for('main.index'))

    # Transaction filter
    tx_type = request.args.get('type')
    if tx_type:
        transactions = query_db(
            "SELECT * FROM transactions WHERE wallet_id = %s AND type = %s ORDER BY created_at DESC",
            (wallet['id'], tx_type)
        )
    else:
        transactions = query_db(
            "SELECT * FROM transactions WHERE wallet_id = %s ORDER BY created_at DESC LIMIT 50",
            (wallet['id'],)
        )

    # Statistics
    stats = query_db(
        "SELECT "
        "COALESCE(SUM(CASE WHEN direction = 'Credit' THEN amount ELSE 0 END), 0) as total_credits, "
        "COALESCE(SUM(CASE WHEN direction = 'Debit' THEN amount ELSE 0 END), 0) as total_debits "
        "FROM transactions WHERE wallet_id = %s",
        (wallet['id'],),
        one=True
    )

    return render_template('wallet/wallet.html', wallet=wallet, transactions=transactions, stats=stats, current_filter=tx_type)

@wallet_bp.route('/deposit', methods=['POST'])
@login_required
def deposit():
    user_id = session['user_id']
    try:
        amount = float(request.form.get('amount', 0))
    except ValueError:
        amount = 0

    if amount <= 0:
        flash('Deposit amount must be greater than zero.', 'danger')
        return redirect(url_for('wallet.index'))

    if amount > 1000000:
        flash('Single deposit cannot exceed ₹10,00,000.', 'danger')
        return redirect(url_for('wallet.index'))

    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, balance FROM wallets WHERE user_id = %s FOR UPDATE", (user_id,))
            wallet = cur.fetchone()
            new_balance = float(wallet['balance']) + amount

            cur.execute("UPDATE wallets SET balance = %s WHERE id = %s", (new_balance, wallet['id']))
            cur.execute(
                "INSERT INTO transactions (wallet_id, amount, type, direction, reference_id, balance_after, description) "
                "VALUES (%s, %s, 'Deposit', 'Credit', 'SIM-DEP', %s, 'Instant simulated wallet deposit')",
                (wallet['id'], amount, new_balance)
            )
        conn.commit()
        flash(f'Successfully deposited ₹{amount:,.2f} into your wallet!', 'success')
    except Exception as e:
        conn.rollback()
        flash(f'Error processing deposit: {str(e)}', 'danger')

    return redirect(url_for('wallet.index'))

@wallet_bp.route('/withdraw', methods=['POST'])
@login_required
def withdraw():
    user_id = session['user_id']
    try:
        amount = float(request.form.get('amount', 0))
    except ValueError:
        amount = 0

    if amount <= 0:
        flash('Withdrawal amount must be greater than zero.', 'danger')
        return redirect(url_for('wallet.index'))

    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, balance FROM wallets WHERE user_id = %s FOR UPDATE", (user_id,))
            wallet = cur.fetchone()
            curr_balance = float(wallet['balance'])

            if curr_balance < amount:
                flash(f'Insufficient funds. Current balance is ₹{curr_balance:,.2f}.', 'danger')
                return redirect(url_for('wallet.index'))

            new_balance = curr_balance - amount
            cur.execute("UPDATE wallets SET balance = %s WHERE id = %s", (new_balance, wallet['id']))
            cur.execute(
                "INSERT INTO transactions (wallet_id, amount, type, direction, reference_id, balance_after, description) "
                "VALUES (%s, %s, 'Withdrawal', 'Debit', 'SIM-WTH', %s, 'Simulated withdrawal to linked bank account')",
                (wallet['id'], amount, new_balance)
            )
        conn.commit()
        flash(f'Successfully withdrew ₹{amount:,.2f} to your bank account!', 'success')
    except Exception as e:
        conn.rollback()
        flash(f'Error processing withdrawal: {str(e)}', 'danger')

    return redirect(url_for('wallet.index'))
