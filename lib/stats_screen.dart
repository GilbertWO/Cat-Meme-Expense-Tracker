import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/firebase_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _selectedYear = DateTime.now().year;
  Map<ExpenseCategory, double> _categoryTotals = {};
  Map<String, double> _monthlyTotals = {};
  double _totalSpent = 0;
  bool _isLoading = true;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final yearStart = DateTime(_selectedYear, 1, 1);
    final yearEnd = DateTime(_selectedYear, 12, 31, 23, 59, 59);

    // Fetch all expenses for the selected year from Firestore
    final allExpenses = await FirebaseService.instance.getAllExpenses();
    final expenses = allExpenses.where((e) =>
    !e.date.isBefore(yearStart) && !e.date.isAfter(yearEnd)).toList();

    // Compute category totals
    final Map<ExpenseCategory, double> categoryTotals = {};
    for (final e in expenses) {
      categoryTotals[e.category] =
          (categoryTotals[e.category] ?? 0) + e.amount;
    }

    // Compute monthly totals
    final Map<String, double> monthlyTotals = {};
    for (final e in expenses) {
      final key =
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      monthlyTotals[key] = (monthlyTotals[key] ?? 0) + e.amount;
    }

    // Compute total
    final total = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    setState(() {
      _categoryTotals = categoryTotals;
      _monthlyTotals = monthlyTotals;
      _totalSpent = total;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        title: Text(
          'Statistics',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          _buildYearPicker(theme, colorScheme),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categoryTotals.isEmpty
          ? _buildEmptyState(theme, colorScheme)
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildTotalCard(theme, colorScheme),
          const SizedBox(height: 24),
          _buildPieChart(theme, colorScheme),
          const SizedBox(height: 24),
          _buildBarChart(theme, colorScheme),
          const SizedBox(height: 24),
          _buildCategoryBreakdown(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildYearPicker(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() => _selectedYear--);
              _loadStats();
            },
          ),
          Text('$_selectedYear',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _selectedYear >= DateTime.now().year
                ? null
                : () {
              setState(() => _selectedYear++);
              _loadStats();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Spent in $_selectedYear',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'RM ${_totalSpent.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_categoryTotals.length} categories tracked',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(ThemeData theme, ColorScheme colorScheme) {
    final sections = _categoryTotals.entries.map((entry) {
      final index = entry.key.index;
      final isTouched = index == _touchedIndex;
      return PieChartSectionData(
        color: entry.key.color,
        value: entry.value,
        title: isTouched
            ? '${(entry.value / _totalSpent * 100).toStringAsFixed(1)}%'
            : '',
        radius: isTouched ? 60 : 50,
        titleStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By Category',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex = response
                          .touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sections: sections,
                sectionsSpace: 3,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _categoryTotals.keys.map((cat) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: cat.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(cat.label,
                      style: theme.textTheme.bodySmall),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(ThemeData theme, ColorScheme colorScheme) {
    if (_monthlyTotals.isEmpty) return const SizedBox.shrink();

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final barGroups = List.generate(12, (i) {
      final key =
          '$_selectedYear-${(i + 1).toString().padLeft(2, '0')}';
      final value = _monthlyTotals[key] ?? 0.0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: value,
            color: colorScheme.primary,
            width: 16,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6)),
          ),
        ],
      );
    });

    final maxY = _monthlyTotals.values.isEmpty
        ? 100.0
        : _monthlyTotals.values.reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Spending',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colorScheme.outline.withOpacity(0.3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, _) => Text(
                        'RM${value.toInt()}',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => Text(
                        months[value.toInt()],
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(ThemeData theme, ColorScheme colorScheme) {
    final sorted = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Breakdown',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...sorted.map((entry) {
            final pct = _totalSpent > 0
                ? entry.value / _totalSpent
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(entry.key.emoji),
                      const SizedBox(width: 8),
                      Text(entry.key.label,
                          style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Text(
                        'RM ${entry.value.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(pct * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor:
                      entry.key.color.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(entry.key.color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined,
              size: 80,
              color: colorScheme.onBackground.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'No data for $_selectedYear',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onBackground.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}