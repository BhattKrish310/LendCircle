from functools import wraps
from flask import Blueprint, render_template, request, redirect, url_for, flash, session, g
from werkzeug.security import generate_password_hash, check_password_hash
from app.db import query_db, execute_db, get_db

auth_bp = Blueprint('auth', __name__)

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            flash('Please log in to access this page.', 'warning')
            return redirect(url_for('auth.login', next=request.url))
        return f(*args, **kwargs)
    return decorated_function

def role_required(*roles):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if 'user_id' not in session:
                flash('Please log in first.', 'warning')
                return redirect(url_for('auth.login', next=request.url))
            if session.get('role') not in roles:
                flash('You are not authorized to view that page.', 'danger')
                if session.get('role') == 'borrower':
                    return redirect(url_for('borrower.dashboard'))
                elif session.get('role') == 'lender':
                    return redirect(url_for('lender.dashboard'))
                elif session.get('role') == 'admin':
                    return redirect(url_for('admin.dashboard'))
                return redirect(url_for('main.index'))
            return f(*args, **kwargs)
        return decorated_function
    return decorator

@auth_bp.before_app_request
def load_logged_in_user():
    user_id = session.get('user_id')
    if user_id is None:
        g.user = None
    else:
        g.user = query_db(
            "SELECT u.id, u.full_name, u.email, u.phone, u.role, u.status, w.balance, "
            "COALESCE(k.status, 'Not Submitted') as kyc_status "
            "FROM users u "
            "LEFT JOIN wallets w ON u.id = w.user_id "
            "LEFT JOIN (SELECT user_id, status FROM kyc_documents ORDER BY id DESC LIMIT 1) k ON u.id = k.user_id "
            "WHERE u.id = %s",
            (user_id,),
            one=True
        )

@auth_bp.route('/register', methods=['GET', 'POST'])
def register():
    if 'user_id' in session:
        return redirect_user_by_role(session.get('role'))

    if request.method == 'POST':
        full_name = request.form.get('full_name', '').strip()
        email = request.form.get('email', '').strip().lower()
        phone = request.form.get('phone', '').strip()
        password = request.form.get('password', '')
        confirm_password = request.form.get('confirm_password', '')
        role = request.form.get('role', '').strip().lower()

        if not full_name or not email or not phone or not password or not role:
            flash('All fields are required.', 'danger')
            return render_template('auth/register.html')

        if role not in ['borrower', 'lender']:
            flash('Invalid role selected.', 'danger')
            return render_template('auth/register.html')

        if password != confirm_password:
            flash('Passwords do not match.', 'danger')
            return render_template('auth/register.html')

        if len(password) < 6:
            flash('Password must be at least 6 characters long.', 'danger')
            return render_template('auth/register.html')

        # Check existing email or phone
        existing_user = query_db("SELECT id FROM users WHERE email = %s OR phone = %s", (email, phone), one=True)
        if existing_user:
            flash('Email or phone number is already registered.', 'danger')
            return render_template('auth/register.html')

        hashed_password = generate_password_hash(password)
        try:
            # Insert user (MySQL trigger trg_after_user_insert auto-creates wallet and role profile)
            user_id = execute_db(
                "INSERT INTO users (full_name, email, phone, password_hash, role, status) VALUES (%s, %s, %s, %s, %s, 'active')",
                (full_name, email, phone, hashed_password, role)
            )
            flash('Registration successful! You can now log in.', 'success')
            return redirect(url_for('auth.login'))
        except Exception as e:
            flash(f'An error occurred during registration: {str(e)}', 'danger')
            return render_template('auth/register.html')

    return render_template('auth/register.html')

@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    if 'user_id' in session:
        return redirect_user_by_role(session.get('role'))

    if request.method == 'POST':
        email = request.form.get('email', '').strip().lower()
        password = request.form.get('password', '')

        if not email or not password:
            flash('Please provide both email and password.', 'danger')
            return render_template('auth/login.html')

        user = query_db("SELECT * FROM users WHERE email = %s", (email,), one=True)
        if not user or not check_password_hash(user['password_hash'], password):
            flash('Invalid email or password.', 'danger')
            return render_template('auth/login.html')

        if user['status'] == 'suspended':
            flash('Your account has been suspended by an administrator. Please contact support.', 'danger')
            return render_template('auth/login.html')

        session.clear()
        session['user_id'] = user['id']
        session['full_name'] = user['full_name']
        session['email'] = user['email']
        session['role'] = user['role']

        flash(f"Welcome back, {user['full_name']}!", 'success')
        next_page = request.args.get('next')
        if next_page:
            return redirect(next_page)
        return redirect_user_by_role(user['role'])

    return render_template('auth/login.html')

@auth_bp.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out successfully.', 'info')
    return redirect(url_for('auth.login'))

def redirect_user_by_role(role):
    if role == 'borrower':
        return redirect(url_for('borrower.dashboard'))
    elif role == 'lender':
        return redirect(url_for('lender.dashboard'))
    elif role == 'admin':
        return redirect(url_for('admin.dashboard'))
    return redirect(url_for('main.index'))
