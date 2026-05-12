import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({bool reset = false}) async {
    if (reset) _currentPage = 1;
    setState(() { _loading = true; _error = null; });
    try {
      final q = _searchCtrl.text.trim();
      final search = q.isNotEmpty ? '&search=${Uri.encodeComponent(q)}' : '';
      final data = await ApiClient.get('/users/?page=$_currentPage$search');
      final list = (data is Map && data['data'] is List) ? data['data'] as List : [];
      setState(() {
        _users = list.map((e) => e as Map<String, dynamic>).toList();
        _totalPages = (data is Map) ? (data['totalPages'] as int? ?? 1) : 1;
        _currentPage = (data is Map) ? (data['currentPage'] as int? ?? 1) : 1;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAssignJuryDialog(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este usuario no tiene ID registrado')),
      );
      return;
    }

    final namesCtrl = TextEditingController();
    final lastNamesCtrl = TextEditingController();
    String? selectedGender;
    DateTime? birthDate;
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickDate() async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: ctx,
              initialDate: birthDate ?? DateTime(now.year - 20),
              firstDate: DateTime(1950),
              lastDate: DateTime(now.year - 16),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.light(primary: Color(0xFFC2185B)),
                ),
                child: child!,
              ),
            );
            if (picked != null) setDialogState(() => birthDate = picked);
          }

          Future<void> submit() async {
            if (!formKey.currentState!.validate()) return;
            if (birthDate == null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Selecciona la fecha de nacimiento')),
              );
              return;
            }
            if (selectedGender == null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Selecciona el género')),
              );
              return;
            }
            setDialogState(() => saving = true);
            try {
              await ApiClient.post(
                '/profiles/$userId/assign-jury/',
                {
                  'names': namesCtrl.text.trim(),
                  'lastNames': lastNamesCtrl.text.trim(),
                  'birthDate': '${birthDate!.year.toString().padLeft(4, '0')}-'
                      '${birthDate!.month.toString().padLeft(2, '0')}-'
                      '${birthDate!.day.toString().padLeft(2, '0')}',
                  'gender': selectedGender,
                },
                requiresAuth: true,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${user['userName']} ahora es Jurado'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadUsers(reset: true);
              }
            } on ApiException catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(e.message), backgroundColor: Colors.red),
                );
              }
            } finally {
              setDialogState(() => saving = false);
            }
          }

          final birthStr = birthDate != null
              ? '${birthDate!.day.toString().padLeft(2, '0')}/'
                '${birthDate!.month.toString().padLeft(2, '0')}/'
                '${birthDate!.year}'
              : 'Seleccionar';

          return AlertDialog(
            title: Text('Convertir a Jurado: ${user['userName']}'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: namesCtrl,
                      decoration: const InputDecoration(labelText: 'Nombres *', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: lastNamesCtrl,
                      decoration: const InputDecoration(labelText: 'Apellidos *', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGender,
                      decoration: const InputDecoration(labelText: 'Género *', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'M', child: Text('Masculino')),
                        DropdownMenuItem(value: 'F', child: Text('Femenino')),
                        DropdownMenuItem(value: 'O', child: Text('Otro')),
                      ],
                      onChanged: (v) => setDialogState(() => selectedGender = v),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: pickDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('Fecha de nac.: $birthStr', style: const TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC2185B),
                        side: const BorderSide(color: Color(0xFFC2185B)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: saving ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC2185B),
                  foregroundColor: Colors.white,
                ),
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Asignar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Usuarios', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar usuario...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadUsers(reset: true);
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _loadUsers(reset: true),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC2185B)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: () => _loadUsers(reset: true), child: const Text('Reintentar')),
                          ],
                        ),
                      )
                    : _users.isEmpty
                        ? const Center(child: Text('No se encontraron usuarios', style: TextStyle(color: Colors.grey)))
                        : RefreshIndicator(
                            color: const Color(0xFFC2185B),
                            onRefresh: () => _loadUsers(reset: true),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _users.length + (_totalPages > 1 ? 1 : 0),
                              itemBuilder: (ctx, i) {
                                if (i == _users.length) {
                                  return _buildPagination();
                                }
                                return _buildUserCard(_users[i]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final type = (user['type'] ?? '').toString();
    final state = (user['userState'] ?? '').toString();
    final isActive = state == 'ACTIVE';

    Color typeColor;
    switch (type) {
      case 'JURY': typeColor = Colors.purple; break;
      case 'EXPOSER': typeColor = Colors.orange; break;
      case 'SECRETARY': typeColor = Colors.blue; break;
      case 'ADMIN': typeColor = const Color(0xFF6A1B9A); break;
      default: typeColor = Colors.green;
    }

    String typeLabel;
    switch (type) {
      case 'JURY': typeLabel = 'Jurado'; break;
      case 'EXPOSER': typeLabel = 'Expositor'; break;
      case 'SECRETARY': typeLabel = 'Secretario'; break;
      case 'ADMIN': typeLabel = 'Admin'; break;
      default: typeLabel = 'Votante';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: typeColor.withValues(alpha: 0.15),
          child: Text(
            (user['userName'] ?? 'U').toString().isNotEmpty
                ? (user['userName'] as String)[0].toUpperCase()
                : 'U',
            style: TextStyle(color: typeColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          (user['userName'] ?? '').toString(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((user['email'] ?? '').toString(), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(typeLabel, style: TextStyle(fontSize: 11, color: typeColor, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'Activo' : 'Inactivo',
                    style: TextStyle(fontSize: 11, color: isActive ? Colors.green[700] : Colors.red[700]),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: type == 'VOTER'
            ? IconButton(
                icon: const Icon(Icons.gavel, color: Color(0xFFC2185B)),
                tooltip: 'Convertir a Jurado',
                onPressed: () => _showAssignJuryDialog(user),
              )
            : null,
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () { setState(() => _currentPage--); _loadUsers(); }
                : null,
          ),
          Text('$_currentPage / $_totalPages', style: const TextStyle(fontWeight: FontWeight.w500)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () { setState(() => _currentPage++); _loadUsers(); }
                : null,
          ),
        ],
      ),
    );
  }
}
