import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../app/typography.dart';
import '../../core/constants/finance_constants.dart';
import '../../core/utils/money.dart';
import '../auth/data/session_controller.dart';
import '../../shared/ui.dart';
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

/// Finans özeti — tasarım teslimatı ekran 25.
///
/// En üstte tek bir sayı: net kâr. Kullanıcının aya bakarken sorduğu tek
/// soru bu; gelir ve gider onu açıklayan ikinci sıra bilgi.
class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  static final _ayKisa = DateFormat('MMM', 'tr_TR');
  static final _ayUzun = DateFormat('MMMM y', 'tr_TR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palet = context.palette;

    return ref
        .watch(financeOverviewProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppErrorState(
            message: 'Finans özeti yüklenemedi.',
            onRetry: () => ref.invalidate(financeOverviewProvider),
          ),
          data: (gorunum) {
            final buAy = gorunum.buAy;
            final degisim = gorunum.netDegisimYuzdesi;

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text(
                  _ayUzun.format(buAy.ay),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  accent: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NET KÂR',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palet.textMuted,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Money.formatMinor(buAy.netMinor, decimals: false),
                        style: AppTypography.monoLarge.copyWith(
                          fontSize: 30,
                          color: buAy.netMinor >= 0
                              ? palet.accent
                              : palet.dangerText,
                        ),
                      ),
                      if (degisim != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${degisim >= 0 ? '%${degisim.round()} artış' : '%${degisim.abs().round()} düşüş'}'
                          ' · geçen aya göre',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: degisim >= 0
                                    ? palet.successText
                                    : palet.dangerText,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _MiniKutu(
                        etiket: 'Gelir',
                        tutar: buAy.incomeMinor,
                        renk: palet.successText,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _MiniKutu(
                        etiket: 'Gider',
                        tutar: buAy.expenseMinor,
                        renk: palet.dangerText,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _MiniKutu(
                        etiket: 'Alacak',
                        tutar: gorunum.receivableMinor,
                        renk: palet.warningText,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),
                const SectionHeader('Son 6 ay'),
                _AylikGrafik(aylar: gorunum.aylar, ayEtiketi: _ayKisa.format),
              ],
            );
          },
        );
  }
}

/// Gelir / Gider / Alacak kutusu.
class _MiniKutu extends StatelessWidget {
  const _MiniKutu({
    required this.etiket,
    required this.tutar,
    required this.renk,
  });

  final String etiket;
  final int tutar;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiket,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.palette.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            Money.formatMinor(tutar, decimals: false),
            style: AppTypography.mono.copyWith(fontSize: 14, color: renk),
          ),
        ],
      ),
    );
  }
}

/// Altı aylık gelir/gider sütun grafiği.
///
/// Grafik kütüphanesi yerine düz kutular: altı çift sütun için bir paket
/// eklemek, uygulamanın boyutunu ve başlangıç süresini hiç yoktan
/// büyütürdü (bkz. Play kalite gereksinimleri).
class _AylikGrafik extends StatelessWidget {
  const _AylikGrafik({required this.aylar, required this.ayEtiketi});

  final List<AyOzeti> aylar;
  final String Function(DateTime) ayEtiketi;

  static const _yukseklik = 96.0;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    // Ölçek en yüksek sütuna göre. Hepsi sıfırsa bölme yapılmaz.
    var tavan = 0;
    for (final a in aylar) {
      if (a.incomeMinor > tavan) tavan = a.incomeMinor;
      if (a.expenseMinor > tavan) tavan = a.expenseMinor;
    }

    double oran(int deger) => tavan == 0 ? 0 : deger / tavan;

    return AppCard(
      child: Column(
        children: [
          SizedBox(
            height: _yukseklik,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final ay in aylar)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Sutun(
                          oran: oran(ay.incomeMinor),
                          renk: palet.successText,
                        ),
                        const SizedBox(width: 3),
                        _Sutun(
                          oran: oran(ay.expenseMinor),
                          renk: palet.dangerText,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final ay in aylar)
                Expanded(
                  child: Text(
                    ayEtiketi(ay.ay),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palet.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Anahtar(renk: palet.successText, metin: 'Gelir'),
              const SizedBox(width: AppSpacing.lg),
              _Anahtar(renk: palet.dangerText, metin: 'Gider'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sutun extends StatelessWidget {
  const _Sutun({required this.oran, required this.renk});

  final double oran;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    // Sıfır bile olsa 2dp'lik bir iz bırakılıyor: hiç sütun olmaması
    // "veri gelmedi" gibi okunuyor, "o ay sıfırdı" gibi değil.
    final yukseklik = 2 + (_AylikGrafik._yukseklik - 2) * oran.clamp(0, 1);

    return Container(
      width: 10,
      height: yukseklik,
      decoration: BoxDecoration(
        color: renk.withValues(alpha: oran == 0 ? 0.3 : 0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}

class _Anahtar extends StatelessWidget {
  const _Anahtar({required this.renk, required this.metin});

  final Color renk;
  final String metin;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          metin,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.palette.textMuted),
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
