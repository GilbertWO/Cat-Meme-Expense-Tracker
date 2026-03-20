import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/firebase_service.dart';
import '../widgets/expense_tile.dart';
import '../widgets/cat_meme_card.dart';
import 'add_expense_screen.dart';
import '../stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Expense> _expenses = [];
  bool _isLoading = true;
  int _selectedNavIndex = 0;

  // Filters
  ExpenseCategory? _filterCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Cached computed values
  List<Expense> _filteredCache = [];
  double _thisMonthTotalCache = 0;
  Map<String, List<Expense>> _groupedCache = {};

  // Firestore real-time stream
  StreamSubscription<List<Expense>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribeToFirestore();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _subscribeToFirestore() {
    setState(() => _isLoading = true);
    _subscription =
        FirebaseService.instance.watchExpenses().listen((expenses) {
          if (!mounted) return;
          setState(() {
            _expenses = expenses;
            _recompute();
            _isLoading = false;
          });
        }, onError: (_) {
          if (mounted) setState(() => _isLoading = false);
        });
  }

  void _recompute() {
    final now = DateTime.now();
    double monthTotal = 0;
    for (final e in _expenses) {
      if (e.date.year == now.year && e.date.month == now.month) {
        monthTotal += e.amount;
      }
    }
    _thisMonthTotalCache = monthTotal;

    _filteredCache = _expenses.where((e) {
      final matchesCategory =
          _filterCategory == null || e.category == _filterCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          e.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    final grouped = <String, List<Expense>>{};
    for (final e in _filteredCache) {
      final key = DateFormat('MMMM d, yyyy').format(e.date);
      grouped.putIfAbsent(key, () => []).add(e);
    }
    _groupedCache = grouped;
  }

  void _applyFilters() => setState(() => _recompute());

  Future<void> _deleteExpense(Expense expense) async {
    if (expense.firestoreId == null) return;
    await FirebaseService.instance.deleteExpense(expense.firestoreId!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Expense deleted'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  Future<void> _navigateToAdd({Expense? expense}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(expense: expense),
        fullscreenDialog: true,
      ),
    );
    // No manual reload needed — Firestore stream updates automatically
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: _selectedNavIndex == 0
          ? _buildHomeBody(theme, colorScheme)
          : const StatsScreen(),
      floatingActionButton: _selectedNavIndex == 0
          ? FloatingActionButton.extended(
        onPressed: () => _navigateToAdd(),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeBody(ThemeData theme, ColorScheme colorScheme) {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(theme, colorScheme),
        SliverToBoxAdapter(child: _buildSummaryCard(theme, colorScheme)),
        // 🐱 Cat meme card lives here, between summary and expenses
        const SliverToBoxAdapter(child: CatMemeCard()),
        SliverToBoxAdapter(child: _buildSearchAndFilter(theme, colorScheme)),
        if (_isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_filteredCache.isEmpty)
          SliverFillRemaining(child: _buildEmptyState(theme, colorScheme))
        else
          _buildExpenseList(theme, colorScheme),
      ],
    );
  }

  Widget _buildSliverAppBar(ThemeData theme, ColorScheme colorScheme) {
    return SliverAppBar(
      backgroundColor: colorScheme.background,
      floating: true,
      title: Text(
        'My Expenses',
        style: theme.textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, ColorScheme colorScheme) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(now),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${_thisMonthTotalCache.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'This month',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_expenses.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'total entries',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) {
              _searchQuery = v;
              _applyFilters();
            },
            decoration: InputDecoration(
              hintText: 'Search expenses...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _searchQuery = '';
                  _applyFilters();
                },
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _filterCategory == null,
                    onSelected: (_) {
                      _filterCategory = null;
                      _applyFilters();
                    },
                  ),
                ),
                ...ExpenseCategory.values.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('${cat.emoji} ${cat.label}'),
                    selected: _filterCategory == cat,
                    selectedColor: cat.color.withOpacity(0.2),
                    onSelected: (_) {
                      _filterCategory =
                      _filterCategory == cat ? null : cat;
                      _applyFilters();
                    },
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList(ThemeData theme, ColorScheme colorScheme) {
    final dates = _groupedCache.keys.toList();
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final date = dates[index];
          final expenses = _groupedCache[date]!;
          final dayTotal =
          expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(date,
                          style: theme.textTheme.labelLarge?.copyWith(
                              color:
                              colorScheme.onBackground.withOpacity(0.5))),
                      Text('RM ${dayTotal.toStringAsFixed(2)}',
                          style: theme.textTheme.labelLarge?.copyWith(
                              color:
                              colorScheme.onBackground.withOpacity(0.5))),
                    ],
                  ),
                ),
                ...expenses.map((e) => ExpenseTile(
                  expense: e,
                  onDelete: () => _deleteExpense(e),
                  onTap: () => _navigateToAdd(expense: e),
                )),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
        childCount: dates.length,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 80,
              color: colorScheme.onBackground.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _filterCategory != null
                ? 'No matching expenses'
                : 'No expenses yet',
            style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onBackground.withOpacity(0.4)),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty && _filterCategory == null)
            Text(
              'Tap + Add Expense to get started',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onBackground.withOpacity(0.3)),
            ),
        ],
      ),
    );
  }
}
