import 'package:exame_facil/features/billing/domain/doctor_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plano ativo sem data de fim continua aberto', () {
    const plan = DoctorPlan(status: 'active');
    expect(plan.isActiveAt(DateTime.utc(2026, 11, 13)), isTrue);
  });

  test('plano ativo fecha quando o período acaba', () {
    final plan = DoctorPlan(
      status: 'active',
      periodEnd: DateTime.utc(2026, 11, 1),
    );
    expect(plan.isActiveAt(DateTime.utc(2026, 11, 13)), isFalse);
    expect(plan.isActiveAt(DateTime.utc(2026, 10, 1)), isTrue);
  });

  test('plano em atraso ou cancelado fica fechado', () {
    expect(
      const DoctorPlan(status: 'past_due').isActiveAt(DateTime.utc(2026)),
      isFalse,
    );
    expect(
      const DoctorPlan(status: 'canceled').isActiveAt(DateTime.utc(2026)),
      isFalse,
    );
    expect(
      const DoctorPlan(status: 'inactive').isActiveAt(DateTime.utc(2026)),
      isFalse,
    );
  });
}
