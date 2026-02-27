// lib/features/reporting/presentation/settlement_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettlementState {
  final double? totalRevenue;
  final Map<int, int> cashCounts;
  final Map<String, double> paymentAmounts;

  SettlementState({
    this.totalRevenue,
    this.cashCounts = const {},
    this.paymentAmounts = const {},
  });

  SettlementState copyWith({
    double? totalRevenue,
    Map<int, int>? cashCounts,
    Map<String, double>? paymentAmounts,
  }) {
    return SettlementState(
      totalRevenue: totalRevenue ?? this.totalRevenue,
      cashCounts: cashCounts ?? this.cashCounts,
      paymentAmounts: paymentAmounts ?? this.paymentAmounts,
    );
  }

  bool get isEmpty => totalRevenue == null && cashCounts.isEmpty && paymentAmounts.isEmpty;
}

class SettlementNotifier extends Notifier<SettlementState> {
  @override
  SettlementState build() {
    return SettlementState();
  }

  void updateRevenue(double amount) {
    state = state.copyWith(totalRevenue: amount);
  }

  void updateCashCount(int denomination, int count) {
    final newCounts = Map<int, int>.from(state.cashCounts);
    newCounts[denomination] = count;
    state = state.copyWith(cashCounts: newCounts);
  }

  void updatePaymentAmount(String method, double amount) {
    final newPayments = Map<String, double>.from(state.paymentAmounts);
    newPayments[method] = amount;
    state = state.copyWith(paymentAmounts: newPayments);
  }

  void reset() {
    state = SettlementState();
  }
}

final settlementProvider = NotifierProvider<SettlementNotifier, SettlementState>(SettlementNotifier.new);
