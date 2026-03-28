import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/api_client.dart';
import '../../models/profile_models.dart';
import '../../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  String? _errorMessage;

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
      case 'Expositor':  return Colors.blue[700]!;
      case 'Jurado':     return Colors.orange[700]!;
      case 'Secretario': return Colors.green[700]!;
      default:           return const Color(0xFFB71C1C);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)))
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
                  backgroundColor: const Color(0xFFB71C1C),
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
          backgroundColor: const Color(0xFFB71C1C),
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Mi Perfil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              children: [
                // Fondo degradado
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFB71C1C), Color(0xFF7F0000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // Avatar + nombre centrados
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
                            color: Color(0xFFB71C1C),
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
                // Badge de rol
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: roleColor),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(
                      color: roleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
          Icon(icon, size: 20, color: const Color(0xFFB71C1C)),
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
