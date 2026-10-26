import pymysql
import pymysql.cursors
from flask import g, current_app

def get_db():
    """Get or establish database connection for current request context."""
    if 'db' not in g:
        g.db = pymysql.connect(
            host=current_app.config['DB_HOST'],
            port=current_app.config['DB_PORT'],
            user=current_app.config['DB_USER'],
            password=current_app.config['DB_PASSWORD'],
            database=current_app.config['DB_NAME'],
            charset='utf8mb4',
            cursorclass=pymysql.cursors.DictCursor,
            autocommit=False
        )
    return g.db

def close_db(e=None):
    """Close the database connection at the end of request."""
    db = g.pop('db', None)
    if db is not None:
        db.close()

def query_db(query, args=(), one=False):
    """Execute a query and fetch all or one result row."""
    conn = get_db()
    with conn.cursor() as cursor:
        cursor.execute(query, args)
        rv = cursor.fetchall()
        return (rv[0] if rv else None) if one else rv

def execute_db(query, args=(), commit=True):
    """Execute an INSERT, UPDATE, or DELETE query and return lastrowid / affected rows."""
    conn = get_db()
    with conn.cursor() as cursor:
        affected = cursor.execute(query, args)
        last_id = cursor.lastrowid
        if commit:
            conn.commit()
        return last_id if last_id else affected
