import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/api_client.dart';
import '../../models/event_models.dart';
import '../../services/event_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'project_list_screen.dart';
import 'my_projects_screen.dart';
import 'manage_event_screen.dart';
import 'role_requests_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userRole;
  const HomeScreen({super.key, required this.userRole});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<EventSummary> _events = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final events = widget.userRole == 'Secretario'
          ? await EventService.getEvents()
          : await EventService.getActiveEvents();
      setState(() => _events = events);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() {
    AppState.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _onNavTap(int index) {
    final itemCount = _navItems().length;
    if (index == itemCount - 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      return;
    }
    if (index == 1 && widget.userRole == 'Expositor') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProjectsScreen()));
      return;
    }
    if (index == 1 && (widget.userRole == 'Jurado' || widget.userRole == 'Secretario')) {
      _showResultsEventPicker();
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _showResultsEventPicker() {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay eventos disponibles')),
      );
      return;
    }
    if (_events.length == 1) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProjectListScreen(
          userRole: widget.userRole,
          eventId: _events.first.id,
          eventName: _events.first.name,
        ),
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Selecciona un evento',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(),
          ..._events.map((e) => ListTile(
            leading: const Icon(Icons.event, color: Color(0xFFB71C1C)),
            title: Text(e.name),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ProjectListScreen(
                  userRole: widget.userRole,
                  eventId: e.id,
                  eventName: e.name,
                ),
              ));
            },
          )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  List<BottomNavigationBarItem> _navItems() => [
    const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Eventos'),
    if (widget.userRole == 'Expositor')
      const BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Mi Proyecto'),
    if (widget.userRole == 'Jurado' || widget.userRole == 'Secretario')
      const BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Resultados'),
    const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jornadas UPB', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD32F2F), Color(0xFF7F0000)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFB71C1C),
        unselectedItemColor: Colors.grey,
        onTap: _onNavTap,
        items: _navItems(),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFB71C1C), Color(0xFF7F0000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: Text(
              AppState.userName ?? 'Usuario UPB',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(AppState.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                (AppState.userName ?? 'U').isNotEmpty
                    ? AppState.userName![0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Color(0xFFB71C1C),
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Mi Perfil'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          if (widget.userRole == 'Secretario') ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.event, color: Color(0xFFB71C1C)),
              title: const Text('Gestionar Eventos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageEventScreen(),
                  ),
                ).then((created) {
                  if (created == true) _loadEvents();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_ind, color: Color(0xFFB71C1C)),
              title: const Text('Solicitudes de Rol'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RoleRequestsScreen(),
                  ),
                );
              },
            ),
          ],
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                onPressed: _loadEvents,
              ),
            ],
          ),
        ),
      );
    }
    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay eventos disponibles',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFFB71C1C),
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, index) => _buildEventCard(_events[index]),
      ),
    );
  }

  Widget _buildEventCard(EventSummary event) {
    final statusInfo = _statusInfo(event.status.description);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: statusInfo.$1.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectListScreen(
              userRole: widget.userRole,
              eventId: event.id,
              eventName: event.name,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [Colors.white, statusInfo.$1.withValues(alpha: 0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusInfo.$1, statusInfo.$1.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: statusInfo.$1.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.event_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusInfo.$1,
                            boxShadow: [
                              BoxShadow(
                                color: statusInfo.$1.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusInfo.$1.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusInfo.$2,
                            style: TextStyle(
                              color: statusInfo.$1,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusInfo.$1.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: statusInfo.$1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Retorna (color, label) según el status del evento
  (Color, String) _statusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'UPLOADING':
        return (Colors.green[700]!, 'Activo');
      case 'VOTING':
        return (Colors.blue[700]!, 'En votación');
      case 'UPCOMING':
        return (Colors.orange[700]!, 'Próximo');
      case 'CLOSED':
        return (Colors.grey[600]!, 'Cerrado');
      default:
        return (Colors.grey[600]!, status);
    }
  }
}
