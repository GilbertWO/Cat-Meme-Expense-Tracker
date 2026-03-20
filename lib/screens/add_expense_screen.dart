import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/firebase_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense; // if provided, we're in edit mode

  const AddExpenseScreen({super.key, this.expense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  ExpenseCategory _selectedCategory = ExpenseCategory.food;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.expense!;
      _titleController.text = e.title;
      _amountController.text = e.amount.toStringAsFixed(2);
      _noteController.text = e.note ?? '';
      _selectedCategory = e.category;
      _selectedDate = e.date;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final expense = Expense(
      id: widget.expense?.id,
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text),
      category: _selectedCategory,
      date: _selectedDate,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    try {
      if (_isEditing) {
        await FirebaseService.instance.updateExpense(expense.firestoreId!, expense);
      } else {
        await FirebaseService.instance.createExpense(expense);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
          _isEditing ? 'Edit Expense' : 'New Expense',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(_isEditing ? 'Update' : 'Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Amount field — hero element
            _buildAmountField(theme, colorScheme),
            const SizedBox(height: 24),

            // Title
            _buildTextField(
              controller: _titleController,
              label: 'Title',
              hint: 'e.g. Lunch at Pak Ali',
              icon: Icons.title,
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Category picker
            _buildCategoryPicker(theme, colorScheme),
            const SizedBox(height: 16),

            // Date picker
            _buildDateField(theme, colorScheme),
            const SizedBox(height: 16),

            // Note
            _buildTextField(
              controller: _noteController,
              label: 'Note (optional)',
              hint: 'Any additional details...',
              icon: Icons.notes,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amount (RM)',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: colorScheme.primary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onBackground,
            ),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: theme.textTheme.displaySmall?.copyWith(
                color: colorScheme.onBackground.withOpacity(0.3),
                fontWeight: FontWeight.w700,
              ),
              border: InputBorder.none,
              prefixText: 'RM ',
              prefixStyle: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter an amount';
              final parsed = double.tryParse(v);
              if (parsed == null || parsed <= 0) return 'Enter a valid amount';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
    );
  }

  Widget _buildCategoryPicker(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: theme.textTheme.labelLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ExpenseCategory.values.map((cat) {
            final selected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? cat.color
                      : cat.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? cat.color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat.emoji),
                    const SizedBox(width: 6),
                    Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : cat.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateField(ThemeData theme, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surface,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 20, color: colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
              style: theme.textTheme.bodyLarge,
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: colorScheme.onSurface.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }
}
