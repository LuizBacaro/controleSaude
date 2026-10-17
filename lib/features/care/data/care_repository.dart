import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/care_grant.dart';

final careRepositoryProvider = Provider<CareRepository>((ref) {
  return CareRepository();
});

class CareRepository {
  CareRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<DoctorListing>> listDoctors() async {
    final rows = await _client
        .from('doctor_directory')
        .select()
        .order('display_name', ascending: true);
    return [
      for (final row in rows)
        DoctorListing.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<List<CareGrant>> grantsAsPatient() async {
    final uid = _requireUser();
    final rows = await _client
        .from('care_grants')
        .select()
        .eq('patient_id', uid)
        .order('created_at');
    return _grants(rows);
  }

  Future<List<CareGrant>> grantsAsDoctor() async {
    final uid = _requireUser();
    final rows = await _client
        .from('care_grants')
        .select()
        .eq('doctor_id', uid)
        .order('created_at');
    return _grants(rows);
  }

  Future<void> invite(String doctorId) async {
    final uid = _requireUser();
    final existing = await _client
        .from('care_grants')
        .select('id, status')
        .eq('patient_id', uid)
        .eq('doctor_id', doctorId)
        .maybeSingle();
    try {
      if (existing == null) {
        await _client.from('care_grants').insert({
          'patient_id': uid,
          'doctor_id': doctorId,
          'status': 'pending',
        });
        return;
      }
      final status = existing['status'] as String?;
      if (status == 'pending' || status == 'accepted') {
        throw Exception('Este médico já recebeu o seu convite.');
      }
      await _client
          .from('care_grants')
          .update({'status': 'pending'})
          .eq('id', existing['id'] as String);
    } on PostgrestException catch (error) {
      throw Exception(_message(error));
    }
  }

  Future<void> revoke(String grantId) => _setStatus(grantId, 'revoked');

  Future<void> accept(String grantId) => _setStatus(grantId, 'accepted');

  Future<void> decline(String grantId) => _setStatus(grantId, 'revoked');

  Future<void> _setStatus(String grantId, String status) async {
    try {
      await _client
          .from('care_grants')
          .update({'status': status})
          .eq('id', grantId);
    } on PostgrestException catch (error) {
      throw Exception(_message(error));
    }
  }

  String _requireUser() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('Entre na conta para continuar.');
    }
    return uid;
  }

  List<CareGrant> _grants(List<dynamic> rows) => [
    for (final row in rows) CareGrant.fromJson(Map<String, dynamic>.from(row)),
  ];

  String _message(PostgrestException error) {
    final text = error.message;
    final lower = text.toLowerCase();
    if (lower.contains('revogue') ||
        lower.contains('já foi') ||
        lower.contains('só o') ||
        lower.contains('não é médico') ||
        lower.contains('sem permissão')) {
      return text;
    }
    if (lower.contains('duplicate') || lower.contains('unique')) {
      return 'Este convite já existe.';
    }
    return 'Não foi possível atualizar o acesso.';
  }
}
