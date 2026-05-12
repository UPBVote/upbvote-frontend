import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  final _memberSearchCtrl = TextEditingController();

  List<ProjectCourse> _courses = [];
  List<EventSummary> _events = [];
  List<WorkingGroup> _myGroups = [];
  List<ExposerProfile> _searchResults = [];
  List<ExposerProfile> _pendingMembers = [];

  ProjectCourse? _selectedCourse;
  EventSummary? _selectedEvent;
  WorkingGroup? _selectedGroup;

  // Main image
  String? _mainImagePath;
  String? _mainImageName;

  // Carrusel images (max 4)
  final List<Map<String, String>> _carruselImages = []; // [{path, name}]

  bool _isLoading = true;
  bool _isSaving = false;
  bool _creatingGroup = false;
  bool _isSearching = false;
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
    _memberSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
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
      print('API ERROR: ${e.message}');
      setState(() => _errorMessage = e.message);
    } catch (e, stack) {
      print('ERROR DESCONOCIDO: $e');
      print('STACK: $stack');
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMainImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _mainImagePath = result.files.single.path;
        _mainImageName = result.files.single.name;
      });
    }
  }

  Future<void> _addCarruselImage() async {
    if (_carruselImages.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Máximo 4 imágenes de carrusel permitidas.'),
        ),
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _carruselImages.add({
          'path': result.files.single.path!,
          'name': result.files.single.name,
        });
      });
    }
  }

  Future<void> _searchMembers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await WorkingGroupService.searchExposers(query.trim());
      setState(() => _searchResults = results);
    } catch (_) {
      setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
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
        _pendingMembers.clear();
        _searchResults.clear();
        _memberSearchCtrl.clear();
      });
      // Add pending members to the newly created group
      for (final m in _pendingMembers) {
        try {
          await WorkingGroupService.addMember(group.id, m.userId);
        } catch (_) {}
      }
      if (mounted) setState(() => _pendingMembers.clear());
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addMemberToExistingGroup(ExposerProfile exposer) async {
    if (_selectedGroup == null) return;
    try {
      final updated = await WorkingGroupService.addMember(
        _selectedGroup!.id,
        exposer.userId,
      );
      setState(() {
        final idx = _myGroups.indexWhere((g) => g.id == updated.id);
        if (idx != -1) _myGroups[idx] = updated;
        _selectedGroup = updated;
        _memberSearchCtrl.clear();
        _searchResults.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${exposer.displayName} agregado al grupo'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourse == null ||
        _selectedEvent == null ||
        _selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos requeridos')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final project = await ProjectService.createProject(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        courseId: _selectedCourse!.id,
        workingGroupId: _selectedGroup!.id,
        eventId: _selectedEvent!.id,
      );

      // Upload images if selected
      final hasImages = _mainImagePath != null || _carruselImages.isNotEmpty;
      if (hasImages) {
        try {
          final contentTypes = await ProjectService.getContentTypes();
          final mainType = contentTypes
              .where((t) => t.name.toUpperCase() == 'MAIN_IMAGE')
              .firstOrNull;
          final carruselType = contentTypes
              .where((t) => t.name.toUpperCase() == 'CARRUSEL_IMAGE')
              .firstOrNull;

          if (_mainImagePath != null && mainType != null) {
            await ProjectService.uploadFile(
              projectId: project.id,
              filePath: _mainImagePath!,
              mimeType: _mimeFromExtension(
                _mainImagePath!.split('.').last.toLowerCase(),
              ),
              contentTypeId: mainType.id,
            );
          }
          if (carruselType != null) {
            for (final img in _carruselImages) {
              await ProjectService.uploadFile(
                projectId: project.id,
                filePath: img['path']!,
                mimeType: _mimeFromExtension(
                  img['path']!.split('.').last.toLowerCase(),
                ),
                contentTypeId: carruselType.id,
              );
            }
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Proyecto creado, pero no se pudieron subir algunas imágenes.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Proyecto creado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _mimeFromExtension(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFC2185B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Registrar Proyecto',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFC2185B)),
            )
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
              backgroundColor: const Color(0xFFC2185B),
              foregroundColor: Colors.white,
            ),
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
            _noDataWarning(
              Icons.event,
              'No hay eventos activos con subida habilitada',
            )
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

          // Imagen principal
          _buildMainImageSection(),
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
                backgroundColor: const Color(0xFFC2185B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed:
                  (_isSaving ||
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
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Crear proyecto',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.image_outlined, size: 18, color: Color(0xFFC2185B)),
            SizedBox(width: 6),
            Text(
              'Imagen principal',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 6),
            Text(
              '(opcional)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _pickMainImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: 110,
            decoration: BoxDecoration(
              border: Border.all(
                color: _mainImagePath != null
                    ? const Color(0xFFC2185B)
                    : Colors.grey[300]!,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
              color: _mainImagePath != null
                  ? const Color(0xFFC2185B).withValues(alpha: 0.04)
                  : Colors.grey[50],
            ),
            child: _mainImagePath != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFFC2185B),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _mainImageName ?? '',
                          style: const TextStyle(
                            color: Color(0xFFC2185B),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: Colors.grey,
                        onPressed: () => setState(() {
                          _mainImagePath = null;
                          _mainImageName = null;
                        }),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 32,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Toca para seleccionar imagen',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                      Text(
                        'PNG, JPG — máx. 5MB',
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ),
          ),
        ),

        // Carrusel images (hasta 4)
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 16,
              color: Color(0xFFC2185B),
            ),
            const SizedBox(width: 6),
            const Text(
              'Imágenes de carrusel',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Text(
              '(hasta 4)',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const Spacer(),
            if (_carruselImages.length < 4)
              TextButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                label: const Text('Agregar'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC2185B),
                ),
                onPressed: _addCarruselImage,
              ),
          ],
        ),
        if (_carruselImages.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...List.generate(_carruselImages.length, (i) {
            final img = _carruselImages[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFC2185B).withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFC2185B).withValues(alpha: 0.03),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.image_outlined,
                    color: Color(0xFFC2185B),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      img['name'] ?? '',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${i + 1}/4',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: Colors.grey,
                    onPressed: () =>
                        setState(() => _carruselImages.removeAt(i)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildGroupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.group_outlined,
              size: 18,
              color: Color(0xFFC2185B),
            ),
            const SizedBox(width: 6),
            const Text(
              'Grupo de trabajo *',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              icon: Icon(_creatingGroup ? Icons.close : Icons.add, size: 16),
              label: Text(_creatingGroup ? 'Cancelar' : 'Nuevo grupo'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC2185B),
              ),
              onPressed: () => setState(() {
                _creatingGroup = !_creatingGroup;
                _pendingMembers.clear();
                _searchResults.clear();
                _memberSearchCtrl.clear();
              }),
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
                  backgroundColor: const Color(0xFFC2185B),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSaving ? null : _createGroup,
                child: const Text('Crear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMemberSearch(isNewGroup: true),
        ] else if (_myGroups.isEmpty) ...[
          _noDataWarning(
            Icons.group_off,
            'No tienes grupos. Toca "Nuevo grupo" para crear uno.',
          ),
        ] else ...[
          _buildDropdown<WorkingGroup>(
            label: 'Seleccionar grupo',
            icon: Icons.group_outlined,
            value: _selectedGroup,
            items: _myGroups,
            itemLabel: (g) => g.name,
            onChanged: (v) => setState(() => _selectedGroup = v),
          ),
          if (_selectedGroup != null) ...[
            const SizedBox(height: 12),
            _buildMemberSearch(isNewGroup: false),
          ],
        ],
      ],
    );
  }

  Widget _buildMemberSearch({required bool isNewGroup}) {
    final currentMembers = isNewGroup
        ? _pendingMembers.map((e) => e.displayName).toList()
        : (_selectedGroup?.members.map((m) => m.displayName).toList() ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_add_outlined, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            const Text(
              'Agregar integrantes',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _memberSearchCtrl,
          decoration: InputDecoration(
            hintText: 'Buscar expositor por nombre...',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onChanged: _searchMembers,
        ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: _searchResults.take(5).map((e) {
                final alreadyAdded = isNewGroup
                    ? _pendingMembers.any((m) => m.userId == e.userId)
                    : (_selectedGroup?.members.any((m) => m.id == e.id) ??
                          false);
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(
                      0xFFC2185B,
                    ).withValues(alpha: 0.12),
                    child: Text(
                      e.displayName.isNotEmpty
                          ? e.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFFC2185B),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    e.displayName,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    e.userName,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: alreadyAdded
                      ? const Icon(Icons.check, color: Colors.green, size: 18)
                      : IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Color(0xFFC2185B),
                            size: 20,
                          ),
                          onPressed: () {
                            if (isNewGroup) {
                              setState(() {
                                _pendingMembers.add(e);
                                _memberSearchCtrl.clear();
                                _searchResults.clear();
                              });
                            } else {
                              _addMemberToExistingGroup(e);
                            }
                          },
                        ),
                );
              }).toList(),
            ),
          ),
        ],
        if (currentMembers.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: currentMembers
                .map(
                  (name) => Chip(
                    label: Text(name, style: const TextStyle(fontSize: 12)),
                    avatar: const Icon(Icons.person, size: 14),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(
                      0xFFC2185B,
                    ).withValues(alpha: 0.08),
                  ),
                )
                .toList(),
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
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
                ),
              )
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
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.orange[800]),
            ),
          ),
        ],
      ),
    );
  }
}
