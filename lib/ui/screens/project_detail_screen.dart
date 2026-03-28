import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../models/project_models.dart';
import '../../models/comment_models.dart';
import '../../services/project_service.dart';
import '../../services/comment_service.dart';
import 'vote_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String userRole;
  final String projectId;
  final String projectTitle;

  const ProjectDetailScreen({
    super.key,
    required this.userRole,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ProjectDetail? _project;
  bool _isLoading = true;
  String? _errorMessage;

  // Content tab state
  ProjectContent? _content;
  bool _isLoadingContent = false;
  String? _contentError;
  List<ContentType> _contentTypes = [];
  List<LinkType> _linkTypes = [];

  // Comments tab state
  List<Comment> _comments = [];
  bool _isLoadingComments = false;
  String? _commentsError;
  List<CommentType> _commentTypes = [];
  bool _commentsLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProject();
    _tabController.addListener(() {
      if (_tabController.index == 1 && _content == null && !_isLoadingContent) {
        _loadContent();
      }
      if (_tabController.index == 2 && !_commentsLoaded && !_isLoadingComments) {
        _loadComments();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final project = await ProjectService.getProjectDetail(widget.projectId);
      setState(() => _project = project);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadContent() async {
    setState(() { _isLoadingContent = true; _contentError = null; });
    try {
      final results = await Future.wait([
        ProjectService.getProjectContent(widget.projectId),
        ProjectService.getContentTypes(),
        ProjectService.getLinkTypes(),
      ]);
      setState(() {
        _content = results[0] as ProjectContent;
        _contentTypes = results[1] as List<ContentType>;
        _linkTypes = results[2] as List<LinkType>;
      });
    } on ApiException catch (e) {
      setState(() => _contentError = e.message);
    } catch (_) {
      setState(() => _contentError = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _isLoadingContent = false);
    }
  }

  Future<void> _showUploadFileDialog() async {
    if (_contentTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay tipos de contenido disponibles')),
      );
      return;
    }
    ContentType? selectedType = _contentTypes.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Subir archivo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tipo de archivo', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButton<ContentType>(
                    value: selectedType,
                    isExpanded: true,
                    items: _contentTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedType = v),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white),
              onPressed: () async {
                // Strip leading dots: backend sends ".pdf" but FilePicker needs "pdf"
                final extensions = selectedType!.allowedExtensions
                    .map((e) => e.startsWith('.') ? e.substring(1) : e)
                    .toList();
                Navigator.pop(ctx);
                final result = await FilePicker.platform.pickFiles(
                  allowedExtensions: extensions.isEmpty ? null : extensions,
                  type: extensions.isEmpty ? FileType.any : FileType.custom,
                );
                if (result == null || result.files.single.path == null) return;
                final file = result.files.single;
                // Use mime type from content type's allowed_mime_types or detect from extension
                final mimeType = _mimeFromExtension(file.extension ?? '');
                try {
                  await ProjectService.uploadFile(
                    projectId: widget.projectId,
                    filePath: file.path!,
                    mimeType: mimeType,
                    contentTypeId: selectedType!.id,
                  );
                  _loadContent();
                } on ApiException catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Seleccionar archivo'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddLinkDialog() async {
    if (_linkTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay tipos de enlace disponibles')),
      );
      return;
    }

    final result = await showDialog<({String url, String name, String typeId})>(
      context: context,
      builder: (ctx) => _AddLinkDialog(linkTypes: _linkTypes),
    );

    if (result == null || !mounted) return;
    try {
      await ProjectService.addLink(
        projectId: widget.projectId,
        url: result.url,
        displayName: result.name,
        linkTypeId: result.typeId,
      );
      if (mounted) _loadContent();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _confirmDeleteFile(ProjectFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text('¿Eliminar "${file.fileName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ProjectService.deleteFile(widget.projectId, file.id);
      _loadContent();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _confirmDeleteLink(ProjectLink link) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar enlace'),
        content: Text('¿Eliminar "${link.displayName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ProjectService.deleteLink(widget.projectId, link.id);
      _loadContent();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.projectTitle)),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C))),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.projectTitle)),
        body: Center(
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
                onPressed: _loadProject,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final p = _project!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD32F2F), Color(0xFF7F0000)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        title: Text(
          p.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          _buildHeaderCard(p),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFB71C1C),
            unselectedLabelColor: Colors.grey[400],
            indicatorColor: const Color(0xFFB71C1C),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Info'),
              Tab(icon: Icon(Icons.attach_file, size: 18), text: 'Contenido'),
              Tab(icon: Icon(Icons.chat_bubble_outline, size: 18), text: 'Comentarios'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(p),
                _buildContentTab(),
                _buildCommentsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildHeaderCard(ProjectDetail p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7F0000), Color(0xFF263238)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          if (p.course != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Text(
                p.course!.name,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 12),
          ],
          _buildStars(p.averagePublicScore),
          const SizedBox(width: 7),
          Text(
            p.averagePublicScore.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${p.totalVoters} votos',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB INFO ────────────────────────────────────────────────────────────
  Widget _buildInfoTab(ProjectDetail p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Descripción
          const Text('Descripción',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(p.description.isNotEmpty ? p.description : 'Sin descripción.',
              style: const TextStyle(fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),

          // Detalles
          _infoCard([
            if (p.course != null)
              _infoRow(Icons.book_outlined, 'Materia', p.course!.name),
            if (p.state != null)
              _infoRow(Icons.info_outline, 'Estado', p.state!.name),
            if (p.publicationDate.isNotEmpty)
              _infoRow(Icons.calendar_today_outlined, 'Publicado',
                  _formatDate(p.publicationDate)),
          ]),
          const SizedBox(height: 20),

          // Grupo de trabajo
          if (p.workingGroup != null) ...[
            const Text('Grupo de Trabajo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            _buildWorkingGroupCard(p.workingGroup!),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> rows) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: rows),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFB71C1C)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingGroupCard(WorkingGroup group) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group_outlined,
                    color: Color(0xFFB71C1C), size: 20),
                const SizedBox(width: 8),
                Text(group.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            if (group.members.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Integrantes',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              ...group.members.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              const Color(0xFFB71C1C).withValues(alpha: 0.12),
                          child: Text(
                            m.displayName.isNotEmpty
                                ? m.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Color(0xFFB71C1C),
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(m.displayName,
                            style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  // ─── TAB CONTENIDO ───────────────────────────────────────────────────────
  Widget _buildContentTab() {
    if (_isLoadingContent) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)));
    }
    if (_contentError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_contentError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white),
              onPressed: _loadContent,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_content == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Selecciona esta pestaña para cargar el contenido',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final isExpositor = widget.userRole == 'Expositor';
    final files = _content!.files;
    final links = _content!.links;
    final isEmpty = files.isEmpty && links.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botones de acción para Expositor
          if (isExpositor) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Subir archivo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB71C1C),
                      side: const BorderSide(color: Color(0xFFB71C1C)),
                    ),
                    onPressed: _showUploadFileDialog,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Agregar enlace'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF263238),
                      side: const BorderSide(color: Color(0xFF263238)),
                    ),
                    onPressed: _showAddLinkDialog,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open, size: 56, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('Sin contenido todavía',
                        style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                  ],
                ),
              ),
            ),

          // Archivos
          if (files.isNotEmpty) ...[
            _sectionHeader(Icons.insert_drive_file_outlined, 'Archivos', files.length),
            const SizedBox(height: 8),
            ...files.map((f) => _buildFileCard(f, isExpositor)),
            const SizedBox(height: 20),
          ],

          // Enlaces
          if (links.isNotEmpty) ...[
            _sectionHeader(Icons.link, 'Enlaces', links.length),
            const SizedBox(height: 8),
            ...links.map((l) => _buildLinkCard(l, isExpositor)),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, int count) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFB71C1C)),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFB71C1C).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFFB71C1C), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildFileCard(ProjectFile file, bool canDelete) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFB71C1C).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.insert_drive_file, color: Color(0xFFB71C1C), size: 22),
        ),
        title: Text(file.fileName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text('${file.contentType.name} · ${file.readableSize}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: canDelete
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => _confirmDeleteFile(file),
              )
            : null,
      ),
    );
  }

  Widget _buildLinkCard(ProjectLink link, bool canDelete) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF263238).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.link, color: Color(0xFF263238), size: 22),
        ),
        title: Text(link.displayName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(link.linkType.name,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: canDelete
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => _confirmDeleteLink(link),
              )
            : const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
        onTap: () async {
          var urlString = link.url.trim();
          if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
            urlString = 'https://$urlString';
          }
          try {
            await launchUrl(Uri.parse(urlString), mode: LaunchMode.externalApplication);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No se pudo abrir el enlace')),
              );
            }
          }
        },
      ),
    );
  }

  // ─── TAB COMENTARIOS ─────────────────────────────────────────────────────
  Future<void> _loadComments() async {
    setState(() { _isLoadingComments = true; _commentsError = null; });
    try {
      final results = await Future.wait([
        CommentService.getComments(widget.projectId),
        CommentService.getCommentTypes(),
      ]);
      setState(() {
        _comments = results[0] as List<Comment>;
        _commentTypes = results[1] as List<CommentType>;
        _commentsLoaded = true;
      });
    } on ApiException catch (e) {
      setState(() => _commentsError = e.message);
    } catch (_) {
      setState(() => _commentsError = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _showAddCommentDialog() async {
    final publicType = _commentTypes.where((t) => t.name == 'PUBLIC').firstOrNull;
    final anonType = _commentTypes.where((t) => t.name == 'ANONYMOUS').firstOrNull;
    if (publicType == null && anonType == null) return;

    final result = await showDialog<({String comment, String typeId})>(
      context: context,
      builder: (ctx) => _AddCommentDialog(
        publicTypeId: publicType?.id,
        anonTypeId: anonType?.id,
      ),
    );

    if (result == null || !mounted) return;
    try {
      await CommentService.createComment(
        projectId: widget.projectId,
        comment: result.comment,
        commentTypeId: result.typeId,
      );
      if (mounted) _loadComments();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildCommentsTab() {
    if (_isLoadingComments) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFB71C1C)));
    }
    if (_commentsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_commentsError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  foregroundColor: Colors.white),
              onPressed: _loadComments,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (!_commentsLoaded) {
      return Center(
        child: Text('Selecciona esta pestaña para cargar comentarios',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center),
      );
    }

    return Column(
      children: [
        // Botón agregar comentario
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_comment_outlined, size: 18),
              label: const Text('Agregar comentario'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB71C1C),
                side: const BorderSide(color: Color(0xFFB71C1C)),
              ),
              onPressed: _showAddCommentDialog,
            ),
          ),
        ),
        Expanded(
          child: _comments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 56, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('Sin comentarios todavía',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 15)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFB71C1C),
                  onRefresh: _loadComments,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) => _buildCommentCard(_comments[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteComment(Comment comment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar comentario'),
        content: const Text('¿Eliminar este comentario? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CommentService.deleteComment(widget.projectId, comment.id);
      _loadComments();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildCommentCard(Comment comment) {
    final isAnon = comment.isAnonymous;
    final canModerate = widget.userRole == 'Secretario';
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isAnon
                      ? Colors.grey[300]
                      : const Color(0xFFB71C1C).withValues(alpha: 0.12),
                  child: Icon(
                    isAnon ? Icons.person_off : Icons.person,
                    size: 16,
                    color: isAnon ? Colors.grey[600] : const Color(0xFFB71C1C),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAnon ? 'Anónimo' : 'Usuario',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        _formatDate(comment.dateTime),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAnon
                        ? Colors.grey[200]
                        : const Color(0xFFB71C1C).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isAnon ? 'Anónimo' : 'Público',
                    style: TextStyle(
                      fontSize: 10,
                      color: isAnon ? Colors.grey[700] : const Color(0xFFB71C1C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(comment.text,
                      style: const TextStyle(fontSize: 14, height: 1.4)),
                ),
                if (canModerate)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    tooltip: 'Eliminar comentario',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _confirmDeleteComment(comment),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── FAB por rol ─────────────────────────────────────────────────────────
  Widget? _buildFab() {
    switch (widget.userRole) {
      case 'Votante':
        return FloatingActionButton.extended(
          backgroundColor: const Color(0xFFB71C1C),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.star),
          label: const Text('Votar'),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VoteScreen(
                  projectId: widget.projectId,
                  projectTitle: widget.projectTitle,
                ),
              ),
            );
            if (result == true) _loadProject();
          },
        );
      case 'Jurado':
        return FloatingActionButton.extended(
          backgroundColor: const Color(0xFF263238),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.rate_review),
          label: const Text('Evaluar'),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VoteScreen(
                  projectId: widget.projectId,
                  projectTitle: widget.projectTitle,
                  isJury: true,
                ),
              ),
            );
            if (result == true) _loadProject();
          },
        );
      default:
        return null;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  Widget _buildStars(double score) {
    final full = score.floor().clamp(0, 5);
    final hasHalf = (score - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) return const Icon(Icons.star, color: Colors.amber, size: 18);
        if (i == full && hasHalf) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 18);
        }
        return const Icon(Icons.star_border, color: Colors.amber, size: 18);
      }),
    );
  }

  String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'mp4': return 'video/mp4';
      case 'mov': return 'video/quicktime';
      case 'avi': return 'video/x-msvideo';
      case 'png': return 'image/png';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      default: return 'application/octet-stream';
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ─── Diálogo agregar enlace ───────────────────────────────────────────────────
class _AddLinkDialog extends StatefulWidget {
  final List<LinkType> linkTypes;
  const _AddLinkDialog({required this.linkTypes});

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _urlCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  late LinkType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.linkTypes.first;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar enlace'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                  labelText: 'URL', border: OutlineInputBorder()),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nombre a mostrar', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text('Tipo', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.linkTypes.map((t) => ChoiceChip(
                label: Text(t.name),
                selected: _selectedType == t,
                selectedColor: const Color(0xFFB71C1C).withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: _selectedType == t ? const Color(0xFFB71C1C) : null,
                  fontWeight: _selectedType == t ? FontWeight.w600 : null,
                ),
                onSelected: (_) => setState(() => _selectedType = t),
              )).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white),
          onPressed: () {
            final url = _urlCtrl.text.trim();
            final name = _nameCtrl.text.trim();
            if (url.isEmpty || name.isEmpty) return;
            Navigator.pop(context, (url: url, name: name, typeId: _selectedType.id));
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

// ─── Diálogo agregar comentario ───────────────────────────────────────────────
class _AddCommentDialog extends StatefulWidget {
  final String? publicTypeId;
  final String? anonTypeId;

  const _AddCommentDialog({
    required this.publicTypeId,
    required this.anonTypeId,
  });

  @override
  State<_AddCommentDialog> createState() => _AddCommentDialogState();
}

class _AddCommentDialogState extends State<_AddCommentDialog> {
  final _textCtrl = TextEditingController();
  bool _isAnonymous = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar comentario'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textCtrl,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText: 'Escribe tu comentario...',
              border: OutlineInputBorder(),
            ),
          ),
          if (widget.anonTypeId != null)
            CheckboxListTile(
              value: _isAnonymous,
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFFB71C1C),
              title: const Text('Publicar anónimamente',
                  style: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _isAnonymous = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white),
          onPressed: () {
            final comment = _textCtrl.text.trim();
            if (comment.isEmpty) return;
            final typeId = (_isAnonymous && widget.anonTypeId != null)
                ? widget.anonTypeId!
                : widget.publicTypeId!;
            Navigator.pop(context, (comment: comment, typeId: typeId));
          },
          child: const Text('Publicar'),
        ),
      ],
    );
  }
}
