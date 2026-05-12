import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/api_client.dart';
import '../../models/event_models.dart';
import '../../services/event_service.dart';

class ManageEventScreen extends StatefulWidget {
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

  // Jury selection
  List<JuryProfileSummary> _allJuries = [];
  List<JuryProfileSummary> _filteredJuries = [];
  final Set<String> _selectedJuryProfileIds = {};
  final _jurySearchCtrl = TextEditingController();
  bool _loadingJuries = false;

  // Schedule PDF (edit mode)
  Map<String, dynamic>? _existingSchedule;
  bool _loadingSchedule = false;
  String? _pickedPdfPath;
  String? _pickedPdfName;
  bool _uploadingPdf = false;
  bool _deletingPdf = false;

  bool _isSaving = false;
  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl.text = widget.event!.name;
      _loadExistingSchedule();
    }
    _loadJuries();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _jurySearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadJuries() async {
    setState(() => _loadingJuries = true);
    try {
      final juries = await EventService.getJuryProfiles();
      setState(() {
        _allJuries = juries;
        _filteredJuries = juries;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingJuries = false);
    }
  }

  void _filterJuries(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredJuries = _allJuries
          .where((j) =>
              j.displayName.toLowerCase().contains(q) ||
              j.userName.toLowerCase().contains(q))
          .toList();
    });
  }

  Future<void> _loadExistingSchedule() async {
    setState(() => _loadingSchedule = true);
    try {
      final schedule = await EventService.getEventSchedule(widget.event!.id);
      if (mounted) setState(() => _existingSchedule = schedule);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingSchedule = false);
    }
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
          colorScheme: const ColorScheme.light(primary: Color(0xFFC2185B)),
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
          colorScheme: const ColorScheme.light(primary: Color(0xFFC2185B)),
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

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedPdfPath = result.files.single.path;
        _pickedPdfName = result.files.single.name;
      });
    }
  }

  Future<void> _uploadSchedulePdf() async {
    if (_pickedPdfPath == null) return;
    setState(() => _uploadingPdf = true);
    try {
      await EventService.uploadEventSchedule(widget.event!.id, _pickedPdfPath!);
      await _loadExistingSchedule();
      setState(() {
        _pickedPdfPath = null;
        _pickedPdfName = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cronograma subido exitosamente'), backgroundColor: Colors.green),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPdf = false);
    }
  }

  Future<void> _deleteSchedulePdf() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cronograma'),
        content: const Text('¿Estás seguro de que quieres eliminar el PDF del cronograma?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deletingPdf = true);
    try {
      await EventService.deleteEventSchedule(widget.event!.id);
      setState(() => _existingSchedule = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cronograma eliminado'), backgroundColor: Colors.orange),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingPdf = false);
    }
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
        if (_selectedJuryProfileIds.isNotEmpty) {
          body['juryIds'] = _selectedJuryProfileIds.toList();
        }
        await EventService.updateEvent(widget.event!.id, body);
      } else {
        final newEvent = await EventService.createEvent(
          name: _nameCtrl.text.trim(),
          uploadOpen: _uploadOpen!,
          uploadClose: _uploadClose!,
          juryOpen: _juryOpen,
          juryClose: _juryClose,
          juryIds: _selectedJuryProfileIds.toList(),
        );
        if (_pickedPdfPath != null) {
          try {
            await EventService.uploadEventSchedule(newEvent.id, _pickedPdfPath!);
          } catch (_) {}
        }
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
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _isEditing ? 'Editar Evento' : 'Crear Evento',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFC2185B), Color(0xFF7B1FA2)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
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
            const SizedBox(height: 16),

            // ── Jurado ───────────────────────────────────────────────────────
            _jurySection(),
            const SizedBox(height: 16),

            // ── Cronograma PDF ───────────────────────────────────────────────
            _schedulePdfSection(),
            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // ── Cerrar evento (solo edición) ─────────────────────────────────
            if (_isEditing) ...[
              _deactivateButton(),
              const SizedBox(height: 12),
            ],

            // ── Botón ────────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC2185B), Color(0xFF7B1FA2)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC2185B).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _deactivateButton() {
    return OutlinedButton.icon(
      onPressed: _isSaving ? null : () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cerrar evento'),
            content: const Text('¿Estás seguro? El evento pasará a estado Finalizado y no podrá editarse.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Cerrar evento'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        setState(() => _isSaving = true);
        try {
          await EventService.deactivateEvent(widget.event!.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Evento cerrado'), backgroundColor: Colors.orange),
            );
            Navigator.pop(context, true);
          }
        } on ApiException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _isSaving = false);
        }
      },
      icon: const Icon(Icons.lock_outline, color: Colors.red),
      label: const Text('Cerrar evento', style: TextStyle(color: Colors.red)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _jurySection() {
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
              const Icon(Icons.people_outline, size: 18, color: Color(0xFFC2185B)),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jurado del evento',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Opcional — selecciona los jurados',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              if (_selectedJuryProfileIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC2185B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedJuryProfileIds.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _jurySearchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar jurado...',
              prefixIcon: const Icon(Icons.search, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: _filterJuries,
          ),
          const SizedBox(height: 8),
          if (_loadingJuries)
            const Center(child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else if (_filteredJuries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No hay jurados disponibles', style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredJuries.length,
                itemBuilder: (ctx, i) {
                  final jury = _filteredJuries[i];
                  final selected = _selectedJuryProfileIds.contains(jury.profileId);
                  return CheckboxListTile(
                    dense: true,
                    value: selected,
                    title: Text(jury.displayName, style: const TextStyle(fontSize: 13)),
                    subtitle: Text('@${jury.userName}', style: const TextStyle(fontSize: 11)),
                    activeColor: const Color(0xFFC2185B),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedJuryProfileIds.add(jury.profileId);
                        } else {
                          _selectedJuryProfileIds.remove(jury.profileId);
                        }
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _schedulePdfSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFFC2185B)),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cronograma (PDF)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Opcional — adjunta el cronograma del evento',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingSchedule)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_existingSchedule != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _existingSchedule!['fileName']?.toString() ?? 'Cronograma.pdf',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_deletingPdf)
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Eliminar cronograma',
                      onPressed: _deleteSchedulePdf,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickPdf,
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Reemplazar PDF', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC2185B),
                side: const BorderSide(color: Color(0xFFC2185B)),
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: _pickPdf,
              icon: const Icon(Icons.attach_file, size: 16),
              label: const Text('Seleccionar PDF', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC2185B),
                side: const BorderSide(color: Color(0xFFC2185B)),
              ),
            ),
          ],
          if (_pickedPdfPath != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pickedPdfName ?? 'archivo.pdf',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_uploadingPdf)
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    TextButton(
                      onPressed: _uploadSchedulePdf,
                      child: const Text('Subir', style: TextStyle(fontSize: 13)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() {
                      _pickedPdfPath = null;
                      _pickedPdfName = null;
                    }),
                  ),
                ],
              ),
            ),
          ],
        ],
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
              Icon(icon, size: 18, color: const Color(0xFFC2185B)),
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
        foregroundColor: hasValue ? const Color(0xFFC2185B) : Colors.grey[600],
        side: BorderSide(
            color: hasValue ? const Color(0xFFC2185B) : Colors.grey[400]!),
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
