import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense.dart';

/// Firestore-backed expense service.
/// Collection structure: expenses/{userId}/records/{docId}
///
/// For simplicity this uses a hardcoded userId — swap in
/// FirebaseAuth.instance.currentUser!.uid once you add auth.
class FirebaseService {
  static final FirebaseService instance = FirebaseService._init();
  FirebaseService._init();

  static const _userId = 'default_user'; // replace with auth uid later

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('expenses')
      .doc(_userId)
      .collection('records');

  // ── CREATE ──────────────────────────────────────────────────────────────────
  Future<Expense> createExpense(Expense expense) async {
    final doc = await _col.add({
      'title': expense.title,
      'amount': expense.amount,
      'category': expense.category.index,
      'date': Timestamp.fromDate(expense.date),
      'note': expense.note,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return expense.copyWith(id: doc.id.hashCode);
  }

  // ── READ ALL ─────────────────────────────────────────────────────────────────
  Future<List<Expense>> getAllExpenses() async {
    final snap =
    await _col.orderBy('date', descending: true).get();
    return snap.docs.map((d) => _fromDoc(d)).toList();
  }

  // ── REAL-TIME STREAM ─────────────────────────────────────────────────────────
  Stream<List<Expense>> watchExpenses() {
    return _col
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _fromDoc(d)).toList());
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────────
  Future<void> updateExpense(String firestoreId, Expense expense) async {
    await _col.doc(firestoreId).update({
      'title': expense.title,
      'amount': expense.amount,
      'category': expense.category.index,
      'date': Timestamp.fromDate(expense.date),
      'note': expense.note,
    });
  }

  // ── DELETE ────────────────────────────────────────────────────────────────────
  Future<void> deleteExpense(String firestoreId) async {
    await _col.doc(firestoreId).delete();
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────────
  Expense _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Expense(
      id: doc.id.hashCode,
      firestoreId: doc.id,
      title: data['title'] as String,
      amount: (data['amount'] as num).toDouble(),
      category: ExpenseCategory.values[data['category'] as int],
      date: (data['date'] as Timestamp).toDate(),
      note: data['note'] as String?,
    );
  }
}