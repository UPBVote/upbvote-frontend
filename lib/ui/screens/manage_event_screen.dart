import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/event_models.dart';
import '../../services/event_service.dart';

class ManageEventScreen extends StatefulWidget {
  /// Pasa un evento existente para editar, o null para crear uno nuevo.
  final EventSummary? event;

  const ManageEventScreen({super.key, this.event});

  @override
  State<ManageEventScreen> createState() => _ManageEventScreenState();
}

class _ManageEventScreenState extends State<ManageEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  DateTime? _uploadOpen;
  DateTime? _uploadClose;
  DateTime? _juryOpen;
  DateTime? _juryClose;

  bool _isSaving = false;
  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl.text = widget.event!.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(BuildContext context, {DateTime? initial}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFB71C1C)),
        ),
        child: child!,
      ),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFB71C1C)),
        ),
        child: child!,
      ),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return 'Seleccionar';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEditing) {
      if (_uploadOpen == null || _uploadClose == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completa las fechas de subida de proyectos')),
        );
        return;
      }
      if (_uploadOpen!.isAfter(_uploadClose!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La fecha de apertura debe ser antes del cierre')),
        );
        return;
      }
    }
    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        final body = <String, dynamic>{'name': _nameCtrl.text.trim()};
        final schedules = <Map<String, dynamic>>[];
        if (_uploadOpen != null && _uploadClose != null) {
          schedules.add({
            'type': 'UPLOAD',
            'openDate': _uploadOpen!.toUtc().toIso8601String(),
            'closeDate': _uploadClose!.toUtc().toIso8601String(),
          });
        }
        if (_juryOpen != null && _juryClose != null) {
          schedules.add({
            'type': 'JURY_VOTE',
            'openDate': _juryOpen!.toUtc().toIso8601String(),
            'closeDate': _juryClose!.toUtc().toIso8601String(),
          });
        }
        if (schedules.isNotEmpty) body['schedules'] = schedules;
        await EventService.updateEvent(widget.event!.id, body);
      } else {
        await EventService.createEvent(
          name: _nameCtrl.text.trim(),
          uploadOpen: _uploadOpen!,
          uploadClose: _uploadClose!,
          juryOpen: _juryOpen,
          juryClose: _juryClose,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? '¡Evento actualizado exitosamente!'
                : '¡Evento creado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _isEditing ? 'Editar Evento' : 'Crear Evento',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Nombre ──────────────────────────────────────────────────────
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del evento *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 24),

            // ── Período subida ───────────────────────────────────────────────
            _scheduleSection(
              title: 'Período de subida de proyectos',
              subtitle: _isEditing ? 'Opcional — deja vacío para no cambiar' : 'Requerido *',
              icon: Icons.upload_file,
              openDate: _uploadOpen,
              closeDate: _uploadClose,
              onPickOpen: () async {
                final dt = await _pickDateTime(context, initial: _uploadOpen);
                if (dt != null) setState(() => _uploadOpen = dt);
              },
              onPickClose: () async {
                final dt = await _pickDateTime(context, initial: _uploadClose ?? _uploadOpen);
                if (dt != null) setState(() => _uploadClose = dt);
              },
              onClear: () => setState(() { _uploadOpen = null; _uploadClose = null; }),
            ),
            const SizedBox(height: 16),

            // ── Período jurado ───────────────────────────────────────────────
            _scheduleSection(
              title: 'Período de votación del jurado',
              subtitle: 'Opcional',
              icon: Icons.rate_review_outlined,
              openDate: _juryOpen,
              closeDate: _juryClose,
              onPickOpen: () async {
                final dt = await _pickDateTime(context, initial: _juryOpen ?? _uploadClose);
                if (dt != null) setState(() => _juryOpen = dt);
              },
              onPickClose: () async {
                final dt = await _pickDateTime(context, initial: _juryClose ?? _juryOpen);
                if (dt != null) setState(() => _juryClose = dt);
              },
              onClear: () => setState(() { _juryOpen = null; _juryClose = null; }),
            ),
            const SizedBox(height: 32),

            // ── Botón ────────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _isEditing ? 'Actualizar evento' : 'Crear evento',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required DateTime? openDate,
    required DateTime? closeDate,
    required VoidCallback onPickOpen,
    required VoidCallback onPickClose,
    required VoidCallback onClear,
  }) {
    final hasData = openDate != null || closeDate != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFFB71C1C)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (hasData)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                  tooltip: 'Limpiar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dateButton(
                  label: 'Apertura',
                  value: _fmt(openDate),
                  onTap: onPickOpen,
                  hasValue: openDate != null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateButton(
                  label: 'Cierre',
                  value: _fmt(closeDate),
                  onTap: onPickClose,
                  hasValue: closeDate != null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required String value,
    required VoidCallback onTap,
    required bool hasValue,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: hasValue ? const Color(0xFFB71C1C) : Colors.grey[600],
        side: BorderSide(
            color: hasValue ? const Color(0xFFB71C1C) : Colors.grey[400]!),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
