import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../models/project_models.dart';
import '../../models/comment_models.dart';
import '../../services/project_service.dart';
import '../../services/comment_service.dart';
import '../../models/vote_models.dart';
import '../../services/vote_service.dart';
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

  // Content state
  ProjectContent? _content;
  bool _isLoadingContent = false;
  String? _contentError;
  List<ContentType> _contentTypes = [];
  List<LinkType> _linkTypes = [];
  bool _contentLoaded = false;

  // Comments state
  List<Comment> _comments = [];
  bool _isLoadingComments = false;
  String? _commentsError;
  List<CommentType> _commentTypes = [];
  bool _commentsLoaded = false;

  // Jury feedback (Expositor only)
  JuryFeedback? _juryFeedback;
  bool _juryFeedbackLoaded = false;

  // Carousel
  int _carouselIndex = 0;
  late PageController _pageController;

  // Inline comment input (Comments tab)
  final _inlineCommentCtrl = TextEditingController();
  bool _isPostingComment = false;

  // Quick comment box in Info tab (Votante / Expositor)
  final _quickCommentCtrl = TextEditingController();
  bool _isQuickPosting = false;
  bool _commentIsAnonymous = false;

  // Content tab index
  static const int _tabContent = 1;
  static const int _tabComments = 2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pageController = PageController();
    _loadProject();
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
      if (_tabController.index == _tabContent && !_contentLoaded && !_isLoadingContent) {
        _loadContent();
      }
      if (_tabController.index == _tabComments && !_commentsLoaded && !_isLoadingComments) {
        _loadComments();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _inlineCommentCtrl.dispose();
    _quickCommentCtrl.dispose();
    super.dispose();
  }

  String _tr(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('jury voting schedule is not active') || m.contains('jury vote schedule')) {
      return 'El período de evaluación del jurado no está habilitado aún.';
    }
    if (m.contains('upload schedule is not active') || m.contains('upload schedule')) {
      return 'El período de subida de proyectos no está habilitado.';
    }
    if (m.contains('schedule is not active')) {
      return 'Esta función no está habilitada en este momento.';
    }
    if (m.contains('not active') || m.contains('inactive')) {
      return 'Este proyecto no está activo.';
    }
    if (m.contains('already voted') || m.contains('already exists')) {
      return 'Ya registraste tu voto para este proyecto.';
    }
    if (m.contains('not found')) return 'Recurso no encontrado.';
    if (m.contains('permission') || m.contains('forbidden')) return 'No tienes permisos para esta acción.';
    if (m.contains('unauthorized') || m.contains('authentication')) return 'Sesión expirada. Por favor vuelve a iniciar sesión.';
    if (m.contains('connection') || m.contains('network')) return 'Error de conexión. Verifica tu internet.';
    return msg;
  }

  Future<void> _loadProject() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final project = await ProjectService.getProjectDetail(widget.projectId);
      setState(() => _project = project);
      if (widget.userRole == 'Expositor') _loadJuryFeedback();
    } on ApiException catch (e) {
      setState(() => _errorMessage = _tr(e.message));
    } catch (_) {
      setState(() => _errorMessage = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadJuryFeedback() async {
    try {
      final feedback = await VoteService.getJuryFeedback(widget.projectId);
      if (mounted) setState(() { _juryFeedback = feedback; _juryFeedbackLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _juryFeedbackLoaded = true);
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
      if (!mounted) return;
      setState(() {
        _content = results[0] as ProjectContent;
        _contentTypes = results[1] as List<ContentType>;
        _linkTypes = results[2] as List<LinkType>;
        _contentLoaded = true;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _contentError = _tr(e.message));
    } catch (_) {
      if (mounted) setState(() => _contentError = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _isLoadingContent = false);
    }
  }

  Future<void> _loadComments() async {
    setState(() { _isLoadingComments = true; _commentsError = null; });
    try {
      final results = await Future.wait([
        CommentService.getComments(widget.projectId),
        CommentService.getCommentTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _comments = (results[0] as List<Comment>)
            .where((c) => c.commentType.name.toUpperCase() != 'JURY')
            .toList();
        _commentTypes = results[1] as List<CommentType>;
        _commentsLoaded = true;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _commentsError = _tr(e.message));
    } catch (_) {
      if (mounted) setState(() => _commentsError = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _postInlineComment() async {
    final text = _inlineCommentCtrl.text.trim();
    if (text.isEmpty) return;
    if (_commentTypes.isEmpty) await _loadComments();
    final targetName = _commentIsAnonymous ? 'ANONYMOUS' : 'PUBLIC';
    final type = _commentTypes
        .where((t) => t.name.toUpperCase() == targetName)
        .firstOrNull ?? _commentTypes.firstOrNull;
    if (type == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo determinar el tipo de comentario.')),
        );
      }
      return;
    }
    setState(() => _isPostingComment = true);
    try {
      await CommentService.createComment(
        projectId: widget.projectId,
        comment: text,
        commentTypeId: type.id,
      );
      _inlineCommentCtrl.clear();
      await _loadComments();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr(e.message)), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al publicar comentario.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  Future<void> _postQuickComment() async {
    final text = _quickCommentCtrl.text.trim();
    if (text.isEmpty) return;
    if (_commentTypes.isEmpty) await _loadComments();
    final targetName = _commentIsAnonymous ? 'ANONYMOUS' : 'PUBLIC';
    final type = _commentTypes
        .where((t) => t.name.toUpperCase() == targetName)
        .firstOrNull ?? _commentTypes.firstOrNull;
    if (type == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo determinar el tipo de comentario.')),
        );
      }
      return;
    }
    setState(() => _isQuickPosting = true);
    try {
      await CommentService.createComment(
        projectId: widget.projectId,
        comment: text,
        commentTypeId: type.id,
      );
      _quickCommentCtrl.clear();
      await _loadComments();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr(e.message)), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al publicar comentario.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isQuickPosting = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(widget.projectTitle),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFC2185B))),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: _buildAppBar(widget.projectTitle),
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
                    backgroundColor: const Color(0xFFC2185B), foregroundColor: Colors.white),
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
      appBar: _buildAppBar(p.title),
      body: Column(
        children: [
          // Tab bar always visible at top
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFC2185B),
            unselectedLabelColor: Colors.grey[400],
            indicatorColor: const Color(0xFFC2185B),
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

  AppBar _buildAppBar(String title) {
    return AppBar(
      backgroundColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFC2185B), Color(0xFF7B1FA2)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ─── TAB INFO ─────────────────────────────────────────────────────────────
  Widget _buildInfoTab(ProjectDetail p) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título grande
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              p.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                height: 1.25,
                letterSpacing: -0.3,
              ),
            ),
          ),

          // Carrusel de imágenes
          _buildCarousel(p),

          // Estrellas + puntuación
          _buildScoreSection(p),

          // Materia + fecha
          if (p.course != null || p.publicationDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (p.course != null)
                    _chipInfo(Icons.book_outlined, p.course!.name, const Color(0xFF1565C0)),
                  if (p.publicationDate.isNotEmpty)
                    _chipInfo(Icons.calendar_today_outlined,
                        _formatDate(p.publicationDate), Colors.grey[700]!),
                ],
              ),
            ),

          // Integrantes del grupo
          if (p.workingGroup != null) _buildMembersSection(p.workingGroup!),

          const Divider(height: 1),

          // Descripción
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Descripción',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  p.description.isNotEmpty ? p.description : 'Sin descripción.',
                  style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
                ),
              ],
            ),
          ),

          // Botón Ver diagramas
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.account_tree_outlined, size: 18),
                label: const Text('Ver diagramas'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC2185B),
                  side: const BorderSide(color: Color(0xFFC2185B)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  _tabController.animateTo(_tabContent);
                },
              ),
            ),
          ),

          // Sección enlaces relacionados
          _buildRelatedLinksSection(),

          // Retroalimentación del jurado (solo Expositor)
          if (widget.userRole == 'Expositor') _buildJuryFeedbackSection(),

          const Divider(height: 1),

          // Comentarios al fondo (YouTube style)
          _buildInlineComments(),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ─── CARRUSEL ─────────────────────────────────────────────────────────────
  Widget _buildCarousel(ProjectDetail p) {
    // We build slides from content once loaded; meanwhile show placeholder
    final slides = _buildCarouselSlides();
    if (slides.isEmpty) {
      return Container(
        height: 220,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text('Sin imágenes',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 220,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _carouselIndex = i),
                  itemBuilder: (_, i) => slides[i],
                ),
                if (slides.length > 1) ...[
                  // Prev button
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          if (_carouselIndex > 0) {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_left,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                  // Next button
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          if (_carouselIndex < slides.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_right,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                  // Dots
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _carouselIndex ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _carouselIndex
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
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

  List<Widget> _buildCarouselSlides() {
    if (_content == null) {
      // Trigger lazy load
      if (!_contentLoaded && !_isLoadingContent) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadContent());
      }
      return [];
    }

    final slides = <Widget>[];

    // 1. Main image first
    final mainImages = _content!.files
        .where((f) => f.contentType.name.toUpperCase() == 'MAIN_IMAGE')
        .toList();
    for (final img in mainImages) {
      slides.add(_imageSlide(ApiClient.fixMediaUrl(img.url), img.fileName));
    }

    // 2. Video second (show thumbnail with play icon)
    final videos = _content!.files
        .where((f) => f.contentType.name.toUpperCase() == 'VIDEO')
        .toList();
    for (final v in videos) {
      slides.add(_videoSlide(v));
    }

    // 3. Carousel images
    final carouselImages = _content!.files
        .where((f) => f.contentType.name.toUpperCase() == 'CARRUSEL_IMAGE')
        .take(4)
        .toList();
    for (final img in carouselImages) {
      slides.add(_imageSlide(ApiClient.fixMediaUrl(img.url), img.fileName));
    }

    return slides;
  }

  Widget _imageSlide(String url, String name) {
    return Container(
      color: Colors.black,
      child: url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    ),
              errorBuilder: (context, e, _) => Center(
                child: Icon(Icons.broken_image, color: Colors.grey[600], size: 48),
              ),
            )
          : Center(
              child: Icon(Icons.image_outlined, color: Colors.grey[600], size: 48),
            ),
    );
  }

  Widget _videoSlide(ProjectFile video) {
    if (video.url.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(child: Icon(Icons.videocam_off, color: Colors.white38, size: 48)),
      );
    }
    return _InlineVideoPlayer(url: video.url, fileName: video.fileName);
  }

  // ─── SCORE SECTION ────────────────────────────────────────────────────────
  Widget _buildScoreSection(ProjectDetail p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          _buildStars(p.averagePublicScore),
          const SizedBox(width: 8),
          Text(
            p.averagePublicScore.toStringAsFixed(1),
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF263238)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${p.totalVoters} ${p.totalVoters == 1 ? 'voto' : 'votos'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MEMBERS SECTION ──────────────────────────────────────────────────────
  Widget _buildMembersSection(WorkingGroup group) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_outlined, size: 16, color: Color(0xFFC2185B)),
              const SizedBox(width: 6),
              Text(group.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: group.members.map((m) => _memberChip(m)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _memberChip(WorkingGroupMember m) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFFC2185B).withValues(alpha: 0.1),
          child: Text(
            m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Color(0xFFC2185B), fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 6),
        Text(m.displayName, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  // ─── JURY FEEDBACK (Expositor only) ─────────────────────────────────────────
  Widget _buildJuryFeedbackSection() {
    if (!_juryFeedbackLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF263238)),
        )),
      );
    }
    final fb = _juryFeedback;
    final hasEvaluations = fb != null && fb.evaluations.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF263238).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rate_review, size: 18, color: Color(0xFF263238)),
              ),
              const SizedBox(width: 10),
              const Text(
                'Retroalimentación del Jurado',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (hasEvaluations) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF263238), Color(0xFF455A64)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        fb.totalAverage.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (hasEvaluations)
            ...fb.evaluations.map((e) => _buildJuryEvaluationCard(e))
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined, size: 36, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Aún no hay retroalimentación del jurado',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJuryEvaluationCard(JuryEvaluation e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF263238).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF263238).withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF263238).withValues(alpha: 0.12),
                child: Text(
                  e.juryName.isNotEmpty ? e.juryName[0].toUpperCase() : 'J',
                  style: const TextStyle(
                    color: Color(0xFF263238),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.juryName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      e.score.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (e.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              e.comment,
              style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  // ─── RELATED LINKS ────────────────────────────────────────────────────────
  Widget _buildRelatedLinksSection() {
    if (!_contentLoaded) return const SizedBox.shrink();
    final links = _content?.links ?? [];
    if (links.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.link, size: 16, color: Color(0xFFC2185B)),
              SizedBox(width: 6),
              Text('Enlaces relacionados',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          ...links.map((l) => _buildLinkPreviewCard(l)),
        ],
      ),
    );
  }

  Widget _buildLinkPreviewCard(ProjectLink link) {
    final isYouTube = link.url.contains('youtube.com') ||
        link.url.contains('youtu.be');
    final isGitHub = link.url.contains('github.com');
    final isFigma = link.url.contains('figma.com');

    IconData icon;
    Color color;
    if (isYouTube) {
      icon = Icons.play_circle_filled;
      color = Colors.red[700]!;
    } else if (isGitHub) {
      icon = Icons.code;
      color = const Color(0xFF24292e);
    } else if (isFigma) {
      icon = Icons.design_services;
      color = Colors.purple[700]!;
    } else {
      icon = Icons.open_in_new;
      color = const Color(0xFF263238);
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _launchUrl(link.url),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(link.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      link.linkType.name,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      link.url,
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          decoration: TextDecoration.underline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  // ─── INLINE COMMENTS (YouTube style) ─────────────────────────────────────
  Widget _buildInlineComments() {
    if (!_commentsLoaded && !_isLoadingComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadComments());
    }

    final canComment = widget.userRole == 'Votante' || widget.userRole == 'Expositor';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline,
                  size: 16, color: Color(0xFFC2185B)),
              const SizedBox(width: 6),
              const Text('Comentarios',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (!canComment)
                TextButton.icon(
                  icon: const Icon(Icons.add_comment_outlined, size: 16),
                  label: const Text('Ver todos'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFC2185B)),
                  onPressed: () {
                    if (!_commentsLoaded) _loadComments();
                    _tabController.animateTo(_tabComments);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoadingComments)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFFC2185B)))
          else if (_commentsError != null)
            Text(_commentsError!,
                style: const TextStyle(color: Colors.red, fontSize: 13))
          else if (!_commentsLoaded)
            Text('Cargando comentarios...',
                style: TextStyle(color: Colors.grey[500], fontSize: 13))
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('Sin comentarios todavía',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ..._comments.take(3).map((c) => _buildCommentCard(c)),
          if (_comments.length > 3)
            TextButton(
              onPressed: () => _tabController.animateTo(_tabComments),
              child: Text(
                'Ver los ${_comments.length} comentarios →',
                style: const TextStyle(color: Color(0xFFC2185B)),
              ),
            ),
          // Quick comment box for Votante / Expositor
          if (canComment) ...[
            const SizedBox(height: 12),
            // Toggle anónimo
            GestureDetector(
              onTap: () => setState(() => _commentIsAnonymous = !_commentIsAnonymous),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _commentIsAnonymous ? Icons.person_off : Icons.person,
                    size: 15,
                    color: _commentIsAnonymous ? Colors.grey[500] : const Color(0xFFC2185B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _commentIsAnonymous ? 'Comentar anónimamente' : 'Comentar públicamente',
                    style: TextStyle(
                      fontSize: 12,
                      color: _commentIsAnonymous ? Colors.grey[500] : const Color(0xFFC2185B),
                    ),
                  ),
                  Switch.adaptive(
                    value: !_commentIsAnonymous,
                    onChanged: (v) => setState(() => _commentIsAnonymous = !v),
                    activeThumbColor: const Color(0xFFC2185B),
                    activeTrackColor: const Color(0xFFC2185B).withValues(alpha: 0.4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickCommentCtrl,
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isQuickPosting
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFC2185B)),
                        ),
                      )
                    : IconButton(
                        onPressed: _postQuickComment,
                        icon: const Icon(Icons.send_rounded),
                        color: const Color(0xFFC2185B),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFC2185B).withValues(alpha: 0.1),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ─── TAB CONTENIDO ────────────────────────────────────────────────────────
  Widget _buildContentTab() {
    if (_isLoadingContent) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFC2185B)));
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
                  backgroundColor: const Color(0xFFC2185B),
                  foregroundColor: Colors.white),
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

    // Group files by type
    final mainImages =
        files.where((f) => f.contentType.name.toUpperCase() == 'MAIN_IMAGE').toList();
    final carouselImages =
        files.where((f) => f.contentType.name.toUpperCase() == 'CARRUSEL_IMAGE').toList();
    final videos =
        files.where((f) => f.contentType.name.toUpperCase() == 'VIDEO').toList();
    final diagrams =
        files.where((f) => f.contentType.name.toUpperCase() == 'DIAGRAM').toList();
    final docs = files
        .where((f) => !['MAIN_IMAGE', 'CARRUSEL_IMAGE', 'VIDEO', 'DIAGRAM']
            .contains(f.contentType.name.toUpperCase()))
        .toList();

    // Group links by type
    final youtubeLinks = links
        .where((l) => l.url.contains('youtube.com') || l.url.contains('youtu.be'))
        .toList();
    final otherLinks = links
        .where((l) =>
            !l.url.contains('youtube.com') && !l.url.contains('youtu.be'))
        .toList();

    final isEmpty = files.isEmpty && links.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Acciones para Expositor
          if (isExpositor) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Subir archivo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC2185B),
                      side: const BorderSide(color: Color(0xFFC2185B)),
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
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 15)),
                  ],
                ),
              ),
            ),

          if (mainImages.isNotEmpty) ...[
            _sectionHeader(Icons.image_outlined, 'Imagen Principal', mainImages.length),
            const SizedBox(height: 8),
            ...mainImages.map((f) => _buildFileCard(f, isExpositor)),
            const SizedBox(height: 20),
          ],

          if (videos.isNotEmpty) ...[
            _sectionHeader(Icons.videocam_outlined, 'Videos', videos.length),
            const SizedBox(height: 8),
            ...videos.map((f) => _buildFileCard(f, isExpositor)),
            const SizedBox(height: 20),
          ],

          if (carouselImages.isNotEmpty) ...[
            _sectionHeader(Icons.photo_library_outlined, 'Galería', carouselImages.length),
            const SizedBox(height: 8),
            ...carouselImages.map((f) => _buildFileCard(f, isExpositor)),
            const SizedBox(height: 20),
          ],

          if (diagrams.isNotEmpty) ...[
            _sectionHeader(Icons.account_tree_outlined, 'Diagramas', diagrams.length),
            const SizedBox(height: 8),
            ...diagrams.map((f) => _buildFileCard(f, isExpositor)),
            const SizedBox(height: 20),
          ],

          if (docs.isNotEmpty) ...[
            _sectionHeader(Icons.insert_drive_file_outlined, 'Documentos', docs.length),
            const SizedBox(height: 8),
            ...docs.map((f) => _buildFileCard(f, isExpositor)),
            const SizedBox(height: 20),
          ],

          if (youtubeLinks.isNotEmpty) ...[
            _sectionHeader(Icons.play_circle_outline, 'YouTube', youtubeLinks.length),
            const SizedBox(height: 8),
            ...youtubeLinks.map((l) => _buildLinkCard(l, isExpositor)),
            const SizedBox(height: 20),
          ],

          if (otherLinks.isNotEmpty) ...[
            _sectionHeader(Icons.link, 'Otros enlaces', otherLinks.length),
            const SizedBox(height: 8),
            ...otherLinks.map((l) => _buildLinkCard(l, isExpositor)),
          ],
        ],
      ),
    );
  }

  // ─── TAB COMENTARIOS ──────────────────────────────────────────────────────
  Widget _buildCommentsTab() {
    if (_isLoadingComments) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFC2185B)));
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
                  backgroundColor: const Color(0xFFC2185B),
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
        // Lista de comentarios
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
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 15)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFC2185B),
                  onRefresh: _loadComments,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) => _buildCommentCard(_comments[i]),
                  ),
                ),
        ),
        // Campo de comentario al fondo (estilo YouTube)
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle anónimo
                GestureDetector(
                  onTap: () => setState(() => _commentIsAnonymous = !_commentIsAnonymous),
                  child: Row(
                    children: [
                      Icon(
                        _commentIsAnonymous ? Icons.person_off : Icons.person,
                        size: 16,
                        color: _commentIsAnonymous ? Colors.grey[600] : const Color(0xFFC2185B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _commentIsAnonymous ? 'Anónimo' : 'Público',
                        style: TextStyle(
                          fontSize: 12,
                          color: _commentIsAnonymous ? Colors.grey[600] : const Color(0xFFC2185B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Switch.adaptive(
                        value: !_commentIsAnonymous,
                        onChanged: (v) => setState(() => _commentIsAnonymous = !v),
                        activeThumbColor: const Color(0xFFC2185B),
                        activeTrackColor: const Color(0xFFC2185B).withValues(alpha: 0.4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                Expanded(
                  child: TextField(
                    controller: _inlineCommentCtrl,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isPostingComment
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFC2185B)),
                        ),
                      )
                    : IconButton(
                        onPressed: _postInlineComment,
                        icon: const Icon(Icons.send_rounded),
                        color: const Color(0xFFC2185B),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFC2185B).withValues(alpha: 0.1),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── FAB ─────────────────────────────────────────────────────────────────
  Widget? _buildFab() {
    if (_tabController.index == _tabComments) return null;
    final canVote = widget.userRole == 'Votante' || widget.userRole == 'Expositor';
    if (canVote) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFFC2185B),
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
    }
    if (widget.userRole == 'Jurado') {
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
    }
    return null;
  }

  // ─── DIALOGS ─────────────────────────────────────────────────────────────
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
              const Text('Tipo de archivo',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _contentTypes
                    .map((t) => ChoiceChip(
                          label: Text(_contentTypeName(t.name)),
                          selected: selectedType == t,
                          selectedColor:
                              const Color(0xFFC2185B).withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: selectedType == t
                                ? const Color(0xFFC2185B)
                                : null,
                          ),
                          onSelected: (_) =>
                              setDialogState(() => selectedType = t),
                        ))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC2185B),
                  foregroundColor: Colors.white),
              onPressed: () async {
                final extensions = selectedType!.allowedExtensions
                    .map((e) => e.startsWith('.') ? e.substring(1) : e)
                    .toList();
                Navigator.pop(ctx);
                final result = await FilePicker.platform.pickFiles(
                  allowedExtensions: extensions.isEmpty ? null : extensions,
                  type: extensions.isEmpty ? FileType.any : FileType.custom,
                  withData: true,
                );
                if (result == null || result.files.isEmpty) return;
                final file = result.files.single;
                final mimeType = _mimeFromExtension(file.extension ?? '');
                try {
                  await ProjectService.uploadFile(
                    projectId: widget.projectId,
                    filePath: file.path,
                    fileBytes: file.bytes?.toList(),
                    fileName: file.name,
                    mimeType: mimeType,
                    contentTypeId: selectedType!.id,
                  );
                  _loadContent();
                } catch (e) {
                  if (mounted) {
                    final msg = e is ApiException ? e.message : 'Error al subir el archivo';
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg), backgroundColor: Colors.red));
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ProjectService.deleteFile(widget.projectId, file.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo eliminado.')));
      }
      _loadContent();
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Error al eliminar el archivo';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red));
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.red)),
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

  Future<void> _confirmDeleteComment(Comment comment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar comentario'),
        content: const Text(
            '¿Eliminar este comentario? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.red)),
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

  // ─── CARD WIDGETS ─────────────────────────────────────────────────────────
  Widget _sectionHeader(IconData icon, String title, int count) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFC2185B)),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFC2185B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFC2185B),
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildFileCard(ProjectFile file, bool canDelete) {
    final hasUrl = file.url.isNotEmpty;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: hasUrl
            ? () async {
                final uri = Uri.parse(file.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            : null,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFC2185B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_fileIcon(file.contentType.name),
              color: const Color(0xFFC2185B), size: 22),
        ),
        title: Text(file.fileName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${_contentTypeName(file.contentType.name)} · ${file.readableSize}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: canDelete
            ? IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: () => _confirmDeleteFile(file),
              )
            : hasUrl
                ? const Icon(Icons.download_outlined,
                    color: Color(0xFFC2185B), size: 20)
                : null,
      ),
    );
  }

  IconData _fileIcon(String typeName) {
    switch (typeName.toUpperCase()) {
      case 'MAIN_IMAGE':
      case 'CARRUSEL_IMAGE': return Icons.image_outlined;
      case 'VIDEO': return Icons.videocam_outlined;
      case 'DOCUMENT':
      case 'PDF': return Icons.picture_as_pdf_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
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
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: () => _confirmDeleteLink(link),
              )
            : const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
        onTap: () => _launchUrl(link.url),
      ),
    );
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
                      : const Color(0xFFC2185B).withValues(alpha: 0.12),
                  child: Icon(
                    isAnon ? Icons.person_off : Icons.person,
                    size: 16,
                    color: isAnon
                        ? Colors.grey[600]
                        : const Color(0xFFC2185B),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAnon
                            ? 'Anónimo'
                            : (comment.userName ??
                                (comment.userId != null && comment.userId == AppState.userId
                                    ? AppState.userName
                                    : null) ??
                                'Usuario'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        _formatDate(comment.dateTime),
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500]),
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
                        : const Color(0xFFC2185B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isAnon ? 'Anónimo' : 'Público',
                    style: TextStyle(
                      fontSize: 10,
                      color: isAnon
                          ? Colors.grey[700]
                          : const Color(0xFFC2185B),
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
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 18),
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

  // ─── HELPERS ─────────────────────────────────────────────────────────────
  Widget _chipInfo(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStars(double score) {
    final full = score.floor().clamp(0, 5);
    final hasHalf = (score - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) {
          return const Icon(Icons.star_rounded, color: Colors.amber, size: 22);
        }
        if (i == full && hasHalf) {
          return const Icon(Icons.star_half_rounded,
              color: Colors.amber, size: 22);
        }
        return Icon(Icons.star_outline_rounded,
            color: Colors.amber[200], size: 22);
      }),
    );
  }

  Future<void> _launchUrl(String url) async {
    var urlString = url.trim();
    if (!urlString.startsWith('http://') &&
        !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    try {
      await launchUrl(Uri.parse(urlString),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace')),
        );
      }
    }
  }

  String _contentTypeName(String name) {
    switch (name.toUpperCase()) {
      case 'MAIN_IMAGE': return 'Imagen Principal';
      case 'CARRUSEL_IMAGE': return 'Imagen Carrusel';
      case 'VIDEO': return 'Video';
      case 'DOCUMENTATION': return 'Documentación';
      case 'SLIDES': return 'Diapositivas';
      case 'IMAGE': return 'Imagen';
      case 'DIAGRAM': return 'Diagrama';
      default: return name;
    }
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

// ─── Diálogo agregar enlace ────────────────────────────────────────────────
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
              children: widget.linkTypes
                  .map((t) => ChoiceChip(
                        label: Text(t.name),
                        selected: _selectedType == t,
                        selectedColor:
                            const Color(0xFFC2185B).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _selectedType == t
                              ? const Color(0xFFC2185B)
                              : null,
                          fontWeight: _selectedType == t
                              ? FontWeight.w600
                              : null,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedType = t),
                      ))
                  .toList(),
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
              backgroundColor: const Color(0xFFC2185B),
              foregroundColor: Colors.white),
          onPressed: () {
            final url = _urlCtrl.text.trim();
            final name = _nameCtrl.text.trim();
            if (url.isEmpty || name.isEmpty) return;
            Navigator.pop(
                context, (url: url, name: name, typeId: _selectedType.id));
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  final String url;
  final String fileName;

  const _InlineVideoPlayer({required this.url, required this.fileName});

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      }).catchError((e) {
        print('VIDEO ERROR: $e');
        if (mounted) setState(() => _error = true);
      });
    _controller.setLooping(false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        color: Colors.black,
        child: const Center(child: Icon(Icons.error_outline, color: Colors.white54, size: 48)),
      );
    }
    if (!_initialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
            if (!_controller.value.isPlaying)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
              ),
          ],
        ),
      ),
    );
  }
}
