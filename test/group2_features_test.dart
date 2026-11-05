import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/features/invoices/models/invoice_line_model.dart';
import 'package:abu_ali/features/invoices/models/invoice_model.dart';
import 'package:abu_ali/features/journal/models/journal_entry_line_model.dart';
import 'package:abu_ali/features/journal/models/journal_entry_model.dart';
import 'package:abu_ali/features/payments/models/payment_allocation_model.dart';
import 'package:abu_ali/features/payments/models/payment_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group 2: Journal Entries Models', () {
    test('JournalEntryModel correctly checks balancing and labels', () {
      final entry = JournalEntryModel(
        id: 'je_1',
        organizationId: 'org_main',
        entryNumber: 'JV-2026-0001',
        fiscalPeriodId: 'fp_1',
        entryDate: '2026-11-01',
        entryType: 'GENERAL',
        status: 'POSTED',
        narration: 'قيد رواتب شهر نوفمبر',
        totalBaseDebit: 15000000, // 150,000.00
        totalBaseCredit: 15000000,
        postedAt: '2026-11-01T10:00:00Z',
      );

      expect(entry.isBalanced, isTrue);
      expect(entry.isPosted, isTrue);
      expect(entry.isDraft, isFalse);
      expect(entry.totalBaseDebitDouble, 150000.0);
      expect(entry.typeLabel, 'قيد يومية عام');
      expect(entry.statusLabel, 'مرحّل');

      final map = entry.toMap();
      expect(map['entry_number'], 'JV-2026-0001');
      expect(map['total_base_debit'], 15000000);

      final restored = JournalEntryModel.fromMap(map);
      expect(restored.isBalanced, isTrue);
      expect(restored.narration, 'قيد رواتب شهر نوفمبر');
    });

    test('JournalEntryLineModel handles foreign currencies and scales', () {
      final line = JournalEntryLineModel(
        id: 'jel_1',
        organizationId: 'org_main',
        journalEntryId: 'je_1',
        lineNumber: 1,
        accountId: 'acc_cash',
        currencyCode: 'USD',
        exchangeRateScaled: 535500000, // 535.500000
        foreignDebit: 10000, // $100.00
        foreignCredit: 0,
        baseDebit: 5355000, // 53,550.00 YER
        baseCredit: 0,
      );

      expect(line.isDebit, isTrue);
      expect(line.isCredit, isFalse);
      expect(line.foreignDebitDouble, 100.0);
      expect(line.baseDebitDouble, 53550.0);
      expect(line.exchangeRateDouble, closeTo(535.5, 0.0001));
    });
  });

  group('Group 2: Invoices Models', () {
    test(
        'InvoiceModel distinguishes sales and purchases and calculates balance due',
        () {
      final inv = InvoiceModel(
        id: 'inv_1',
        organizationId: 'org_main',
        partyId: 'cust_1',
        invoiceType: 'SALES',
        invoiceNumber: 'INV-2026-0001',
        issueDate: '2026-11-01',
        dueDate: '2026-11-30',
        currencyCode: 'YER',
        exchangeRateScaled: 1000000,
        subtotal: 5000000,
        totalAmount: 5000000, // 50,000.00
        paidAmount: 2000000, // 20,000.00
        paymentStatus: 'PARTIALLY_PAID',
        status: 'POSTED',
      );

      expect(inv.isSales, isTrue);
      expect(inv.isPurchase, isFalse);
      expect(inv.isPartiallyPaid, isTrue);
      expect(inv.isPaid, isFalse);
      expect(inv.remainingAmount, 3000000); // 30,000.00
      expect(inv.remainingDouble, 30000.0);
      expect(inv.typeLabel, 'فاتورة مبيعات');
      expect(inv.paymentStatusLabel, 'مدفوعة جزئياً');
    });

    test('InvoiceLineModel calculates minor unit conversions', () {
      final line = InvoiceLineModel(
        id: 'il_1',
        organizationId: 'org_main',
        invoiceId: 'inv_1',
        lineNumber: 1,
        accountId: 'acc_sales',
        itemDescription: 'شاشات سامسونج',
        quantityScaled: 2000, // 2.000
        unitPrice: 2500000, // 25,000.00
        lineTotal: 5000000, // 50,000.00
      );

      expect(line.quantityDouble, 2.0);
      expect(line.unitPriceDouble, 25000.0);
      expect(line.lineTotalDouble, 50000.0);
    });
  });

  group('Group 2: Payments & Allocations Models', () {
    test('PaymentModel handles receipt and disbursements properly', () {
      final payment = PaymentModel(
        id: 'pay_1',
        organizationId: 'org_main',
        partyId: 'cust_1',
        cashBankAccountId: 'acc_cash',
        paymentType: 'RECEIPT',
        paymentNumber: 'RC-2026-0001',
        paymentDate: '2026-11-01',
        paymentMethod: 'CASH',
        currencyCode: 'YER',
        exchangeRateScaled: 1000000,
        amount: 3000000, // 30,000.00
        allocatedAmount: 2000000,
        unallocatedAmount: 1000000,
        status: 'POSTED',
      );

      expect(payment.isReceipt, isTrue);
      expect(payment.isPayment, isFalse);
      expect(payment.typeLabel, 'سند قبض');
      expect(payment.methodLabel, 'نقداً');
      expect(payment.amountDouble, 30000.0);
      expect(payment.allocatedDouble, 20000.0);
      expect(payment.unallocatedDouble, 10000.0);
    });

    test('PaymentAllocationModel correctly maps invoice allocation', () {
      final alloc = PaymentAllocationModel(
        id: 'alloc_1',
        organizationId: 'org_main',
        paymentId: 'pay_1',
        invoiceId: 'inv_1',
        allocatedAmount: 2000000,
        allocationDate: '2026-11-01',
        invoiceNumber: 'INV-2026-0001',
      );

      expect(alloc.allocatedAmountDouble, 20000.0);
      expect(alloc.invoiceNumber, 'INV-2026-0001');

      final map = alloc.toMap();
      expect(map['allocated_amount'], 2000000);
      expect(map['payment_id'], 'pay_1');
    });
  });
}
