import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/project_models.dart';
import '../../services/project_service.dart';
import 'project_detail_screen.dart';
import 'create_project_screen.dart';

class MyProjectsScreen extends StatefulWidget {
  const MyProjectsScreen({super.key});

  @override
  State<MyProjectsScreen> createState() => _MyProjectsScreenState();
}

class _MyProjectsScreenState extends State<MyProjectsScreen> {
  List<ProjectSummary> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final projects = await ProjectService.getMyProjects();
      setState(() => _projects = projects);
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
        title: const Text('Mi Proyecto', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo proyecto'),
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
          );
          if (created == true) _load();
        },
      ),
    );
  }

  Widget _buildBody() {
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
              onPressed: _load,
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
            Icon(Icons.folder_open, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No tienes proyectos todavía',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Toca "Nuevo proyecto" para comenzar',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFFB71C1C),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _projects.length,
        itemBuilder: (_, i) => _buildCard(_projects[i]),
      ),
    );
  }

  Widget _buildCard(ProjectSummary p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(
              userRole: 'Expositor',
              projectId: p.id,
              projectTitle: p.title,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder, color: Color(0xFFB71C1C), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (p.course != null) ...[
                      const SizedBox(height: 4),
                      Text(p.course!.name,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                    if (p.state != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB71C1C).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(p.state!.name,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFFB71C1C))),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
