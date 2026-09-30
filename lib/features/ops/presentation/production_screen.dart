import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../assets/domain/company_asset.dart';
import '../../commerce/application/commerce_providers.dart';
import '../../commerce/data/commerce_repository.dart';
import '../../orders/application/orders_providers.dart';
import '../../orders/domain/order_status.dart';
import '../application/ops_providers.dart';
import '../data/ops_repository.dart';
import 'qc_dialog.dart';

/// Production floor: job cards by stage (rush and late first), and a week
/// view of each machine's booked minutes against its daily capacity.
class ProductionScreen extends StatelessWidget {
  const ProductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(icon: Icon(Icons.view_kanban_outlined), text: 'Job board'),
              Tab(
                icon: Icon(Icons.calendar_view_week_outlined),
                text: 'Machine capacity',
              ),
            ],
          ),
          Expanded(child: TabBarView(children: [_Board(), _Capacity()])),
        ],
      ),
    );
  }
}

int _jobRank(ProductionJob j) => (j.isRush ? 0 : 2) + (j.isLate ? 0 : 1);

class _Board extends ConsumerStatefulWidget {
  const _Board();

  @override
  ConsumerState<_Board> createState() => _BoardState();
}

class _BoardState extends ConsumerState<_Board> {
  bool _openOnly = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(productionJobsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn\'t load jobs',
        message: friendlyError(e),
      ),
      data: (jobs) {
        final shown = (_openOnly ? jobs.where((j) => j.isOpen) : jobs).toList()
          ..sort((a, b) {
            final r = _jobRank(a).compareTo(_jobRank(b));
            if (r != 0) return r;
            return (a.dueDate ?? DateTime(2100)).compareTo(
              b.dueDate ?? DateTime(2100),
            );
          });
        final byStage = <String, List<ProductionJob>>{};
        for (final j in shown) {
          byStage.putIfAbsent(j.stage, () => []).add(j);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${jobs.where((j) => j.isOpen).length} open · ${jobs.where((j) => j.isLate).length} late · ${jobs.where((j) => j.isOpen && j.isRush).length} rush',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                FilterChip(
                  label: const Text('Open only'),
                  selected: _openOnly,
                  onSelected: (v) => setState(() => _openOnly = v),
                ),
              ],
            ),
            if (shown.isEmpty)
              const EmptyState(
                icon: Icons.precision_manufacturing_outlined,
                title: 'No jobs',
                message: 'Job cards appear here when orders are confirmed.',
              ),
            for (final stage in jobStages.keys)
              if (byStage[stage]?.isNotEmpty ?? false) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 6),
                  child: Text(
                    '${jobStages[stage]} (${byStage[stage]!.length})',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                for (final j in byStage[stage]!) _JobCard(job: j),
              ],
          ],
        );
      },
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.job});

  final ProductionJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = DateFormat('EEE d MMM');
    final order = ref
        .watch(allOrdersProvider)
        .valueOrNull
        ?.where((o) => o.id == job.orderId)
        .firstOrNull;
    return Card(
      child: ListTile(
        leading: Icon(
          job.isRush ? Icons.bolt_rounded : Icons.work_outline_rounded,
          color: job.isLate
              ? theme.colorScheme.error
              : job.isRush
              ? Colors.orange
              : null,
        ),
        title: Text('${job.orderNumber} · ${job.customerName}'),
        subtitle: Text(
          [
            job.itemsSummary,
            [
              if (job.machineName.isNotEmpty) job.machineName,
              if (job.operatorName.isNotEmpty) job.operatorName,
              if (job.scheduledDate != null)
                'on ${date.format(job.scheduledDate!)}',
              if (job.estimatedMinutes > 0)
                '${(job.estimatedMinutes / 60).toStringAsFixed(1)} h',
              if (job.dueDate != null)
                '${job.isLate ? 'LATE — was due' : 'due'} ${date.format(job.dueDate!)}',
              if (order != null) order.status.label,
            ].join(' · '),
          ].where((s) => s.isNotEmpty).join('\n'),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            switch (v) {
              case 'edit':
                await showDialog<void>(
                  context: context,
                  builder: (_) => _JobDialog(job: job),
                );
              case 'sheet':
                await openDocument(
                  context,
                  ref,
                  DocumentKind.jobSheet,
                  job.orderId,
                );
              case 'qc':
                await showQualityCheckDialog(
                  context,
                  orderId: job.orderId,
                  orderLabel: job.orderNumber,
                );
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Schedule / update'),
            ),
            const PopupMenuItem(value: 'sheet', child: Text('Print job sheet')),
            if (order != null &&
                [
                  OrderStatus.inProduction,
                  OrderStatus.qualityCheck,
                ].contains(order.status))
              const PopupMenuItem(value: 'qc', child: Text('Quality check')),
          ],
        ),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _JobDialog(job: job),
        ),
      ),
    );
  }
}

class _JobDialog extends ConsumerStatefulWidget {
  const _JobDialog({required this.job});

  final ProductionJob job;

  @override
  ConsumerState<_JobDialog> createState() => _JobDialogState();
}

class _JobDialogState extends ConsumerState<_JobDialog> {
  late String _stage = widget.job.stage;
  late String _priority = widget.job.priority;
  late String? _machineId = widget.job.machineId;
  late DateTime? _day = widget.job.scheduledDate;
  late final _operator = TextEditingController(text: widget.job.operatorName);
  late final _hours = TextEditingController(
    text: widget.job.estimatedMinutes == 0
        ? ''
        : (widget.job.estimatedMinutes / 60).toStringAsFixed(1),
  );
  late final _notes = TextEditingController(text: widget.job.notes);
  bool _saving = false;

  @override
  void dispose() {
    _operator.dispose();
    _hours.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save(List<CompanyAsset> machines) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final machine = machines.where((m) => m.id == _machineId).firstOrNull;
      await ref.read(opsRepositoryProvider).updateJob(widget.job.orderId, {
        'stage': _stage,
        'priority': _priority,
        'machineId': machine?.id,
        'machineName': machine?.name ?? '',
        'operatorName': _operator.text.trim(),
        'scheduledDate': _day,
        'estimatedMinutes': ((double.tryParse(_hours.text.trim()) ?? 0) * 60)
            .round(),
        'notes': _notes.text.trim(),
      }, uid: uid);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(error)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(machinesProvider);
    return AlertDialog(
      title: Text('Job ${widget.job.orderNumber}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _stage,
                decoration: const InputDecoration(labelText: 'Stage'),
                items: [
                  for (final e in jobStages.entries)
                    if (e.key != 'cancelled')
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _stage = v!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rush job'),
                value: _priority == 'rush',
                onChanged: (v) =>
                    setState(() => _priority = v ? 'rush' : 'normal'),
              ),
              DropdownButtonFormField<String?>(
                initialValue: machines.any((m) => m.id == _machineId)
                    ? _machineId
                    : null,
                decoration: InputDecoration(
                  labelText: 'Machine',
                  helperText: machines.isEmpty
                      ? 'Add machines under Company Assets (admin).'
                      : null,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Not assigned'),
                  ),
                  for (final m in machines)
                    DropdownMenuItem(value: m.id, child: Text(m.name)),
                ],
                onChanged: (v) => setState(() => _machineId = v),
              ),
              TextField(
                controller: _operator,
                decoration: const InputDecoration(labelText: 'Operator'),
              ),
              TextField(
                controller: _hours,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Estimated machine hours',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _day == null
                      ? 'Not scheduled'
                      : 'Scheduled ${DateFormat('EEE d MMM').format(_day!)}',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 30),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 180)),
                      initialDate: _day ?? DateTime.now(),
                    );
                    if (picked != null) {
                      setState(
                        () => _day = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          12,
                        ),
                      );
                    }
                  },
                  child: const Text('Pick day'),
                ),
              ),
              TextField(
                controller: _notes,
                maxLines: 2,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Production notes',
                ),
              ),
              if (widget.job.dueDate != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Promised to the customer for ${DateFormat('EEE d MMM').format(widget.job.dueDate!)}',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(machines),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _Capacity extends ConsumerStatefulWidget {
  const _Capacity();

  @override
  ConsumerState<_Capacity> createState() => _CapacityState();
}

class _CapacityState extends ConsumerState<_Capacity> {
  late DateTime _weekStart = _monday(DateTime.now());

  static DateTime _monday(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final machines = ref.watch(machinesProvider);
    final jobs = ref.watch(productionJobsProvider).valueOrNull ?? const [];
    final days = List.generate(6, (i) => _weekStart.add(Duration(days: i)));
    int booked(String machineId, DateTime day) => jobs
        .where(
          (j) =>
              j.isOpen && j.machineId == machineId && j.scheduledDate != null,
        )
        .where(
          (j) =>
              j.scheduledDate!.year == day.year &&
              j.scheduledDate!.month == day.month &&
              j.scheduledDate!.day == day.day,
        )
        .fold(0, (s, j) => s + j.estimatedMinutes);
    final unscheduled = jobs
        .where(
          (j) => j.isOpen && (j.scheduledDate == null || j.machineId == null),
        )
        .length;
    if (machines.isEmpty) {
      return const EmptyState(
        icon: Icons.precision_manufacturing_outlined,
        title: 'No machines yet',
        message:
            'Add your embroidery machines, presses and printers under Company Assets (category: Machine) with their daily hours.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(
                () => _weekStart = _weekStart.subtract(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              'Week of ${DateFormat('d MMM').format(_weekStart)}',
              style: theme.textTheme.titleMedium,
            ),
            IconButton(
              onPressed: () => setState(
                () => _weekStart = _weekStart.add(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
            const Spacer(),
            if (unscheduled > 0)
              Chip(label: Text('$unscheduled job(s) not scheduled')),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Machine')),
              for (final d in days)
                DataColumn(label: Text(DateFormat('EEE d').format(d))),
            ],
            rows: [
              for (final m in machines)
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        '${m.name}\n${(m.dailyCapacityMinutes / 60).round()} h/day',
                      ),
                    ),
                    for (final d in days)
                      DataCell(() {
                        final mins = booked(m.id, d);
                        final load = m.dailyCapacityMinutes == 0
                            ? 0.0
                            : mins / m.dailyCapacityMinutes;
                        final color = load > 1
                            ? theme.colorScheme.errorContainer
                            : load > 0.8
                            ? Colors.orange.withValues(alpha: 0.25)
                            : load > 0
                            ? Colors.green.withValues(alpha: 0.2)
                            : null;
                        return Container(
                          width: 72,
                          padding: const EdgeInsets.all(6),
                          color: color,
                          child: Text(
                            mins == 0
                                ? '—'
                                : '${(mins / 60).toStringAsFixed(1)} h\n${(load * 100).round()}%',
                          ),
                        );
                      }()),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Red = overbooked; orange = over 80% of the day.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
