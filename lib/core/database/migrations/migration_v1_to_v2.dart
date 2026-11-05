import 'package:sqflite/sqflite.dart';
import '../../constants/database_constants.dart';
import 'migration.dart';

/// Migration from schema Version 1 to Version 2.
///
/// Introduces:
/// - Core multi-tenant architecture with composite foreign keys.
/// - Currencies with fixed-point exchange rate scale of 1,000,000.
/// - Chart of Accounts with recursive hierarchy.
/// - Fiscal years and periods.
/// - Immutable double-entry general ledger with balanced base-currency enforcement.
/// - Parties, Invoices, Payments, and Payment Allocations.
/// - Opening balances, Forex revaluation, App settings, and Audit logging.
/// - Fully compatible with SQLite 3.32.2.
class MigrationV1ToV2 implements Migration {
  @override
  int get version => 2;

  @override
  String get description =>
      'Initial full accounting schema with multi-organization support, double-entry GL, multi-currency, and audit trail.';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Currencies (Global reference table)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableCurrencies} (
        code TEXT NOT NULL PRIMARY KEY,
        name_ar TEXT NOT NULL,
        name_en TEXT NOT NULL,
        symbol TEXT NOT NULL,
        decimal_places INTEGER NOT NULL DEFAULT 2,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        CHECK (decimal_places >= 0 AND decimal_places <= 4),
        CHECK (is_active IN (0, 1))
      );
    ''');

    // 2. Organizations (Tenant master)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableOrganizations} (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        base_currency_code TEXT NOT NULL,
        tax_number TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        UNIQUE (id),
        UNIQUE (code),
        FOREIGN KEY (base_currency_code) REFERENCES ${DatabaseConstants.tableCurrencies} (code) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (is_active IN (0, 1))
      );
    ''');

    // 3. Exchange Rates (Historical FX rates per organization)
    // Scale: 1.000000 = 1,000,000
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableExchangeRates} (
        id TEXT NOT NULL PRIMARY KEY,
        organization_id TEXT NOT NULL,
        from_currency_code TEXT NOT NULL,
        to_currency_code TEXT NOT NULL,
        rate_scaled INTEGER NOT NULL,
        rate_date TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        UNIQUE (id, organization_id),
        UNIQUE (organization_id, from_currency_code, to_currency_code, rate_date),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (from_currency_code) REFERENCES ${DatabaseConstants.tableCurrencies} (code) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (to_currency_code) REFERENCES ${DatabaseConstants.tableCurrencies} (code) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (rate_scaled > 0),
        CHECK (from_currency_code != to_currency_code)
      );
    ''');

    // 4. Application Settings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableAppSettings} (
        id TEXT NOT NULL PRIMARY KEY,
        organization_id TEXT,
        setting_key TEXT NOT NULL,
        setting_value TEXT NOT NULL,
        data_type TEXT NOT NULL DEFAULT 'STRING',
        description TEXT,
        updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE CASCADE,
        CHECK (data_type IN ('STRING', 'INT', 'BOOL', 'JSON'))
      );
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_app_settings_org_key
      ON ${DatabaseConstants.tableAppSettings} (COALESCE(organization_id, 'GLOBAL'), setting_key);
    ''');

    // 5. Audit Logs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableAuditLogs} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        organization_id TEXT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        action TEXT NOT NULL,
        old_values TEXT,
        new_values TEXT,
        user_id TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE SET NULL,
        CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'POST', 'VOID'))
      );
    ''');

    // 6. Chart of Accounts
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableChartOfAccounts} (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        account_code TEXT NOT NULL,
        account_name_ar TEXT NOT NULL,
        account_name_en TEXT,
        account_type TEXT NOT NULL,
        account_nature TEXT NOT NULL,
        parent_id TEXT,
        currency_code TEXT,
        is_cash_bank INTEGER NOT NULL DEFAULT 0,
        is_reconcilable INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_system INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (id),
        UNIQUE (id, organization_id),
        UNIQUE (organization_id, account_code),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (parent_id, organization_id) REFERENCES ${DatabaseConstants.tableChartOfAccounts} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (currency_code) REFERENCES ${DatabaseConstants.tableCurrencies} (code) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
        CHECK (account_nature IN ('DEBIT', 'CREDIT')),
        CHECK (is_cash_bank IN (0, 1)),
        CHECK (is_reconcilable IN (0, 1)),
        CHECK (is_active IN (0, 1)),
        CHECK (is_system IN (0, 1))
      );
    ''');

    // 7. Fiscal Years
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableFiscalYears} (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        is_closed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (id),
        UNIQUE (id, organization_id),
        UNIQUE (organization_id, name),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (is_closed IN (0, 1)),
        CHECK (end_date >= start_date)
      );
    ''');

    // 8. Fiscal Periods
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableFiscalPeriods} (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        fiscal_year_id TEXT NOT NULL,
        period_number INTEGER NOT NULL,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        is_locked INTEGER NOT NULL DEFAULT 0,
        is_closed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (id),
        UNIQUE (id, organization_id),
        UNIQUE (organization_id, fiscal_year_id, period_number),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (fiscal_year_id, organization_id) REFERENCES ${DatabaseConstants.tableFiscalYears} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (period_number >= 1 AND period_number <= 13),
        CHECK (is_locked IN (0, 1)),
        CHECK (is_closed IN (0, 1)),
        CHECK (end_date >= start_date)
      );
    ''');

    // 9. Parties (Customers & Suppliers)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableParties} (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        code TEXT NOT NULL,
        party_type TEXT NOT NULL,
        name_ar TEXT NOT NULL,
        name_en TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        tax_number TEXT,
        credit_limit INTEGER NOT NULL DEFAULT 0,
        default_currency_code TEXT,
        linked_account_id TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (id),
        UNIQUE (id, organization_id),
        UNIQUE (organization_id, code),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (default_currency_code) REFERENCES ${DatabaseConstants.tableCurrencies} (code) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (linked_account_id, organization_id) REFERENCES ${DatabaseConstants.tableChartOfAccounts} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (party_type IN ('CUSTOMER', 'SUPPLIER', 'BOTH')),
        CHECK (is_active IN (0, 1)),
        CHECK (credit_limit >= 0)
      );
    ''');

    // 10. Journal Entries (General Ledger Header)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableJournalEntries} (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        entry_number TEXT NOT NULL,
        fiscal_period_id TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        entry_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'DRAFT',
        reference TEXT,
        narration TEXT NOT NULL,
        total_base_debit INTEGER NOT NULL DEFAULT 0,
        total_base_credit INTEGER NOT NULL DEFAULT 0,
        posted_at TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (id),
        UNIQUE (id, organization_id),
        UNIQUE (organization_id, entry_number),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (fiscal_period_id, organization_id) REFERENCES ${DatabaseConstants.tableFiscalPeriods} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (entry_type IN ('GENERAL', 'OPENING', 'SALES', 'PURCHASE', 'RECEIPT', 'PAYMENT', 'REVALUATION', 'CLOSING')),
        CHECK (status IN ('DRAFT', 'POSTED', 'VOIDED')),
        CHECK (total_base_debit >= 0 AND total_base_credit >= 0)
      );
    ''');

    // 11. Journal Entry Lines (General Ledger Detail)
    // Scale: exchange_rate_scaled: 1,000,000 = 1.000000
    // Amounts: Scaled integer minor units (e.g. cents/fils)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableJournalEntryLines} (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        journal_entry_id TEXT NOT NULL,
        line_number INTEGER NOT NULL,
        account_id TEXT NOT NULL,
        party_id TEXT,
        description TEXT,
        currency_code TEXT NOT NULL,
        exchange_rate_scaled INTEGER NOT NULL,
        foreign_debit INTEGER NOT NULL DEFAULT 0,
        foreign_credit INTEGER NOT NULL DEFAULT 0,
        base_debit INTEGER NOT NULL DEFAULT 0,
        base_credit INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (id),
        UNIQUE (id, organization_id),
        UNIQUE (journal_entry_id, line_number),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (journal_entry_id, organization_id) REFERENCES ${DatabaseConstants.tableJournalEntries} (id, organization_id) ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY (account_id, organization_id) REFERENCES ${DatabaseConstants.tableChartOfAccounts} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (party_id, organization_id) REFERENCES ${DatabaseConstants.tableParties} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (currency_code) REFERENCES ${DatabaseConstants.tableCurrencies} (code) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (exchange_rate_scaled > 0),
        CHECK (foreign_debit >= 0 AND foreign_credit >= 0),
        CHECK (base_debit >= 0 AND base_credit >= 0),
        CHECK (foreign_debit = 0 OR foreign_credit = 0),
        CHECK (base_debit = 0 OR base_credit = 0)
      );
    ''');

    // 12. Invoices (Sales, Purchases, Returns)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableInvoices} (
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
        CHECK (invoice_type IN ('SALES', 'PURCHASE', 'SALES_RETURN', 'PURCHASE_RETURN')),
        CHECK (status IN ('DRAFT', 'POSTED', 'CANCELLED')),
        CHECK (payment_status IN ('UNPAID', 'PARTIALLY_PAID', 'PAID')),
        CHECK (exchange_rate_scaled > 0),
        CHECK (total_amount >= 0),
        CHECK (paid_amount >= 0),
        CHECK (paid_amount <= total_amount)
      );
    ''');

    // 13. Invoice Lines
    // Quantity scale: 1,000 = 1.000 units
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableInvoiceLines} (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        invoice_id TEXT NOT NULL,
        line_number INTEGER NOT NULL,
        account_id TEXT NOT NULL,
        item_description TEXT NOT NULL,
        quantity_scaled INTEGER NOT NULL DEFAULT 1000,
        unit_price INTEGER NOT NULL,
        discount_amount INTEGER NOT NULL DEFAULT 0,
        tax_amount INTEGER NOT NULL DEFAULT 0,
        line_total INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (id),
        UNIQUE (id, organization_id),
        UNIQUE (invoice_id, line_number),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (invoice_id, organization_id) REFERENCES ${DatabaseConstants.tableInvoices} (id, organization_id) ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY (account_id, organization_id) REFERENCES ${DatabaseConstants.tableChartOfAccounts} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (quantity_scaled > 0),
        CHECK (unit_price >= 0),
        CHECK (discount_amount >= 0),
        CHECK (tax_amount >= 0),
        CHECK (line_total >= 0)
      );
    ''');

    // 14. Payments (Receipts & Disbursements)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tablePayments} (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        party_id TEXT NOT NULL,
        cash_bank_account_id TEXT NOT NULL,
        journal_entry_id TEXT,
        payment_type TEXT NOT NULL,
        payment_number TEXT NOT NULL,
        payment_date TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        currency_code TEXT NOT NULL,
        exchange_rate_scaled INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        allocated_amount INTEGER NOT NULL DEFAULT 0,
        unallocated_amount INTEGER NOT NULL,
        reference_number TEXT,
        status TEXT NOT NULL DEFAULT 'DRAFT',
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (id),
        UNIQUE (id, organization_id),
        UNIQUE (organization_id, payment_number),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (party_id, organization_id) REFERENCES ${DatabaseConstants.tableParties} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (cash_bank_account_id, organization_id) REFERENCES ${DatabaseConstants.tableChartOfAccounts} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (journal_entry_id, organization_id) REFERENCES ${DatabaseConstants.tableJournalEntries} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (currency_code) REFERENCES ${DatabaseConstants.tableCurrencies} (code) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (payment_type IN ('RECEIPT', 'PAYMENT')),
        CHECK (status IN ('DRAFT', 'POSTED', 'VOIDED')),
        CHECK (payment_method IN ('CASH', 'BANK_TRANSFER', 'CHEQUE')),
        CHECK (amount > 0),
        CHECK (allocated_amount >= 0),
        CHECK (unallocated_amount >= 0),
        CHECK (exchange_rate_scaled > 0),
        CHECK (allocated_amount + unallocated_amount = amount)
      );
    ''');

    // 15. Payment Allocations (Linking payments to invoices with realized FX gain/loss)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tablePaymentAllocations} (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        payment_id TEXT NOT NULL,
        invoice_id TEXT NOT NULL,
        allocated_amount INTEGER NOT NULL,
        realized_forex_gain_loss INTEGER NOT NULL DEFAULT 0,
        allocation_date TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (id),
        UNIQUE (id, organization_id),
        UNIQUE (payment_id, invoice_id),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (payment_id, organization_id) REFERENCES ${DatabaseConstants.tablePayments} (id, organization_id) ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY (invoice_id, organization_id) REFERENCES ${DatabaseConstants.tableInvoices} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (allocated_amount > 0)
      );
    ''');

    // 16. Opening Balances
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableOpeningBalances} (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        fiscal_year_id TEXT NOT NULL,
        journal_entry_id TEXT,
        as_of_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'DRAFT',
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (id),
        UNIQUE (id, organization_id),
        UNIQUE (organization_id, fiscal_year_id),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (fiscal_year_id, organization_id) REFERENCES ${DatabaseConstants.tableFiscalYears} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (journal_entry_id, organization_id) REFERENCES ${DatabaseConstants.tableJournalEntries} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (status IN ('DRAFT', 'POSTED'))
      );
    ''');

    // 17. Forex Revaluations Header
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableForexRevaluations} (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        revaluation_number TEXT NOT NULL,
        revaluation_date TEXT NOT NULL,
        fiscal_period_id TEXT NOT NULL,
        journal_entry_id TEXT,
        status TEXT NOT NULL DEFAULT 'DRAFT',
        total_unrealized_gain_loss INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (id),
        UNIQUE (id, organization_id),
        UNIQUE (organization_id, revaluation_number),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (fiscal_period_id, organization_id) REFERENCES ${DatabaseConstants.tableFiscalPeriods} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (journal_entry_id, organization_id) REFERENCES ${DatabaseConstants.tableJournalEntries} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (status IN ('DRAFT', 'POSTED', 'VOIDED'))
      );
    ''');

    // 18. Forex Revaluation Lines
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableForexRevaluationLines} (
        id TEXT NOT NULL,
        organization_id TEXT NOT NULL,
        revaluation_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        currency_code TEXT NOT NULL,
        foreign_balance INTEGER NOT NULL,
        book_value_base INTEGER NOT NULL,
        new_rate_scaled INTEGER NOT NULL,
        revalued_value_base INTEGER NOT NULL,
        unrealized_gain_loss INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (id),
        UNIQUE (id, organization_id),
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations} (id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (revaluation_id, organization_id) REFERENCES ${DatabaseConstants.tableForexRevaluations} (id, organization_id) ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY (account_id, organization_id) REFERENCES ${DatabaseConstants.tableChartOfAccounts} (id, organization_id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (currency_code) REFERENCES ${DatabaseConstants.tableCurrencies} (code) ON UPDATE CASCADE ON DELETE RESTRICT,
        CHECK (new_rate_scaled > 0)
      );
    ''');

    // Multi-tenant and high-traffic Query Indexes
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_coa_org_type
      ON ${DatabaseConstants.tableChartOfAccounts} (organization_id, account_type);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_coa_parent
      ON ${DatabaseConstants.tableChartOfAccounts} (parent_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_journal_org_date
      ON ${DatabaseConstants.tableJournalEntries} (organization_id, entry_date);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_journal_lines_entry
      ON ${DatabaseConstants.tableJournalEntryLines} (journal_entry_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_journal_lines_acc
      ON ${DatabaseConstants.tableJournalEntryLines} (organization_id, account_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_invoices_org_party
      ON ${DatabaseConstants.tableInvoices} (organization_id, party_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_invoices_due_status
      ON ${DatabaseConstants.tableInvoices} (organization_id, due_date, payment_status);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_payments_org_party
      ON ${DatabaseConstants.tablePayments} (organization_id, party_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_allocations_inv
      ON ${DatabaseConstants.tablePaymentAllocations} (invoice_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_audit_logs_lookup
      ON ${DatabaseConstants.tableAuditLogs} (organization_id, table_name, record_id);
    ''');

    // -------------------------------------------------------------
    // TRIGGERS: Ledger Immutability & Double-Entry Balance Validation
    // -------------------------------------------------------------

    // 1. Prevent inserting lines into posted journal entries
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_journal_entry_lines_prevent_insert_posted
      BEFORE INSERT ON ${DatabaseConstants.tableJournalEntryLines}
      FOR EACH ROW
      WHEN (SELECT status FROM ${DatabaseConstants.tableJournalEntries} WHERE id = NEW.journal_entry_id) = 'POSTED'
      BEGIN
        SELECT RAISE(ABORT, 'Cannot add lines to a posted journal entry.');
      END;
    ''');

    // 2. Prevent modifying lines of posted journal entries
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_journal_entry_lines_prevent_update_posted
      BEFORE UPDATE ON ${DatabaseConstants.tableJournalEntryLines}
      FOR EACH ROW
      WHEN (SELECT status FROM ${DatabaseConstants.tableJournalEntries} WHERE id = OLD.journal_entry_id) = 'POSTED'
      BEGIN
        SELECT RAISE(ABORT, 'Lines of a posted journal entry cannot be modified.');
      END;
    ''');

    // 3. Prevent deleting lines of posted journal entries
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_journal_entry_lines_prevent_delete_posted
      BEFORE DELETE ON ${DatabaseConstants.tableJournalEntryLines}
      FOR EACH ROW
      WHEN (SELECT status FROM ${DatabaseConstants.tableJournalEntries} WHERE id = OLD.journal_entry_id) = 'POSTED'
      BEGIN
        SELECT RAISE(ABORT, 'Lines of a posted journal entry cannot be deleted.');
      END;
    ''');

    // 4. Prevent modifying header of posted journal entries or reverting to draft
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_journal_entries_prevent_mod_posted
      BEFORE UPDATE ON ${DatabaseConstants.tableJournalEntries}
      FOR EACH ROW
      WHEN OLD.status = 'POSTED' AND (
        OLD.entry_date != NEW.entry_date OR
        OLD.entry_type != NEW.entry_type OR
        OLD.fiscal_period_id != NEW.fiscal_period_id OR
        OLD.organization_id != NEW.organization_id OR
        OLD.entry_number != NEW.entry_number OR
        NEW.status = 'DRAFT'
      )
      BEGIN
        SELECT RAISE(ABORT, 'Posted journal entries are immutable and cannot be modified or reverted to draft.');
      END;
    ''');

    // 5. Prevent deleting posted journal entries
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_journal_entries_prevent_del_posted
      BEFORE DELETE ON ${DatabaseConstants.tableJournalEntries}
      FOR EACH ROW
      WHEN OLD.status = 'POSTED'
      BEGIN
        SELECT RAISE(ABORT, 'Posted journal entries are immutable and cannot be deleted.');
      END;
    ''');

    // 6. Enforce Double-Entry Balance on Status Change to 'POSTED'
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_journal_entries_enforce_post_balance
      BEFORE UPDATE OF status ON ${DatabaseConstants.tableJournalEntries}
      FOR EACH ROW
      WHEN NEW.status = 'POSTED' AND OLD.status != 'POSTED'
      BEGIN
        SELECT RAISE(ABORT, 'Journal entry cannot be posted: total base debit does not equal total base credit.')
        WHERE (
          SELECT COALESCE(SUM(base_debit), 0)
          FROM ${DatabaseConstants.tableJournalEntryLines}
          WHERE journal_entry_id = NEW.id
        ) != (
          SELECT COALESCE(SUM(base_credit), 0)
          FROM ${DatabaseConstants.tableJournalEntryLines}
          WHERE journal_entry_id = NEW.id
        );

        SELECT RAISE(ABORT, 'Journal entry cannot be posted: entry must have at least 2 lines.')
        WHERE (
          SELECT COUNT(*)
          FROM ${DatabaseConstants.tableJournalEntryLines}
          WHERE journal_entry_id = NEW.id
        ) < 2;

        SELECT RAISE(ABORT, 'Journal entry cannot be posted: total amount must be greater than zero.')
        WHERE (
          SELECT COALESCE(SUM(base_debit), 0)
          FROM ${DatabaseConstants.tableJournalEntryLines}
          WHERE journal_entry_id = NEW.id
        ) <= 0;
      END;
    ''');

    // -------------------------------------------------------------
    // Reference Currencies Seed (YER, USD, SAR)
    // -------------------------------------------------------------
    await db.execute('''
      INSERT OR IGNORE INTO ${DatabaseConstants.tableCurrencies} 
        (code, name_ar, name_en, symbol, decimal_places, is_active)
      VALUES 
        ('YER', 'ريال يمني', 'Yemeni Rial', 'ر.ي', 2, 1),
        ('USD', 'دولار أمريكي', 'US Dollar', '\$', 2, 1),
        ('SAR', 'ريال سعودي', 'Saudi Riyal', 'ر.س', 2, 1);
    ''');
  }
}
