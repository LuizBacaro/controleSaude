import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dashboard/presentation/evolution_page.dart';
import '../../dashboard/presentation/marker_detail_page.dart';
import '../data/granted_charts.dart';

class PatientEvolutionPage extends ConsumerStatefulWidget {
  const PatientEvolutionPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  final String patientId;
  final String patientName;

  @override
  ConsumerState<PatientEvolutionPage> createState() =>
      _PatientEvolutionPageState();
}

class _PatientEvolutionPageState extends ConsumerState<PatientEvolutionPage> {
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(grantedChartsProvider.notifier).load(widget.patientId);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.patientName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.patientName)),
        body: Center(child: Text(_error!)),
      );
    }
    ref.watch(grantedChartsProvider);
    final series = ref
        .read(grantedChartsProvider.notifier)
        .seriesOf(widget.patientId);
    return EvolutionPage(
      title: widget.patientName,
      series: series,
      readOnly: true,
      onOpenMarker: (name) {
        final uri = Uri(
          path: '/consultorio/paciente/${widget.patientId}/marcador',
          queryParameters: {'nome': name},
        );
        context.push(uri.toString());
      },
    );
  }
}

class GrantedMarkerPage extends ConsumerWidget {
  const GrantedMarkerPage({
    super.key,
    required this.patientId,
    required this.markerName,
  });

  final String patientId;
  final String markerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(grantedChartsProvider);
    final series = ref
        .read(grantedChartsProvider.notifier)
        .seriesFor(patientId, markerName);
    return MarkerDetailPage(markerName: markerName, series: series);
  }
}
