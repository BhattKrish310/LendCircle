import unittest
from app import create_app
from app.db import query_db, execute_db

class P2PAppTestCase(unittest.TestCase):
    def setUp(self):
        self.app = create_app()
        self.app.config['TESTING'] = True
        self.client = self.app.test_client()

    def test_01_landing_page(self):
        response = self.client.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'LendCircle', response.data)
        self.assertIn(b'What is Peer-to-Peer (P2P) Lending?', response.data)
        self.assertIn(b'Estimate Your Potential Returns', response.data)

        # Test Lending page
        res_lending = self.client.get('/lending')
        self.assertEqual(res_lending.status_code, 200)
        self.assertIn(b'Lend Directly to Verified Borrowers Across India', res_lending.data)

        # Test Blog Hub & Guides
        res_blog = self.client.get('/blog')
        self.assertEqual(res_blog.status_code, 200)
        self.assertIn(b'LendCircle Knowledge Center', res_blog.data)
        self.assertIn(b'Borrowing Guide: What to Prepare Before Applying for a Loan', res_blog.data)

        # Test Individual Blog Article Reader
        res_post = self.client.get('/blog/borrowing-guide-what-to-prepare')
        self.assertEqual(res_post.status_code, 200)
        self.assertIn(b'Essential Documentation Checklist', res_post.data)

    def test_02_login_and_dashboards(self):
        # 1. Test Admin Login
        res_admin = self.client.post('/login', data={
            'email': 'admin@p2plending.com',
            'password': 'admin123'
        }, follow_redirects=True)
        self.assertEqual(res_admin.status_code, 200)
        self.assertIn(b'Platform Administrator Control Panel', res_admin.data)

        # 2. Test Admin KYC Queue
        res_kyc = self.client.get('/admin/kyc')
        self.assertEqual(res_kyc.status_code, 200)

        # 3. Test Admin Reports
        res_reports = self.client.get('/admin/reports')
        self.assertEqual(res_reports.status_code, 200)
        self.assertIn(b'Monthly Platform Volume', res_reports.data)

        # Logout
        self.client.get('/logout')

        # 4. Test Borrower Login
        res_borrower = self.client.post('/login', data={
            'email': 'rahul.sharma@example.com',
            'password': 'password123'
        }, follow_redirects=True)
        self.assertEqual(res_borrower.status_code, 200)
        self.assertIn(b'Borrower Dashboard', res_borrower.data)

        # Borrower Credit Score
        res_cs = self.client.get('/borrower/credit-score')
        self.assertEqual(res_cs.status_code, 200)
        self.assertIn(b'Credit Score & Audit History', res_cs.data)

        # Logout
        self.client.get('/logout')

        # 5. Test Lender Login
        res_lender = self.client.post('/login', data={
            'email': 'arun.mehta@example.com',
            'password': 'password123'
        }, follow_redirects=True)
        self.assertEqual(res_lender.status_code, 200)
        self.assertIn(b'Lender Dashboard', res_lender.data)

        # Lender Marketplace
        res_market = self.client.get('/lender/marketplace')
        self.assertEqual(res_market.status_code, 200)
        self.assertIn(b'Loan Marketplace', res_market.data)

    def test_03_wallet_deposit_withdraw(self):
        # Login as Lender Arun
        self.client.post('/login', data={
            'email': 'arun.mehta@example.com',
            'password': 'password123'
        }, follow_redirects=True)

        # View wallet
        res_wallet = self.client.get('/wallet/')
        self.assertEqual(res_wallet.status_code, 200)
        self.assertIn(b'Available Balance', res_wallet.data)

        # Test simulated deposit
        res_dep = self.client.post('/wallet/deposit', data={'amount': '5000'}, follow_redirects=True)
        self.assertEqual(res_dep.status_code, 200)
        self.assertIn(b'Successfully deposited', res_dep.data)

    def test_04_borrower_loan_flow_and_repayment(self):
        # 1. Log in as Borrower Rahul
        self.client.post('/login', data={
            'email': 'rahul.sharma@example.com',
            'password': 'password123'
        }, follow_redirects=True)

        # Deposit funds into wallet to ensure sufficient balance for repayment
        self.client.post('/wallet/deposit', data={'amount': '20000'}, follow_redirects=True)

        # Fetch an active loan schedule with a pending EMI for Rahul
        with self.app.app_context():
            sched = query_db(
                "SELECT s.id, s.loan_id FROM repayment_schedules s "
                "JOIN loans l ON s.loan_id = l.id "
                "WHERE l.borrower_id = 2 AND s.status = 'Pending' LIMIT 1",
                one=True
            )
        if sched:
            res_pay = self.client.post(f'/borrower/pay-emi/{sched["id"]}', follow_redirects=True)
            self.assertEqual(res_pay.status_code, 200)
            self.assertIn(b'EMI payment processed successfully', res_pay.data)

    def test_05_admin_refresh_metrics(self):
        # Log in as Admin
        self.client.post('/login', data={
            'email': 'admin@p2plending.com',
            'password': 'admin123'
        }, follow_redirects=True)

        res_refresh = self.client.post('/admin/refresh-metrics', follow_redirects=True)
        self.assertEqual(res_refresh.status_code, 200)
        self.assertIn(b'platform metrics refreshed', res_refresh.data)

    def test_06_cancel_loan_request(self):
        # 1. Log in as Borrower Rahul
        self.client.post('/login', data={
            'email': 'rahul.sharma@example.com',
            'password': 'password123'
        }, follow_redirects=True)

        # 2. Create a test loan request
        res_create = self.client.post('/borrower/loans/create', data={
            'title': 'Test Medical Emergency Fund',
            'purpose': 'Testing loan request cancellation workflow',
            'requested_amount': '25000',
            'interest_rate': '11.5',
            'tenure_months': '6'
        }, follow_redirects=True)
        self.assertEqual(res_create.status_code, 200)

        # 3. Find the created request ID
        with self.app.app_context():
            req = query_db(
                "SELECT id, status FROM loan_requests WHERE borrower_id = 2 AND title = 'Test Medical Emergency Fund' ORDER BY id DESC LIMIT 1",
                one=True
            )
        self.assertIsNotNone(req)
        self.assertEqual(req['status'], 'Open')

        # 4. Cancel the request
        res_cancel = self.client.post(f'/borrower/loans/{req["id"]}/cancel', follow_redirects=True)
        self.assertEqual(res_cancel.status_code, 200)
        self.assertIn(b'cancelled successfully', res_cancel.data)

        # 5. Verify database status is now Cancelled
        with self.app.app_context():
            req_after = query_db("SELECT status FROM loan_requests WHERE id = %s", (req['id'],), one=True)
        self.assertEqual(req_after['status'], 'Cancelled')

if __name__ == '__main__':
    unittest.main()
