import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/finance_constants.dart';
import '../../core/utils/money.dart';
import '../auth/data/session_controller.dart';
import 'data/finance_repository.dart';

/// Finans ekranı — bkz. docs/04 § Gelir/Gider Modülü, § Finans Dashboard.
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finans'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Özet'),
            Tab(text: 'Gelir'),
            Tab(text: 'Gider'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_SummaryTab(), _IncomeTab(), _ExpenseTab()],
      ),
      floatingActionButton: _tabController.index == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _tabController.index == 1
                  ? _showAddIncomeDialog(context)
                  : _showAddExpenseDialog(context),
              icon: const Icon(Icons.add),
              label: Text(
                _tabController.index == 1 ? 'Gelir Ekle' : 'Gider Ekle',
              ),
            ),
    );
  }
}

Future<void> _showAddIncomeDialog(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _AddIncomeSheet(),
  );
}

Future<void> _showAddExpenseDialog(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _AddExpenseSheet(),
  );
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final scheme = Theme.of(context).colorScheme;
    final monthLabel = DateFormat('MMMM y', 'tr_TR').format(DateTime.now());

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (summary) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(monthLabel, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Gelir',
                    amountMinor: summary.incomeMinor,
                    color: Colors.green,
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: 'Gider',
                    amountMinor: summary.expenseMinor,
                    color: Colors.red,
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: 'Net',
                    amountMinor: summary.netMinor,
                    color: scheme.primary,
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.amountMinor,
    required this.color,
    this.bold = false,
  });
  final String label;
  final int amountMinor;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontSize: bold ? 16 : 14,
          ),
        ),
        const Spacer(),
        Text(
          Money.formatMinor(amountMinor, decimals: false),
          style: TextStyle(
            color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            fontSize: bold ? 20 : 16,
          ),
        ),
      ],
    );
  }
}

class _IncomeTab extends ConsumerWidget {
  const _IncomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeAsync = ref.watch(incomeListProvider);
    return incomeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (entries) {
        if (entries.isEmpty) {
          return _EmptyFinanceState(
            text: 'Henüz gelir kaydı yok',
            icon: Icons.trending_up,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final e = entries[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.arrow_downward, color: Colors.green),
                title: Text(e.description),
                subtitle: Text(
                  '${e.category} · ${DateFormat('d MMM y', 'tr_TR').format(e.date)}',
                ),
                trailing: Text(
                  Money.formatMinor(e.amountMinor),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ExpenseTab extends ConsumerWidget {
  const _ExpenseTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(expenseListProvider);
    return expenseAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (entries) {
        if (entries.isEmpty) {
          return _EmptyFinanceState(
            text: 'Henüz gider kaydı yok',
            icon: Icons.trending_down,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final e = entries[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.arrow_upward, color: Colors.red),
                title: Text(e.description),
                subtitle: Text(
                  '${e.category} · ${DateFormat('d MMM y', 'tr_TR').format(e.date)}',
                ),
                trailing: Text(
                  Money.formatMinor(e.amountMinor),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyFinanceState extends StatelessWidget {
  const _EmptyFinanceState({required this.text, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddIncomeSheet extends ConsumerStatefulWidget {
  const _AddIncomeSheet();

  @override
  ConsumerState<_AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _AddIncomeSheetState extends ConsumerState<_AddIncomeSheet> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = incomeCategories.first;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_descController.text.trim().isEmpty ||
        _amountController.text.trim().isEmpty) {
      return;
    }
    setState(() => _isSubmitting = true);
    final session = ref.read(sessionControllerProvider).valueOrNull;
    if (session == null) return;

    await ref
        .read(financeRepositoryProvider)
        .addIncome(
          companyId: session.companyId,
          description: _descController.text.trim(),
          amountMinor: Money.parseToMinor(_amountController.text),
          category: _category,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Gelir Ekle', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Açıklama'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Tutar (₺)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: incomeCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  const _AddExpenseSheet();

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = expenseCategories.first;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_descController.text.trim().isEmpty ||
        _amountController.text.trim().isEmpty) {
      return;
    }
    setState(() => _isSubmitting = true);
    final session = ref.read(sessionControllerProvider).valueOrNull;
    if (session == null) return;

    await ref
        .read(financeRepositoryProvider)
        .addExpense(
          companyId: session.companyId,
          description: _descController.text.trim(),
          amountMinor: Money.parseToMinor(_amountController.text),
          category: _category,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Gider Ekle', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Açıklama'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Tutar (₺)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: expenseCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
