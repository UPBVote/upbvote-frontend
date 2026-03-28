import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/project_models.dart';
import '../../services/project_service.dart';
import 'project_detail_screen.dart';

class ProjectListScreen extends StatefulWidget {
  final String userRole;
  final String eventId;
  final String eventName;

  const ProjectListScreen({
    super.key,
    required this.userRole,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  final _searchController = TextEditingController();
  List<ProjectSummary> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  String _order = 'score_desc';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _currentPage = 1;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final result = await ProjectService.getProjects(
        page: _currentPage,
        search: _searchController.text.trim(),
        order: _order,
        eventId: widget.eventId,
      );
      setState(() {
        _projects = result.data;
        _totalPages = result.totalPages;
        _currentPage = result.currentPage;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventName, style: const TextStyle(fontWeight: FontWeight.bold)),
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
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildSortBar(),
          Expanded(child: _buildList()),
          if (_totalPages > 1) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar proyecto, materia o integrante...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _load(reset: true);
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
        onSubmitted: (_) => _load(reset: true),
      ),
    );
  }

  Widget _buildSortBar() {
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
              color: const Color(0xFFB71C1C).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_projects.length} proyectos',
              style: const TextStyle(
                color: Color(0xFFB71C1C),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _order,
              icon: const Icon(Icons.sort_rounded, size: 18, color: Color(0xFFB71C1C)),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              items: const [
                DropdownMenuItem(value: 'score_desc', child: Text('Mayor puntaje')),
                DropdownMenuItem(value: 'score_asc', child: Text('Menor puntaje')),
                DropdownMenuItem(value: 'date_desc', child: Text('Más recientes')),
                DropdownMenuItem(value: 'date_asc', child: Text('Más antiguos')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _order = val);
                _load(reset: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)));
    }
    if (_errorMessage != null) {
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
              onPressed: () => _load(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_projects.isEmpty) {
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
      color: const Color(0xFFB71C1C),
      onRefresh: () => _load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: _projects.length,
        itemBuilder: (context, index) => _buildProjectCard(_projects[index]),
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
          if (mounted) _load(reset: true);
        },
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Borde gradiente por materia
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

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () { setState(() => _currentPage--); _load(); }
                : null,
          ),
          Text('$_currentPage / $_totalPages',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () { setState(() => _currentPage++); _load(); }
                : null,
          ),
        ],
      ),
    );
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
