import 'package:flutter/material.dart';

enum ExpenseCategory {
  food,
  transport,
  shopping,
  entertainment,
  health,
  housing,
  utilities,
  other,
}

extension ExpenseCategoryExtension on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.food:        return 'Food & Dining';
      case ExpenseCategory.transport:   return 'Transport';
      case ExpenseCategory.shopping:    return 'Shopping';
      case ExpenseCategory.entertainment: return 'Entertainment';
      case ExpenseCategory.health:      return 'Health';
      case ExpenseCategory.housing:     return 'Housing';
      case ExpenseCategory.utilities:   return 'Utilities';
      case ExpenseCategory.other:       return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case ExpenseCategory.food:        return '🍽️';
      case ExpenseCategory.transport:   return '🚗';
      case ExpenseCategory.shopping:    return '🛍️';
      case ExpenseCategory.entertainment: return '🎬';
      case ExpenseCategory.health:      return '💊';
      case ExpenseCategory.housing:     return '🏠';
      case ExpenseCategory.utilities:   return '⚡';
      case ExpenseCategory.other:       return '📦';
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.food:        return const Color(0xFFFF6B6B);
      case ExpenseCategory.transport:   return const Color(0xFF4ECDC4);
      case ExpenseCategory.shopping:    return const Color(0xFFFFE66D);
      case ExpenseCategory.entertainment: return const Color(0xFFA8E6CF);
      case ExpenseCategory.health:      return const Color(0xFFFF8B94);
      case ExpenseCategory.housing:     return const Color(0xFF6C5CE7);
      case ExpenseCategory.utilities:   return const Color(0xFFFDCB6E);
      case ExpenseCategory.other:       return const Color(0xFF74B9FF);
    }
  }
}

class Expense {
  final int? id;
  final String? firestoreId; // Firestore document ID
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final String? note;

  Expense({
    this.id,
    this.firestoreId,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category.index,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: map['amount'] as double,
      category: ExpenseCategory.values[map['category'] as int],
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
    );
  }

  Expense copyWith({
    int? id,
    String? firestoreId,
    String? title,
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
    String? note,
  }) {
    return Expense(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }
}
