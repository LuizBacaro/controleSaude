import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/errors/app_exception.dart';
import 'doctor_plan_repository.dart';

/// Compra o plano do consultório pela Play Store.
class PlayDoctorPlanBilling {
  PlayDoctorPlanBilling(this._confirm);

  final Future<void> Function(String purchaseToken) _confirm;
  final InAppPurchase _store = InAppPurchase.instance;

  Future<void> buy() async {
    final available = await _store.isAvailable();
    if (!available) {
      throw AppException('A Play Store não está disponível neste aparelho.');
    }
    final response = await _store.queryProductDetails({
      DoctorPlanRepository.playProductId,
    });
    if (response.productDetails.isEmpty) {
      throw AppException(
        'O plano do consultório ainda não está disponível na Play Store.',
      );
    }
    final product = response.productDetails.first;
    final completer = Completer<PurchaseDetails>();
    var buying = false;
    final subscription = _store.purchaseStream.listen((purchases) {
      if (!buying || completer.isCompleted) return;
      for (final purchase in purchases) {
        if (purchase.productID != product.id) continue;
        if (purchase.status == PurchaseStatus.pending) continue;
        if (!completer.isCompleted) completer.complete(purchase);
      }
    });
    try {
      buying = true;
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        throw AppException('Não foi possível abrir a compra.');
      }
      final purchase = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw AppException(
          'A compra não foi concluída. Tente de novo.',
        ),
      );
      if (purchase.status == PurchaseStatus.canceled) {
        throw AppException('A compra foi cancelada.');
      }
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        throw AppException(
          purchase.error?.message ?? 'Não foi possível concluir a compra.',
        );
      }
      final token = purchase.verificationData.serverVerificationData.trim();
      if (token.isEmpty) {
        throw AppException('A Play Store não devolveu a compra.');
      }
      try {
        await _confirm(token);
      } finally {
        if (purchase.pendingCompletePurchase) {
          await _store.completePurchase(purchase);
        }
      }
    } finally {
      await subscription.cancel();
    }
  }
}
