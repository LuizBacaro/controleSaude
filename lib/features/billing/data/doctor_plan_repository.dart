import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../domain/doctor_plan.dart';

final doctorPlanRepositoryProvider = Provider<DoctorPlanRepository>((ref) {
  return DoctorPlanRepository();
});

/// `true` quando o consultório pode abrir. Paciente não consulta isto.
final doctorPlanActiveProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isDoctor) return false;
  ref.watch(authRevisionProvider);
  return ref.watch(doctorPlanRepositoryProvider).isActive(user.id);
});

class DoctorPlanRepository {
  DoctorPlanRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const playProductId = 'plano_medico_mensal';

  Future<bool> isActive(String userId) async {
    final row = await _client
        .from('doctor_subscriptions')
        .select('status, current_period_end')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return false;
    return DoctorPlan.fromJson(Map<String, dynamic>.from(row)).isActive;
  }

  /// Abre o checkout do site. A conta de médico já precisa existir.
  Future<String> startWebCheckout() async {
    try {
      final response = await _client.functions.invoke('create-doctor-checkout');
      final data = response.data;
      if (data is Map && data['url'] is String) {
        return data['url'] as String;
      }
      throw AppException('Não foi possível abrir o pagamento.');
    } on FunctionException catch (error) {
      throw AppException(_functionMessage(error));
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException.from(
        error,
        fallback: 'Não foi possível abrir o pagamento.',
      );
    }
  }

  /// Confirma uma compra da Play. Sem a conferência no servidor, o plano fica inativo.
  Future<void> confirmPlayPurchase(String purchaseToken) async {
    try {
      await _client.functions.invoke(
        'confirm-play-purchase',
        body: {'purchaseToken': purchaseToken, 'productId': playProductId},
      );
    } on FunctionException catch (error) {
      throw AppException(_functionMessage(error));
    } catch (error) {
      throw AppException.from(
        error,
        fallback: 'Não foi possível confirmar o pagamento.',
      );
    }
  }

  String _functionMessage(FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (details is String && details.trim().isNotEmpty) return details.trim();
    return 'Não foi possível concluir o pagamento.';
  }
}
