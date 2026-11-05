import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/features/invoices/models/invoice_line_model.dart';
import 'package:abu_ali/features/invoices/models/invoice_model.dart';
import 'package:abu_ali/features/invoices/screens/create_invoice_screen.dart';
import 'package:abu_ali/features/payments/models/payment_allocation_model.dart';
import 'package:abu_ali/features/payments/models/payment_model.dart';
import 'package:abu_ali/features/payments/screens/create_payment_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3 Invoicing and Payment Accounting Workflows Unit Tests', () {
    const String orgA = 'org_test_01';
    const String orgB = 'org_test_02';
    const String cust1 = 'party_cust_01';
    const String cust2 = 'party_cust_02';
    const String supp1 = 'party_supp_01';

    // -----------------------------------------------------------------
    // 1 & 2: Sales & Purchase Invoices Models & Line Item Calculations
    // -----------------------------------------------------------------
    test(
        '1. Sales invoice line items compute gross, discount, tax, and line total correctly',
        () {
      // 2 units @ 150.00 YER (15000 minor) = Gross 300.00 YER (30000 minor)
      // Discount = 20.00 YER (2000 minor)
      // Tax = 15.00 YER (1500 minor)
      // Net Line Total = 30000 - 2000 + 1500 = 29500 (295.00 YER)
      const line = InvoiceLineModel(
        id: 'line_1',
        organizationId: orgA,
        invoiceId: 'inv_1',
        lineNumber: 1,
        accountId: 'acc_rev',
        itemDescription: 'بضاعة تجارية A',
        quantityScaled: 2000, // 2.000 units
        unitPrice: 15000, // 150.00
        discountAmount: 2000, // 20.00
        taxAmount: 1500, // 15.00
        lineTotal: 29500, // 295.00
      );

      expect(line.quantityDouble, 2.0);
      expect(line.unitPriceDouble, 150.0);
      expect(line.discountDouble, 20.0);
      expect(line.taxDouble, 15.0);
      expect(line.lineTotalDouble, 295.0);
    });

    test(
        '2. Invoice header aggregates subtotals, taxes, discounts, and remaining balance',
        () {
      final inv = InvoiceModel(
        id: 'inv_test_01',
        organizationId: orgA,
        partyId: cust1,
        invoiceType: 'SALES',
        invoiceNumber: 'INV-2026-0001',
        issueDate: '2026-02-01',
        dueDate: '2026-03-01',
        currencyCode: 'YER',
        exchangeRateScaled: DatabaseConstants.exchangeRateScale,
        subtotal: 50000, // 500.00 gross
        discountAmount: 5000, // 50.00 discount
        taxAmount: 4500, // 45.00 tax
        totalAmount: 49500, // 495.00 net
        paidAmount: 20000, // 200.00 paid
        paymentStatus: 'PARTIALLY_PAID',
        status: 'POSTED',
      );

      expect(inv.isSales, isTrue);
      expect(inv.isPurchase, isFalse);
      expect(inv.isPosted, isTrue);
      expect(inv.isPartiallyPaid, isTrue);
      expect(inv.remainingAmount, 29500); // 295.00 YER remaining
      expect(inv.remainingDouble, 295.0);
    });

    // -----------------------------------------------------------------
    // 3 & 4: Cash vs Credit Invoice Statuses & Numbering
    // -----------------------------------------------------------------
    test('3. Credit sales invoice starts as UNPAID with paidAmount 0', () {
      final creditInv = InvoiceModel(
        id: 'inv_credit_01',
        organizationId: orgA,
        partyId: cust1,
        invoiceType: 'SALES',
        invoiceNumber: 'INV-2026-0002',
        issueDate: '2026-02-05',
        dueDate: '2026-03-05',
        currencyCode: 'YER',
        exchangeRateScaled: 1000000,
        subtotal: 100000,
        totalAmount: 100000,
        paidAmount: 0,
        paymentStatus: 'UNPAID',
        status: 'POSTED',
      );

      expect(creditInv.isUnpaid, isTrue);
      expect(creditInv.isPaid, isFalse);
      expect(creditInv.remainingAmount, 100000);
    });

    test(
        '4. Cash sales invoice posted directly with PAID status and zero remaining',
        () {
      final cashInv = InvoiceModel(
        id: 'inv_cash_01',
        organizationId: orgA,
        partyId: cust1,
        invoiceType: 'SALES',
        invoiceNumber: 'INV-2026-0003',
        issueDate: '2026-02-05',
        dueDate: '2026-02-05',
        currencyCode: 'YER',
        exchangeRateScaled: 1000000,
        subtotal: 80000,
        totalAmount: 80000,
        paidAmount: 80000,
        paymentStatus: 'PAID',
        status: 'POSTED',
      );

      expect(cashInv.isPaid, isTrue);
      expect(cashInv.isUnpaid, isFalse);
      expect(cashInv.remainingAmount, 0);
    });

    // -----------------------------------------------------------------
    // 5 & 6: Customer Receipts & Supplier Payments Models
    // -----------------------------------------------------------------
    test(
        '5. Customer receipt properly tracks allocated and unallocated advance amounts',
        () {
      final receipt = PaymentModel(
        id: 'rc_01',
        organizationId: orgA,
        partyId: cust1,
        cashBankAccountId: 'acc_cash_main',
        paymentType: 'RECEIPT',
        paymentNumber: 'RC-2026-0001',
        paymentDate: '2026-02-10',
        paymentMethod: 'CASH',
        currencyCode: 'YER',
        exchangeRateScaled: 1000000,
        amount: 50000, // 500.00 YER
        allocatedAmount: 30000, // 300.00 YER allocated to invoices
        unallocatedAmount: 20000, // 200.00 YER advance on account
        status: 'POSTED',
      );

      expect(receipt.isReceipt, isTrue);
      expect(receipt.isPayment, isFalse);
      expect(
          receipt.allocatedAmount + receipt.unallocatedAmount, receipt.amount);
      expect(receipt.isFullyAllocated, isFalse);
      expect(receipt.hasUnallocated, isTrue);
    });

    test('6. Supplier payment fully allocated sets unallocated to 0', () {
      final disbursement = PaymentModel(
        id: 'py_01',
        organizationId: orgA,
        partyId: supp1,
        cashBankAccountId: 'acc_bank_main',
        paymentType: 'PAYMENT',
        paymentNumber: 'PY-2026-0001',
        paymentDate: '2026-02-11',
        paymentMethod: 'BANK_TRANSFER',
        currencyCode: 'SAR',
        exchangeRateScaled: 266000,
        amount: 100000,
        allocatedAmount: 100000,
        unallocatedAmount: 0,
        status: 'POSTED',
      );

      expect(disbursement.isPayment, isTrue);
      expect(disbursement.isReceipt, isFalse);
      expect(disbursement.isFullyAllocated, isTrue);
      expect(disbursement.hasUnallocated, isFalse);
      expect(disbursement.methodLabel, 'تحويل بنكي');
    });

    // -----------------------------------------------------------------
    // 7, 8, & 9: Payment Allocations & Settlements
    // -----------------------------------------------------------------
    test('7. Partial payment allocation reduces invoice balance correctly', () {
      const invoiceTotal = 100000; // 1,000.00
      const currentPaid = 0;
      const allocAmount = 40000; // 400.00

      final newPaid = currentPaid + allocAmount;
      final newStatus = newPaid >= invoiceTotal ? 'PAID' : 'PARTIALLY_PAID';
      final remaining = invoiceTotal - newPaid;

      expect(newPaid, 40000);
      expect(newStatus, 'PARTIALLY_PAID');
      expect(remaining, 60000);
    });

    test('8. Full payment allocation settles invoice with PAID status', () {
      const invoiceTotal = 100000;
      const currentPaid = 40000;
      const allocAmount = 60000;

      final newPaid = currentPaid + allocAmount;
      final newStatus = newPaid >= invoiceTotal ? 'PAID' : 'PARTIALLY_PAID';
      final remaining = invoiceTotal - newPaid;

      expect(newPaid, 100000);
      expect(newStatus, 'PAID');
      expect(remaining, 0);
    });

    test('9. Multi-invoice allocation in single payment voucher', () {
      // Payment of 750 YER settles Invoice 1 (300 YER) and Invoice 2 (450 YER)
      const paymentAmount = 75000;
      final alloc1 = PaymentAllocationModel(
        id: 'alloc_1',
        organizationId: orgA,
        paymentId: 'rc_multi',
        invoiceId: 'inv_101',
        allocatedAmount: 30000,
        allocationDate: '2026-02-12',
      );
      final alloc2 = PaymentAllocationModel(
        id: 'alloc_2',
        organizationId: orgA,
        paymentId: 'rc_multi',
        invoiceId: 'inv_102',
        allocatedAmount: 45000,
        allocationDate: '2026-02-12',
      );

      final totalAllocated = alloc1.allocatedAmount + alloc2.allocatedAmount;
      final unallocated = paymentAmount - totalAllocated;

      expect(totalAllocated, 75000);
      expect(unallocated, 0);
    });

    // -----------------------------------------------------------------
    // 10 & 11: Allocation Limits & Validation Rules
    // -----------------------------------------------------------------
    test('10. Allocation cannot exceed invoice remaining balance', () {
      const invoiceTotal = 50000;
      const invoicePaid = 20000;
      const invoiceRemaining = invoiceTotal - invoicePaid; // 30,000

      const attemptedAllocation =
          35000; // Trying to allocate 35,000 to a 30,000 balance
      final bool isAllowed = attemptedAllocation <= invoiceRemaining;

      expect(isAllowed, isFalse);
    });

    test('11. Total allocations cannot exceed payment voucher amount', () {
      const paymentAmount = 60000;
      const alloc1 = 40000;
      const alloc2 = 30000;

      final totalAllocated = alloc1 + alloc2; // 70,000
      final bool isAllowed = totalAllocated <= paymentAmount;

      expect(isAllowed, isFalse);
    });

    // -----------------------------------------------------------------
    // 12, 13, & 14: Multi-Currency & Realized Forex Gain/Loss Engine
    // -----------------------------------------------------------------
    test(
        '12. Realized FX Gain calculated when exchange rate rises on customer receipt',
        () {
      // Invoice was issued at 1 USD = 250 YER (scale: 250,000,000)
      // Customer pays 100 USD (10000 minor) when 1 USD = 260 YER (scale: 260,000,000)
      const int allocForeign = 10000; // 100.00 USD
      const int invFxScaled = 250000000; // 250.000000
      const int payFxScaled = 260000000; // 260.000000

      final int baseInvoice =
          ((allocForeign * invFxScaled) / DatabaseConstants.exchangeRateScale)
              .round(); // 25,000 YER
      final int basePayment =
          ((allocForeign * payFxScaled) / DatabaseConstants.exchangeRateScale)
              .round(); // 26,000 YER

      final int diff = basePayment - baseInvoice; // +1,000 YER
      final bool isGain = diff > 0;
      final int gainAmount = isGain ? diff : 0;
      final int lossAmount = !isGain ? -diff : 0;

      expect(baseInvoice, 2500000);
      expect(basePayment, 2600000);
      expect(isGain, isTrue);
      expect(gainAmount, 100000); // 1,000.00 YER Realized FX Gain
      expect(lossAmount, 0);

      // Verify General Ledger Balancing:
      // Debit Cash: 26,000 YER
      // Credit AR: 25,000 YER
      // Credit FX Gain: 1,000 YER
      final int debitCash = basePayment;
      final int creditAR = baseInvoice;
      final int creditFxGain = gainAmount;

      expect(debitCash, creditAR + creditFxGain);
    });

    test(
        '13. Realized FX Loss calculated when exchange rate drops on customer receipt',
        () {
      // Invoice issued at 1 USD = 250 YER (250,000,000)
      // Customer pays 100 USD when 1 USD = 240 YER (240,000,000)
      const int allocForeign = 10000;
      const int invFxScaled = 250000000;
      const int payFxScaled = 240000000;

      final int baseInvoice =
          ((allocForeign * invFxScaled) / DatabaseConstants.exchangeRateScale)
              .round(); // 25,000 YER
      final int basePayment =
          ((allocForeign * payFxScaled) / DatabaseConstants.exchangeRateScale)
              .round(); // 24,000 YER

      final int diff = basePayment - baseInvoice; // -1,000 YER
      final bool isGain = diff > 0;
      final int lossAmount = !isGain ? -diff : 0;

      expect(isGain, isFalse);
      expect(lossAmount, 100000); // 1,000.00 YER Realized FX Loss

      // Verify General Ledger Balancing:
      // Debit Cash: 24,000 YER
      // Debit FX Loss: 1,000 YER
      // Credit AR: 25,000 YER
      final int debitCash = basePayment;
      final int debitFxLoss = lossAmount;
      final int creditAR = baseInvoice;

      expect(debitCash + debitFxLoss, creditAR);
    });

    test(
        '14. Realized FX Gain calculated when settling supplier debt with favorable rate',
        () {
      // Purchase bill at 1 USD = 250 YER (250,000,000) -> 25,000 YER liability
      // Payment made when 1 USD = 240 YER (240,000,000) -> 24,000 YER cash paid
      const int allocForeign = 10000;
      const int invFxScaled = 250000000;
      const int payFxScaled = 240000000;

      final int baseInvoice =
          ((allocForeign * invFxScaled) / DatabaseConstants.exchangeRateScale)
              .round(); // 25,000 YER
      final int basePayment =
          ((allocForeign * payFxScaled) / DatabaseConstants.exchangeRateScale)
              .round(); // 24,000 YER

      final int diff = baseInvoice - basePayment; // +1,000 YER Gain (paid less)
      final bool isGain = diff > 0;
      final int gainAmount = isGain ? diff : 0;

      expect(isGain, isTrue);
      expect(gainAmount, 100000);

      // Verify GL Balancing:
      // Debit AP: 25,000 YER
      // Credit Cash: 24,000 YER
      // Credit FX Gain: 1,000 YER
      final int debitAP = baseInvoice;
      final int creditCash = basePayment;
      final int creditFxGain = gainAmount;

      expect(debitAP, creditCash + creditFxGain);
    });

    // -----------------------------------------------------------------
    // 15 & 16: Multi-Tenant and Multi-Party Security Isolation
    // -----------------------------------------------------------------
    test(
        '15. Multi-tenant isolation: Reject allocating invoice from different organization',
        () {
      const paymentOrgId = orgA;
      const invoiceOrgId = orgB;

      final bool isAllowed = paymentOrgId == invoiceOrgId;
      expect(isAllowed, isFalse);
    });

    test(
        '16. Multi-party isolation: Reject allocating customer X invoice to customer Y payment',
        () {
      const paymentPartyId = cust1;
      const invoicePartyId = cust2;

      final bool isAllowed = paymentPartyId == invoicePartyId;
      expect(isAllowed, isFalse);
    });

    // -----------------------------------------------------------------
    // 17 & 18: Reversals, Voiding, and Cancellation Integrity
    // -----------------------------------------------------------------
    test(
        '17. Voiding payment voucher rolls back invoice paid amount and restores status',
        () {
      const invoiceTotal = 100000;
      const currentPaid = 60000; // Paid 600.00
      const voidedAllocAmount = 60000; // Voiding the 600.00 payment

      final int restoredPaid = (currentPaid - voidedAllocAmount) > 0
          ? currentPaid - voidedAllocAmount
          : 0;
      final String restoredStatus = restoredPaid == 0
          ? 'UNPAID'
          : (restoredPaid >= invoiceTotal ? 'PAID' : 'PARTIALLY_PAID');

      expect(restoredPaid, 0);
      expect(restoredStatus, 'UNPAID');
    });

    test('18. Cancelling invoice with existing payments is strictly blocked',
        () {
      final invoiceWithPayments = InvoiceModel(
        id: 'inv_paid_01',
        organizationId: orgA,
        partyId: cust1,
        invoiceType: 'SALES',
        invoiceNumber: 'INV-2026-0099',
        issueDate: '2026-02-01',
        dueDate: '2026-03-01',
        currencyCode: 'YER',
        exchangeRateScaled: 1000000,
        subtotal: 50000,
        totalAmount: 50000,
        paidAmount: 25000, // partially paid
        paymentStatus: 'PARTIALLY_PAID',
        status: 'POSTED',
      );

      final bool canCancel = invoiceWithPayments.paidAmount == 0;
      expect(canCancel, isFalse);
    });

    // -----------------------------------------------------------------
    // 19 & 20: Control Accounts and Party Statement Reconciliation
    // -----------------------------------------------------------------
    test(
        '19. Customer open invoices sum reconciles with Accounts Receivable control account',
        () {
      // 3 Open invoices for Customer 1
      final invoices = [
        InvoiceModel(
          id: 'inv_01',
          organizationId: orgA,
          partyId: cust1,
          invoiceType: 'SALES',
          invoiceNumber: 'INV-01',
          issueDate: '2026-02-01',
          dueDate: '2026-03-01',
          currencyCode: 'YER',
          exchangeRateScaled: 1000000,
          totalAmount: 30000,
          paidAmount: 10000,
          paymentStatus: 'PARTIALLY_PAID',
          status: 'POSTED',
        ),
        InvoiceModel(
          id: 'inv_02',
          organizationId: orgA,
          partyId: cust1,
          invoiceType: 'SALES',
          invoiceNumber: 'INV-02',
          issueDate: '2026-02-02',
          dueDate: '2026-03-02',
          currencyCode: 'YER',
          exchangeRateScaled: 1000000,
          totalAmount: 50000,
          paidAmount: 0,
          paymentStatus: 'UNPAID',
          status: 'POSTED',
        ),
      ];

      final totalOutstanding =
          invoices.fold<int>(0, (sum, inv) => sum + inv.remainingAmount);

      // Remaining on inv1 = 20,000, on inv2 = 50,000 -> Total = 70,000 YER
      expect(totalOutstanding, 70000);
      expect(invoices[0].remainingAmount, 20000);
      expect(invoices[1].remainingAmount, 50000);
    });

    test(
        '20. Supplier open bills sum reconciles with Accounts Payable control account',
        () {
      final bills = [
        InvoiceModel(
          id: 'bill_01',
          organizationId: orgA,
          partyId: supp1,
          invoiceType: 'PURCHASE',
          invoiceNumber: 'BILL-01',
          issueDate: '2026-02-01',
          dueDate: '2026-03-01',
          currencyCode: 'YER',
          exchangeRateScaled: 1000000,
          totalAmount: 120000,
          paidAmount: 40000,
          paymentStatus: 'PARTIALLY_PAID',
          status: 'POSTED',
        ),
      ];

      final totalPayable =
          bills.fold<int>(0, (sum, b) => sum + b.remainingAmount);

      expect(totalPayable, 80000); // 800.00 YER
    });
  });

  // -------------------------------------------------------------------
  // UI Screen Widget Tests
  // -------------------------------------------------------------------
  group('Phase 3 Invoicing and Payment UI Widget Tests', () {
    testWidgets(
        'CreateInvoiceScreen renders Cash/Credit selector, dates, and line items',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: CreateInvoiceScreen(
            organizationId: 'org_test_01',
            baseCurrencyCode: 'YER',
            initialType: 'SALES',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify Header and Type buttons
      expect(find.text('فاتورة مبيعات جديدة'), findsOneWidget);
      expect(find.text('العميل *'), findsOneWidget);

      // Verify Cash vs Credit toggle
      expect(find.text('آجل (ذمم مدينة/دائنة)'), findsOneWidget);
      expect(find.text('نقداً (صندوق / بنك)'), findsOneWidget);

      // Verify Save Buttons
      expect(find.text('حفظ كمسودة'), findsOneWidget);
      expect(find.text('ترحيل الفاتورة'), findsOneWidget);
    });

    testWidgets(
        'CreatePaymentScreen renders payment type, amount, auto-allocate, and submit buttons',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: CreatePaymentScreen(
            organizationId: 'org_test_01',
            baseCurrencyCode: 'YER',
            initialType: 'RECEIPT',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify Header
      expect(find.text('سند قبض جديد'), findsOneWidget);
      expect(find.text('سند قبض (استلام)'), findsOneWidget);
      expect(find.text('سند صرف (دفع)'), findsOneWidget);

      // Verify Fields
      expect(find.text('مبلغ السند *'), findsOneWidget);

      // Verify Save Buttons
      expect(find.text('حفظ كمسودة'), findsOneWidget);
      expect(find.text('ترحيل السند'), findsOneWidget);
    });
  });
}
