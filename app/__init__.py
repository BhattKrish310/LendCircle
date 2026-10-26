import markdown
from flask import Flask
from config import Config
from app.db import close_db

def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    # Register teardown function to clean up database connections
    app.teardown_appcontext(close_db)

    # Custom Jinja filters
    @app.template_filter('markdown')
    def markdown_filter(text):
        if not text:
            return ''
        return markdown.markdown(text, extensions=['extra', 'tables', 'nl2br'])

    @app.template_filter('currency')
    def currency_filter(value):
        try:
            val = float(value or 0)
            return f"₹{val:,.2f}"
        except (ValueError, TypeError):
            return f"₹{value}"

    @app.template_filter('date')
    def date_filter(value, fmt='%d %b %Y'):
        if not value:
            return '-'
        try:
            return value.strftime(fmt)
        except AttributeError:
            return str(value)

    # Register blueprints
    from app.main import main_bp
    from app.auth import auth_bp
    from app.borrower import borrower_bp
    from app.lender import lender_bp
    from app.admin import admin_bp
    from app.wallet import wallet_bp

    app.register_blueprint(main_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(borrower_bp)
    app.register_blueprint(lender_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(wallet_bp)

    return app
