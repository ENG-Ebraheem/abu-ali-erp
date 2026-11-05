import 'package:sqflite/sqflite.dart';
import '../../constants/database_constants.dart';
import 'migration.dart';

/// Migration from schema Version 2 to Version 3.
///
/// Implements:
/// 1. Journal line directional integrity:
///    Enforces that debit and credit amounts cannot be mixed across foreign and base
///    currency columns while safely permitting legitimate small amounts that round to zero.
/// 2. Cash and bank account currency safety:
///    Enforces `CHECK (is_cash_bank = 0 OR currency_code IS NOT NULL)` and prevents
///    altering an account's currency after it has posted journal transactions.
/// 3. Opening invoices:
///    Extends invoice types to distinguish `OPENING_RECEIVABLE` (customers) and
///    `OPENING_PAYABLE` (suppliers) to support invoice-by-invoice opening balances
///    and payment allocations without double-counting against opening journal entries.
class MigrationV2ToV3 implements Migration {
  @override
  int get version => 3;

  @override
  String get description =>
      'V3 Refinements: Directional line integrity, cash account currency validation, and opening invoice classifications.';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // -----------------------------------------------------------------
    // 1. Journal Line Directional Integrity Triggers
    // -----------------------------------------------------------------
    // Blocks foreign-debit with base-credit or foreign-credit with base-debit.
    // Legitimate small amounts where base amount rounds to 0 are safely permitted.
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_journal_entry_lines_directional_integrity_ins
      BEFORE INSERT ON ${DatabaseConstants.tableJournalEntryLines}
      FOR EACH ROW
      WHEN (NEW.foreign_debit > 0 AND NEW.base_credit > 0) OR (NEW.foreign_credit > 0 AND NEW.base_debit > 0)
      BEGIN
        SELECT RAISE(ABORT, 'Journal line directional mismatch: debit and credit cannot be mixed across foreign and base amounts.');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_journal_entry_lines_directional_integrity_upd
      BEFORE UPDATE ON ${DatabaseConstants.tableJournalEntryLines}
      FOR EACH ROW
      WHEN (NEW.foreign_debit > 0 AND NEW.base_credit > 0) OR (NEW.foreign_credit > 0 AND NEW.base_debit > 0)
      BEGIN
        SELECT RAISE(ABORT, 'Journal line directional mismatch: debit and credit cannot be mixed across foreign and base amounts.');
      END;
    ''');

    // -----------------------------------------------------------------
    // 2. Cash and Bank Account Currency Triggers
    // -----------------------------------------------------------------
    // Enforces: CHECK (is_cash_bank = 0 OR currency_code IS NOT NULL)
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_chart_of_accounts_cash_bank_currency_ins
      BEFORE INSERT ON ${DatabaseConstants.tableChartOfAccounts}
      FOR EACH ROW
      WHEN NEW.is_cash_bank = 1 AND NEW.currency_code IS NULL
      BEGIN
        SELECT RAISE(ABORT, 'Cash and bank accounts must have an assigned currency_code (CHECK: is_cash_bank = 0 OR currency_code IS NOT NULL).');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_chart_of_accounts_cash_bank_currency_upd
      BEFORE UPDATE ON ${DatabaseConstants.tableChartOfAccounts}
      FOR EACH ROW
      WHEN NEW.is_cash_bank = 1 AND NEW.currency_code IS NULL
      BEGIN
        SELECT RAISE(ABORT, 'Cash and bank accounts must have an assigned currency_code (CHECK: is_cash_bank = 0 OR currency_code IS NOT NULL).');
      END;
    ''');

    // Prevents changing currency of cash/bank accounts with posted transactions
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_chart_of_accounts_prevent_currency_change_with_transactions
      BEFORE UPDATE OF currency_code ON ${DatabaseConstants.tableChartOfAccounts}
      FOR EACH ROW
      WHEN OLD.is_cash_bank = 1 
        AND OLD.currency_code IS NOT NULL 
        AND NEW.currency_code != OLD.currency_code 
        AND (
          EXISTS (
            SELECT 1 
            FROM ${DatabaseConstants.tableJournalEntryLines} jel 
            JOIN ${DatabaseConstants.tableJournalEntries} je ON jel.journal_entry_id = je.id 
            WHERE jel.account_id = OLD.id AND je.status = 'POSTED'
          )
        )
      BEGIN
        SELECT RAISE(ABORT, 'Cannot change the currency of a cash or bank account with posted transactions.');
      END;
    ''');

    // -----------------------------------------------------------------
    // 3. Opening Invoices (Table Schema Evolution & Party Type Guards)
    // -----------------------------------------------------------------
    // Temporarily disable foreign keys during the table rebuild to ensure
    // child records (e.g. invoice_lines) are not affected by cascading actions.
    await db.execute('PRAGMA foreign_keys = OFF;');

    // Safely upgrade the invoices table CHECK constraint to include
    // OPENING_RECEIVABLE and OPENING_PAYABLE without data loss.
    await db.execute('''
      CREATE TABLE invoices_v3 (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        party_id TEXT NOT NULL,
        journal_entry_id TEXT,
        invoice_type TEXT NOT NULL,
        invoice_number TEXT NOT NULL,
        issue_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        currency_code TEXT NOT NULL,
        exchange_rate_scaled INTEGER NOT NULL,
        subtotal INTEGER NOT NULL DEFAULT 0,
        tax_amount INTEGER NOT NULL DEFAULT 0,
        discount_amount INTEGER NOT NULL DEFAULT 0,
        total_amount INTEGER NOT NULL DEFAULT 0,
        paid_amount INTEGER NOT NULL DEFAULT 0,
        payment_status TEXT NOT NULL DEFAULT 'UNPAID',
        status TEXT NOT NULL DEFAULT 'DRAFT',
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (id),
        UNIQUE (id, organization_id),
        UNIQUE (organization_id, invoice_type, invoice_number),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (party_id, organization_id) REFERENCES ${DatabaseConstants.tableParties} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (journal_entry_id, organization_id) REFERENCES ${DatabaseConstants.tableJournalEntries} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (currency_code) REFERENCES ${DatabaseConstants.tableCurrencies} (code) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (invoice_type IN ('SALES', 'PURCHASE', 'SALES_RETURN', 'PURCHASE_RETURN', 'OPENING_RECEIVABLE', 'OPENING_PAYABLE')),
        CHECK (status IN ('DRAFT', 'POSTED', 'CANCELLED')),
        CHECK (payment_status IN ('UNPAID', 'PARTIALLY_PAID', 'PAID')),
        CHECK (exchange_rate_scaled > 0),
        CHECK (total_amount >= 0),
        CHECK (paid_amount >= 0),
        CHECK (paid_amount <= total_amount)
      );
    ''');

    // Copy existing data, swap tables, and recreate indexes
    await db.execute(
        'INSERT INTO invoices_v3 SELECT * FROM ${DatabaseConstants.tableInvoices};');
    await db.execute('DROP TABLE ${DatabaseConstants.tableInvoices};');
    await db.execute(
        'ALTER TABLE invoices_v3 RENAME TO ${DatabaseConstants.tableInvoices};');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_invoices_org_party 
      ON ${DatabaseConstants.tableInvoices} (organization_id, party_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_invoices_due_status 
      ON ${DatabaseConstants.tableInvoices} (organization_id, due_date, payment_status);
    ''');
    await db.execute('PRAGMA foreign_keys = ON;');

    // Enforce that OPENING_RECEIVABLE is only for CUSTOMER / BOTH
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_invoices_validate_opening_receivable_ins
      BEFORE INSERT ON ${DatabaseConstants.tableInvoices}
      FOR EACH ROW
      WHEN NEW.invoice_type = 'OPENING_RECEIVABLE' AND (
        (SELECT party_type FROM ${DatabaseConstants.tableParties} WHERE id = NEW.party_id) NOT IN ('CUSTOMER', 'BOTH')
      )
      BEGIN
        SELECT RAISE(ABORT, 'Opening receivables (OPENING_RECEIVABLE) must be assigned to a party of type CUSTOMER or BOTH.');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_invoices_validate_opening_receivable_upd
      BEFORE UPDATE ON ${DatabaseConstants.tableInvoices}
      FOR EACH ROW
      WHEN NEW.invoice_type = 'OPENING_RECEIVABLE' AND (
        (SELECT party_type FROM ${DatabaseConstants.tableParties} WHERE id = NEW.party_id) NOT IN ('CUSTOMER', 'BOTH')
      )
      BEGIN
        SELECT RAISE(ABORT, 'Opening receivables (OPENING_RECEIVABLE) must be assigned to a party of type CUSTOMER or BOTH.');
      END;
    ''');

    // Enforce that OPENING_PAYABLE is only for SUPPLIER / BOTH
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_invoices_validate_opening_payable_ins
      BEFORE INSERT ON ${DatabaseConstants.tableInvoices}
      FOR EACH ROW
      WHEN NEW.invoice_type = 'OPENING_PAYABLE' AND (
        (SELECT party_type FROM ${DatabaseConstants.tableParties} WHERE id = NEW.party_id) NOT IN ('SUPPLIER', 'BOTH')
      )
      BEGIN
        SELECT RAISE(ABORT, 'Opening payables (OPENING_PAYABLE) must be assigned to a party of type SUPPLIER or BOTH.');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_invoices_validate_opening_payable_upd
      BEFORE UPDATE ON ${DatabaseConstants.tableInvoices}
      FOR EACH ROW
      WHEN NEW.invoice_type = 'OPENING_PAYABLE' AND (
        (SELECT party_type FROM ${DatabaseConstants.tableParties} WHERE id = NEW.party_id) NOT IN ('SUPPLIER', 'BOTH')
      )
      BEGIN
        SELECT RAISE(ABORT, 'Opening payables (OPENING_PAYABLE) must be assigned to a party of type SUPPLIER or BOTH.');
      END;
    ''');
  }
}
