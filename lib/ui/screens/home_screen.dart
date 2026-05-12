import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/api_client.dart';
import '../../models/event_models.dart';
import '../../models/project_models.dart';
import '../../services/event_service.dart';
import '../../services/project_service.dart';
import '../../services/notification_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'project_list_screen.dart';
import 'project_detail_screen.dart';
import 'my_projects_screen.dart';
import 'manage_event_screen.dart';
import 'role_requests_screen.dart';
import 'users_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userRole;
  const HomeScreen({super.key, required this.userRole});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Events tab
  List<EventSummary> _events = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Projects tab (todos los roles)
  final _projectSearchCtrl = TextEditingController();
  List<ProjectSummary> _projects = [];
  bool _projectsLoading = false;
  bool _projectsInitialized = false;
  String? _projectsError;
  int _projectsPage = 1;
  int _projectsTotalPages = 1;
  String _projectsOrder = 'score_desc';

  List<ProjectSummary> get _sortedProjects {
    final copy = List<ProjectSummary>.from(_projects);
    copy.sort((a, b) {
      if (_projectsOrder == 'score_asc') {
        final diff = a.averagePublicScore - b.averagePublicScore;
        return diff < 0 ? -1 : diff > 0 ? 1 : 0;
      } else if (_projectsOrder == 'date_asc') {
        return a.publicationDate.compareTo(b.publicationDate);
      } else if (_projectsOrder == 'date_desc') {
        return b.publicationDate.compareTo(a.publicationDate);
      } else {
        final diff = b.averagePublicScore - a.averagePublicScore;
        return diff < 0 ? -1 : diff > 0 ? 1 : 0;
      }
    });
    return copy;
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _projectSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final events = (widget.userRole == 'Secretario' || widget.userRole == 'Admin')
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

  Future<void> _loadProjects({bool reset = false}) async {
    if (reset) _projectsPage = 1;
    setState(() { _projectsLoading = true; _projectsError = null; _projectsInitialized = true; });
    try {
      final result = await ProjectService.getProjects(
        page: _projectsPage,
        search: _projectSearchCtrl.text.trim(),
        order: _projectsOrder,
      );
      setState(() {
        _projects = result.data;
        _projectsTotalPages = result.totalPages;
        _projectsPage = result.currentPage;
      });
    } on ApiException catch (e) {
      setState(() => _projectsError = e.message);
    } catch (_) {
      setState(() => _projectsError = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _projectsLoading = false);
    }
  }

  Future<void> _logout() async {
    await NotificationService.deactivateToken();
    AppState.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _onNavTap(int index) {
    final itemCount = _navItems().length;
    // Perfil siempre es el último tab
    if (index == itemCount - 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      return;
    }
    // Expositor: tab 2 = Mi Proyecto → navega a MyProjectsScreen
    if (index == 2 && widget.userRole == 'Expositor') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProjectsScreen()));
      return;
    }
    // Tab 1 = Proyectos — cargar si es primera visita
    if (index == 1 && !_projectsInitialized) {
      _loadProjects();
    }
    setState(() => _selectedIndex = index);
  }

  List<BottomNavigationBarItem> _navItems() => [
    const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Eventos'),
    const BottomNavigationBarItem(icon: Icon(Icons.folder_open_rounded), label: 'Proyectos'),
    if (widget.userRole == 'Expositor')
      const BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Mi Proyecto'),
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
              colors: [Color(0xFFC2185B), Color(0xFF7B1FA2)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            tooltip: 'Notificaciones',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No tienes notificaciones nuevas.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedIndex == 1) {
                _loadProjects(reset: true);
              } else {
                _loadEvents();
              }
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFC2185B),
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
                colors: [Color(0xFFC2185B), Color(0xFF7B1FA2)],
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
                  color: Color(0xFFC2185B),
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
          if (widget.userRole == 'Secretario' || widget.userRole == 'Admin') ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.event, color: Color(0xFFC2185B)),
              title: const Text('Crear Evento'),
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
              leading: const Icon(Icons.assignment_ind, color: Color(0xFFC2185B)),
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
            ListTile(
              leading: const Icon(Icons.people, color: Color(0xFFC2185B)),
              title: const Text('Usuarios'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UsersScreen()),
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
    if (_selectedIndex == 1) {
      return _buildProjectsTab();
    }
    return _buildEventsTab();
  }

  // ─── Events Tab ────────────────────────────────────────────────────────────

  Widget _buildEventsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFC2185B)));
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
                  backgroundColor: const Color(0xFFC2185B),
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
      color: const Color(0xFFC2185B),
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
    final isClosed = event.status.description.toUpperCase() == 'CLOSED';
    return Opacity(
      opacity: isClosed ? 0.6 : 1.0,
      child: Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isClosed ? 1 : 4,
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
              if (widget.userRole == 'Secretario' || widget.userRole == 'Admin')
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManageEventScreen(event: event),
                    ),
                  ).then((updated) { if (updated == true) _loadEvents(); }),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_outlined, size: 16, color: Colors.blue[700]),
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
    ),
    );
  }

  // ─── Projects Tab (Votante) ─────────────────────────────────────────────────

  Widget _buildProjectsTab() {
    return Column(
      children: [
        _buildProjectSearchBar(),
        _buildProjectSortBar(),
        Expanded(child: _buildProjectList()),
        if (_projectsTotalPages > 1) _buildProjectPagination(),
      ],
    );
  }

  Widget _buildProjectSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _projectSearchCtrl,
        decoration: InputDecoration(
          hintText: 'Buscar proyecto, materia o integrante...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _projectSearchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _projectSearchCtrl.clear();
                    _loadProjects(reset: true);
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onSubmitted: (_) => _loadProjects(reset: true),
      ),
    );
  }

  Widget _buildProjectSortBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFC2185B).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_projects.length} proyectos',
              style: const TextStyle(
                color: Color(0xFFC2185B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _projectsOrder,
              icon: const Icon(Icons.sort_rounded, size: 18, color: Color(0xFFC2185B)),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              items: const [
                DropdownMenuItem(value: 'score_desc', child: Text('Mayor puntaje')),
                DropdownMenuItem(value: 'score_asc', child: Text('Menor puntaje')),
                DropdownMenuItem(value: 'date_desc', child: Text('Más recientes')),
                DropdownMenuItem(value: 'date_asc', child: Text('Más antiguos')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _projectsOrder = val);
                _loadProjects(reset: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList() {
    if (_projectsLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFC2185B)));
    }
    if (_projectsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_projectsError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC2185B), foregroundColor: Colors.white),
              onPressed: () => _loadProjects(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_projects.isEmpty && _projectsInitialized) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No se encontraron proyectos',
                style: TextStyle(fontSize: 15, color: Colors.grey[600])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFFC2185B),
      onRefresh: () => _loadProjects(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: _sortedProjects.length,
        itemBuilder: (context, index) => _buildProjectCard(_sortedProjects[index]),
      ),
    );
  }

  Widget _buildProjectCard(ProjectSummary project) {
    final courseColor = _courseColor(project.course?.name ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 3,
      shadowColor: courseColor.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectDetailScreen(
                userRole: widget.userRole,
                projectId: project.id,
                projectTitle: project.title,
              ),
            ),
          );
          if (mounted && _selectedIndex == 1) _loadProjects(reset: true);
        },
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 7,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [courseColor, courseColor.withValues(alpha: 0.5)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              project.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.amber[600]!, Colors.amber[400]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.white, size: 13),
                                const SizedBox(width: 3),
                                Text(
                                  project.averagePublicScore.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (project.course != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: courseColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.book_outlined, size: 12, color: courseColor),
                              const SizedBox(width: 4),
                              Text(
                                project.course!.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: courseColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      _buildStars(project.averagePublicScore),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.arrow_forward_ios_rounded, size: 14,
                    color: courseColor.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStars(double score) {
    final full = score.floor().clamp(0, 5);
    final hasHalf = (score - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) return const Icon(Icons.star, color: Colors.amber, size: 16);
        if (i == full && hasHalf) return const Icon(Icons.star_half, color: Colors.amber, size: 16);
        return const Icon(Icons.star_border, color: Colors.amber, size: 16);
      }),
    );
  }

  Widget _buildProjectPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _projectsPage > 1
                ? () { setState(() => _projectsPage--); _loadProjects(); }
                : null,
          ),
          Text('$_projectsPage / $_projectsTotalPages',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _projectsPage < _projectsTotalPages
                ? () { setState(() => _projectsPage++); _loadProjects(); }
                : null,
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  (Color, String) _statusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'UPLOADING':
        return (Colors.green[700]!, 'Abierto');
      case 'VOTING':
        return (Colors.blue[700]!, 'En votación');
      case 'UPCOMING':
        return (Colors.orange[700]!, 'Próximamente');
      case 'CLOSED':
        return (Colors.grey[500]!, 'Finalizado');
      default:
        return (Colors.grey[500]!, status);
    }
  }

  Color _courseColor(String courseName) {
    final colors = [
      Colors.blue[700]!,
      Colors.purple[700]!,
      Colors.teal[700]!,
      Colors.orange[700]!,
      Colors.indigo[700]!,
      Colors.green[700]!,
    ];
    if (courseName.isEmpty) return Colors.grey[400]!;
    return colors[courseName.codeUnitAt(0) % colors.length];
  }
}
