import os
import subprocess
import sys

MYSQL_PATH = r"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "1234")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "3306")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

SQL_FILES = [
    os.path.join(BASE_DIR, "01_schema.sql"),
    os.path.join(BASE_DIR, "02_procedures_triggers_views.sql"),
    os.path.join(BASE_DIR, "03_seed_data.sql"),
]

def run_sql_via_cli(file_path):
    print(f"--> Executing {os.path.basename(file_path)}...")
    cmd = [
        MYSQL_PATH,
        f"-h{DB_HOST}",
        f"-P{DB_PORT}",
        f"-u{DB_USER}",
        f"-p{DB_PASSWORD}",
        "--default-character-set=utf8mb4"
    ]
    with open(file_path, "rb") as f:
        res = subprocess.run(cmd, stdin=f, capture_output=True, text=True)
        if res.returncode != 0:
            print(f"Error executing {file_path}:\n{res.stderr}")
            return False
        else:
            print(f"[OK] {os.path.basename(file_path)} executed successfully.")
            return True

def init_database():
    print("=" * 60)
    print("Initializing P2P Lending Platform Database")
    print("=" * 60)
    for sql_file in SQL_FILES:
        if not os.path.exists(sql_file):
            print(f"File not found: {sql_file}")
            sys.exit(1)
        success = run_sql_via_cli(sql_file)
        if not success:
            print("Database initialization failed.")
            sys.exit(1)
    print("\nDatabase initialization completed successfully!")

if __name__ == "__main__":
    init_database()
