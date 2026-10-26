from flask import Blueprint, render_template, request, session, redirect, url_for, flash, abort
from app.db import query_db, execute_db
from app.blog_data import BLOG_POSTS

main_bp = Blueprint('main', __name__)

@main_bp.route('/')
def index():
    # Fetch platform stats for landing page hero
    stats = query_db(
        "SELECT "
        "(SELECT COUNT(*) FROM users WHERE role IN ('borrower', 'lender')) as total_members, "
        "(SELECT COALESCE(SUM(principal_amount), 0) FROM loans) as total_funded, "
        "(SELECT COUNT(*) FROM loans WHERE status = 'Active') as active_loans_count, "
        "(SELECT COUNT(*) FROM loan_requests WHERE status = 'Open') as open_marketplace_count",
        one=True
    )
    sample_loans = query_db("SELECT * FROM vw_loan_marketplace LIMIT 3")
    featured_blogs = list(BLOG_POSTS.values())[:3]
    return render_template('index.html', stats=stats, sample_loans=sample_loans, featured_blogs=featured_blogs)

@main_bp.route('/lending')
def lending():
    """Lending informational overview page matching the screenshot navigation."""
    stats = query_db(
        "SELECT "
        "(SELECT COALESCE(SUM(principal_amount), 0) FROM loans) as total_funded, "
        "(SELECT COUNT(*) FROM loan_requests WHERE status = 'Open') as open_marketplace_count, "
        "(SELECT COUNT(*) FROM loans WHERE status = 'Active') as active_loans_count",
        one=True
    )
    sample_loans = query_db("SELECT * FROM vw_loan_marketplace LIMIT 6")
    return render_template('lending.html', stats=stats, sample_loans=sample_loans)

@main_bp.route('/blog')
def blog():
    """Blog & Learning Hub listing all educational guides."""
    category = request.args.get('category', '').strip()
    posts = list(BLOG_POSTS.values())
    if category:
        posts = [p for p in posts if p['category'].lower() == category.lower()]
    return render_template('blog/index.html', posts=posts, current_category=category)

@main_bp.route('/blog/<slug>')
def blog_post(slug):
    """Individual blog article reader."""
    post = BLOG_POSTS.get(slug)
    if not post:
        abort(404)
    # Get other related articles
    related = [p for k, p in BLOG_POSTS.items() if k != slug][:3]
    return render_template('blog/post.html', post=post, related=related)

@main_bp.route('/profile', methods=['GET', 'POST'])
def profile():
    if 'user_id' not in session:
        flash('Please log in to view your profile.', 'warning')
        return redirect(url_for('auth.login'))

    user_id = session['user_id']
    user = query_db("SELECT * FROM users WHERE id = %s", (user_id,), one=True)
    borrower_profile = None
    lender_profile = None

    if user['role'] == 'borrower':
        borrower_profile = query_db("SELECT * FROM borrower_profiles WHERE user_id = %s", (user_id,), one=True)
    elif user['role'] == 'lender':
        lender_profile = query_db("SELECT * FROM lender_profiles WHERE user_id = %s", (user_id,), one=True)

    if request.method == 'POST':
        full_name = request.form.get('full_name', '').strip()
        phone = request.form.get('phone', '').strip()

        if not full_name or not phone:
            flash('Name and phone cannot be empty.', 'danger')
        else:
            try:
                execute_db("UPDATE users SET full_name = %s, phone = %s WHERE id = %s", (full_name, phone, user_id))
                session['full_name'] = full_name

                if user['role'] == 'borrower':
                    income = float(request.form.get('annual_income', 0))
                    emp_status = request.form.get('employment_status', 'Salaried')
                    address = request.form.get('address', '').strip()
                    execute_db(
                        "UPDATE borrower_profiles SET annual_income = %s, employment_status = %s, address = %s WHERE user_id = %s",
                        (income, emp_status, address, user_id)
                    )
                elif user['role'] == 'lender':
                    limit = float(request.form.get('investment_limit', 1000000))
                    execute_db("UPDATE lender_profiles SET investment_limit = %s WHERE user_id = %s", (limit, user_id))

                flash('Profile updated successfully!', 'success')
                return redirect(url_for('main.profile'))
            except Exception as e:
                flash(f'Failed to update profile: {str(e)}', 'danger')

    return render_template('profile.html', user=user, borrower_profile=borrower_profile, lender_profile=lender_profile)
