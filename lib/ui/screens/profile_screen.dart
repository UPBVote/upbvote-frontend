import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/api_client.dart';
import '../../models/profile_models.dart';
import '../../services/profile_service.dart';
import '../../services/role_request_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  String? _errorMessage;
  bool _requestingRole = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await ProfileService.getMyProfile(AppState.role ?? 'Votante');
      setState(() => _profile = profile);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Error de conexión. Verifica que el servidor esté activo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestExpositorRole() async {
    final namesCtrl = TextEditingController();
    final lastNamesCtrl = TextEditingController();
    final studentIDCtrl = TextEditingController();
    String? gender;
    DateTime? birthDate;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Solicitar rol de Expositor'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: namesCtrl,
                    decoration: const InputDecoration(labelText: 'Nombres *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: lastNamesCtrl,
                    decoration: const InputDecoration(labelText: 'Apellidos *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: studentIDCtrl,
                    decoration: const InputDecoration(labelText: 'Código de estudiante *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Género *'),
                    value: gender,
                    items: const [
                      DropdownMenuItem(value: 'M', child: Text('Masculino')),
                      DropdownMenuItem(value: 'F', child: Text('Femenino')),
                      DropdownMenuItem(value: 'O', child: Text('Otro')),
                    ],
                    onChanged: (v) => setDlg(() => gender = v),
                    validator: (v) => v == null ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(birthDate == null
                        ? 'Fecha de nacimiento *'
                        : 'Nacimiento: ${birthDate!.day}/${birthDate!.month}/${birthDate!.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime(2000),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDlg(() => birthDate = picked);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate() && birthDate != null) {
                  Navigator.pop(ctx, true);
                } else if (birthDate == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Selecciona tu fecha de nacimiento')),
                  );
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _requestingRole = true);
    try {
      await RoleRequestService.createRequest({
        'names': namesCtrl.text.trim(),
        'lastNames': lastNamesCtrl.text.trim(),
        'studentID': studentIDCtrl.text.trim(),
        'gender': gender!,
        'birthDate': '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud enviada. Un secretario la revisará pronto.'),
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
    } finally {
      if (mounted) setState(() => _requestingRole = false);
    }
  }

  String _getInitials() {
    final p = _profile;
    if (p?.names != null && p!.names!.isNotEmpty) {
      return p.names!.trim()[0].toUpperCase();
    }
    final name = AppState.userName ?? 'U';
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String _getDisplayName() {
    final p = _profile;
    if (p?.names != null && p!.names!.isNotEmpty) {
      final lastName = p.lastNames?.split(' ').first ?? '';
      return '${p.names} $lastName'.trim();
    }
    return AppState.userName ?? 'Usuario';
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Expositor':  return const Color(0xFF1565C0);
      case 'Jurado':     return const Color(0xFF7B1FA2);
      case 'Secretario': return const Color(0xFF2E7D32);
      case 'Admin':      return const Color(0xFFC2185B);
      default:           return const Color(0xFFC2185B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC2185B)))
          : _errorMessage != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC2185B),
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadProfile,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final role = AppState.role ?? 'Votante';
    final roleColor = _roleColor(role);

    return CustomScrollView(
      slivers: [
        // --- Banner rojo con avatar ---
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: const Color(0xFFC2185B),
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Mi Perfil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFC2185B), Color(0xFF7B1FA2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: Colors.white,
                        child: Text(
                          _getInitials(),
                          style: const TextStyle(
                            color: Color(0xFFC2185B),
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _getDisplayName(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- Contenido ---
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              children: [
                // Badge de rol con gradiente
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [roleColor, roleColor.withValues(alpha: 0.75)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: roleColor.withValues(alpha: 0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Tarjeta de información
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Información de cuenta',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Divider(height: 24),
                        _infoRow(Icons.person_outline, 'Usuario', AppState.userName ?? '-'),
                        _infoRow(Icons.email_outlined, 'Correo', AppState.email ?? '-'),
                        ..._roleSpecificRows(role),
                      ],
                    ),
                  ),
                ),

                if (role == 'Votante') ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quiero ser Expositor',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Solicita el rol de Expositor para poder subir y presentar proyectos en las jornadas.',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC2185B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: _requestingRole
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.upload_outlined, size: 18),
                              label: Text(_requestingRole
                                  ? 'Enviando solicitud...'
                                  : 'Solicitar rol de Expositor'),
                              onPressed: _requestingRole ? null : _requestExpositorRole,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _roleSpecificRows(String role) {
    final p = _profile;
    if (p == null) return [];

    switch (role) {
      case 'Expositor':
        return [
          if (p.names != null)     _infoRow(Icons.badge_outlined,   'Nombres',              p.names!),
          if (p.lastNames != null)  _infoRow(Icons.badge_outlined,   'Apellidos',            p.lastNames!),
          if (p.studentId != null)  _infoRow(Icons.school_outlined,  'Código estudiantil',   p.studentId!),
          if (p.gender != null)     _infoRow(Icons.wc_outlined,      'Género',               p.gender!),
          if (p.birthDate != null)  _infoRow(Icons.cake_outlined,    'Fecha de nacimiento',  p.birthDate!),
        ];
      case 'Jurado':
        return [
          if (p.names != null)     _infoRow(Icons.badge_outlined,  'Nombres',             p.names!),
          if (p.lastNames != null)  _infoRow(Icons.badge_outlined,  'Apellidos',           p.lastNames!),
          if (p.gender != null)     _infoRow(Icons.wc_outlined,     'Género',              p.gender!),
          if (p.birthDate != null)  _infoRow(Icons.cake_outlined,   'Fecha de nacimiento', p.birthDate!),
        ];
      default:
        return [];
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFC2185B)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
