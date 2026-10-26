/**
 * P2P Lending Platform - Frontend Scripts
 * Light/Dark Theme Controller, Mobile Navigation, and Financial Calculators
 */

(function () {
  'use strict';

  // 1. Theme Management
  const themeToggleBtn = document.getElementById('theme-toggle-btn');
  const themeIcon = document.getElementById('theme-icon');
  const themeLabel = document.getElementById('theme-label');

  function getPreferredTheme() {
    const savedTheme = localStorage.getItem('p2p_theme');
    if (savedTheme) {
      return savedTheme;
    }
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('p2p_theme', theme);

    if (themeIcon) {
      themeIcon.textContent = theme === 'dark' ? '☀️' : '🌙';
    }
    if (themeLabel) {
      themeLabel.textContent = theme === 'dark' ? 'Light' : 'Dark';
    }
  }

  // Initialize theme immediately
  const initialTheme = getPreferredTheme();
  applyTheme(initialTheme);

  if (themeToggleBtn) {
    themeToggleBtn.addEventListener('click', () => {
      const currentTheme = document.documentElement.getAttribute('data-theme') || 'light';
      const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
      applyTheme(newTheme);
    });
  }

  // Listen for system preference changes
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    if (!localStorage.getItem('p2p_theme')) {
      applyTheme(e.matches ? 'dark' : 'light');
    }
  });

  // 2. Mobile Navigation Toggle
  const mobileToggle = document.getElementById('mobile-nav-toggle');
  const navLinks = document.getElementById('nav-links');

  if (mobileToggle && navLinks) {
    mobileToggle.addEventListener('click', () => {
      navLinks.classList.toggle('open');
    });
  }

  // 3. Real-time EMI Preview Calculator (for Borrower Create Loan page)
  const amountInput = document.getElementById('calc-amount');
  const rateInput = document.getElementById('calc-rate');
  const tenureInput = document.getElementById('calc-tenure');
  const emiDisplay = document.getElementById('calc-emi-display');
  const totalRepayDisplay = document.getElementById('calc-total-display');
  const interestDisplay = document.getElementById('calc-interest-display');

  function calculateEMI() {
    if (!amountInput || !rateInput || !tenureInput || !emiDisplay) return;

    const P = parseFloat(amountInput.value) || 0;
    const annualRate = parseFloat(rateInput.value) || 0;
    const N = parseInt(tenureInput.value, 10) || 0;

    if (P <= 0 || annualRate <= 0 || N <= 0) {
      emiDisplay.textContent = '₹0.00';
      if (totalRepayDisplay) totalRepayDisplay.textContent = '₹0.00';
      if (interestDisplay) interestDisplay.textContent = '₹0.00';
      return;
    }

    const r = (annualRate / 12) / 100;
    const factor = Math.pow(1 + r, N);
    const emi = (P * r * factor) / (factor - 1);
    const totalRepay = emi * N;
    const totalInterest = totalRepay - P;

    emiDisplay.textContent = '₹' + emi.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    if (totalRepayDisplay) {
      totalRepayDisplay.textContent = '₹' + totalRepay.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }
    if (interestDisplay) {
      interestDisplay.textContent = '₹' + totalInterest.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }
  }

  if (amountInput && rateInput && tenureInput) {
    amountInput.addEventListener('input', calculateEMI);
    rateInput.addEventListener('input', calculateEMI);
    tenureInput.addEventListener('change', calculateEMI);
    calculateEMI();
  }

  // 4. LenDenClub-Style Investment Returns Calculator (Home Page)
  const investSlider = document.getElementById('invest-amount-slider');
  const investAmountDisplay = document.getElementById('invest-amount-display');
  const tenurePills = document.querySelectorAll('.tenure-pill');
  const p2pReturnVal = document.getElementById('calc-p2p-returns');
  const p2pTotalVal = document.getElementById('calc-p2p-total');
  const fdReturnVal = document.getElementById('calc-fd-returns');
  const savingsReturnVal = document.getElementById('calc-savings-returns');
  const extraEarningsVal = document.getElementById('calc-extra-earnings');

  let selectedTenureMonths = 12;

  function updateInvestmentCalculator() {
    if (!investSlider || !investAmountDisplay || !p2pReturnVal) return;

    const principal = parseFloat(investSlider.value) || 50000;
    investAmountDisplay.textContent = '₹' + principal.toLocaleString('en-IN');

    const years = selectedTenureMonths / 12;

    // Rates: P2P ~ 12% p.a., Bank FD ~ 6.5% p.a., Savings ~ 3.5% p.a.
    const p2pRate = 0.12;
    const fdRate = 0.065;
    const savingsRate = 0.035;

    // Simple interest calculation for comparison
    const p2pInterest = principal * p2pRate * years;
    const p2pTotal = principal + p2pInterest;

    const fdInterest = principal * fdRate * years;
    const savingsInterest = principal * savingsRate * years;

    const extra = p2pInterest - fdInterest;

    p2pReturnVal.textContent = '₹' + Math.round(p2pInterest).toLocaleString('en-IN');
    if (p2pTotalVal) p2pTotalVal.textContent = '₹' + Math.round(p2pTotal).toLocaleString('en-IN');
    if (fdReturnVal) fdReturnVal.textContent = '₹' + Math.round(fdInterest).toLocaleString('en-IN');
    if (savingsReturnVal) savingsReturnVal.textContent = '₹' + Math.round(savingsInterest).toLocaleString('en-IN');
    if (extraEarningsVal) extraEarningsVal.textContent = '₹' + Math.round(extra).toLocaleString('en-IN');
  }

  if (investSlider) {
    investSlider.addEventListener('input', updateInvestmentCalculator);
  }

  if (tenurePills.length > 0) {
    tenurePills.forEach(pill => {
      pill.addEventListener('click', () => {
        tenurePills.forEach(p => p.classList.remove('active'));
        pill.classList.add('active');
        selectedTenureMonths = parseInt(pill.getAttribute('data-months'), 10) || 12;
        updateInvestmentCalculator();
      });
    });
    updateInvestmentCalculator();
  }

  // Preset buttons for calculator
  const presetBtns = document.querySelectorAll('.calc-preset-btn');
  if (presetBtns.length > 0) {
    presetBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const val = btn.getAttribute('data-amount');
        if (investSlider && val) {
          investSlider.value = val;
          updateInvestmentCalculator();
        }
      });
    });
  }

  // 5. How It Works Dual Tabs (Investors vs Borrowers)
  const tabBtns = document.querySelectorAll('.tab-btn');
  const workflowContents = document.querySelectorAll('.workflow-content');

  if (tabBtns.length > 0) {
    tabBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        tabBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        const targetId = btn.getAttribute('data-target');
        workflowContents.forEach(content => {
          content.style.display = content.id === targetId ? 'grid' : 'none';
        });
      });
    });
  }

  // 6. FAQ Accordion Toggle
  const faqItems = document.querySelectorAll('.faq-item');
  if (faqItems.length > 0) {
    faqItems.forEach(item => {
      const question = item.querySelector('.faq-question');
      if (question) {
        question.addEventListener('click', () => {
          const isOpen = item.classList.contains('open');
          faqItems.forEach(i => i.classList.remove('open'));
          if (!isOpen) {
            item.classList.add('open');
          }
        });
      }
    });
  }

  // 7. Auto-dismiss alerts after 6 seconds
  setTimeout(() => {
    const alerts = document.querySelectorAll('.alert');
    alerts.forEach((alert) => {
      alert.style.transition = 'opacity 0.4s ease';
      alert.style.opacity = '0';
      setTimeout(() => alert.remove(), 400);
    });
  }, 6000);

})();
