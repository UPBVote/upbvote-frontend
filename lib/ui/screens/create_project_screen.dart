import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/project_models.dart';
import '../../models/event_models.dart';
import '../../services/project_service.dart';
import '../../services/event_service.dart';
import '../../services/working_group_service.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _groupNameCtrl = TextEditingController();

  List<ProjectCourse> _courses = [];
  List<EventSummary> _events = [];
  List<WorkingGroup> _myGroups = [];

  ProjectCourse? _selectedCourse;
  EventSummary? _selectedEvent;
  WorkingGroup? _selectedGroup;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _creatingGroup = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        ProjectService.getCourses(),
        EventService.getActiveEvents(),
        WorkingGroupService.getMyGroups(),
      ]);
      setState(() {
        _courses = results[0] as List<ProjectCourse>;
        _events = results[1] as List<EventSummary>;
        _myGroups = results[2] as List<WorkingGroup>;
        if (_courses.isNotEmpty) _selectedCourse = _courses.first;
        if (_events.isNotEmpty) _selectedEvent = _events.first;
        if (_myGroups.isNotEmpty) _selectedGroup = _myGroups.first;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createGroup() async {
    final name = _groupNameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final group = await WorkingGroupService.createGroup(name);
      setState(() {
        _myGroups = [group, ..._myGroups];
        _selectedGroup = group;
        _creatingGroup = false;
        _groupNameCtrl.clear();
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourse == null || _selectedEvent == null || _selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos requeridos')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ProjectService.createProject(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        courseId: _selectedCourse!.id,
        workingGroupId: _selectedGroup!.id,
        eventId: _selectedEvent!.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Proyecto creado exitosamente!'),
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
        title: const Text('Registrar Proyecto',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)))
          : _errorMessage != null
              ? _buildError()
              : _buildForm(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white),
            onPressed: _loadData,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Título
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Título del proyecto *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),

          // Descripción
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
          ),
          const SizedBox(height: 16),

          // Materia
          if (_courses.isEmpty)
            _noDataWarning(Icons.book_outlined, 'No hay materias disponibles')
          else
            _buildDropdown<ProjectCourse>(
              label: 'Materia *',
              icon: Icons.book_outlined,
              value: _selectedCourse,
              items: _courses,
              itemLabel: (c) => c.name,
              onChanged: (v) => setState(() => _selectedCourse = v),
            ),
          const SizedBox(height: 16),

          // Evento
          if (_events.isEmpty)
            _noDataWarning(Icons.event, 'No hay eventos activos con subida habilitada')
          else
            _buildDropdown<EventSummary>(
              label: 'Evento *',
              icon: Icons.event,
              value: _selectedEvent,
              items: _events,
              itemLabel: (e) => e.name,
              onChanged: (v) => setState(() => _selectedEvent = v),
            ),
          const SizedBox(height: 16),

          // Grupo de trabajo
          _buildGroupSection(),
          const SizedBox(height: 32),

          // Botón enviar
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
              onPressed: (_isSaving ||
                      _courses.isEmpty ||
                      _events.isEmpty ||
                      (_myGroups.isEmpty && !_creatingGroup))
                  ? null
                  : _submit,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Crear proyecto',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.group_outlined,
                size: 18, color: Color(0xFFB71C1C)),
            const SizedBox(width: 6),
            const Text('Grupo de trabajo *',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              icon: Icon(
                  _creatingGroup ? Icons.close : Icons.add,
                  size: 16),
              label: Text(_creatingGroup ? 'Cancelar' : 'Nuevo grupo'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB71C1C)),
              onPressed: () =>
                  setState(() => _creatingGroup = !_creatingGroup),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_creatingGroup) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _groupNameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Nombre del grupo',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white),
                onPressed: _isSaving ? null : _createGroup,
                child: const Text('Crear'),
              ),
            ],
          ),
        ] else if (_myGroups.isEmpty) ...[
          _noDataWarning(Icons.group_off,
              'No tienes grupos. Toca "Nuevo grupo" para crear uno.'),
        ] else ...[
          _buildDropdown<WorkingGroup>(
            label: 'Seleccionar grupo',
            icon: Icons.group_outlined,
            value: _selectedGroup,
            items: _myGroups,
            itemLabel: (g) => g.name,
            onChanged: (v) => setState(() => _selectedGroup = v),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemLabel(item),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _noDataWarning(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange[700], size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 13, color: Colors.orange[800])),
          ),
        ],
      ),
    );
  }
}
