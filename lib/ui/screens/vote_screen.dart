import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/vote_models.dart';
import '../../services/vote_service.dart';

class VoteScreen extends StatefulWidget {
  final String projectId;
  final String projectTitle;
  final bool isJury;

  const VoteScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
    this.isJury = false,
  });

  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> {
  List<EvaluationCriterion> _criteria = [];
  MyVote? _existingVote;
  Map<String, double> _scores = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        widget.isJury
            ? VoteService.getRubricCriteria()
            : VoteService.getPublicCriteria(),
        widget.isJury
            ? VoteService.getMyJuryVote(widget.projectId)
            : VoteService.getMyVote(widget.projectId),
      ]);
      final criteria = results[0] as List<EvaluationCriterion>;
      final existing = results[1] as MyVote?;
      final scores = <String, double>{};
      for (final c in criteria) {
        scores[c.id] = c.minScore;
      }
      if (existing != null) {
        for (final d in existing.details) {
          scores[d.criterionId] = d.score;
        }
      }
      setState(() {
        _criteria = criteria;
        _existingVote = existing;
        _scores = scores;
      });
      if (existing?.comment != null && existing!.comment!.isNotEmpty) {
        _commentCtrl.text = existing.comment!;
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = _translateError(e.message));
    } catch (_) {
      setState(() => _errorMessage = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _translateError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('jury voting schedule is not active') || m.contains('jury vote schedule')) {
      return 'El período de evaluación del jurado no está habilitado aún para este evento.';
    }
    if (m.contains('upload schedule is not active') || m.contains('upload schedule')) {
      return 'El período de subida de proyectos no está habilitado.';
    }
    if (m.contains('schedule is not active') || m.contains('not active for voting')) {
      return 'La votación no está habilitada en este momento.';
    }
    if (m.contains('already voted') || m.contains('already exists') || m.contains('unique')) {
      return 'Ya registraste tu voto para este proyecto.';
    }
    if (m.contains('not active') || m.contains('inactive')) {
      return 'Este proyecto no está activo.';
    }
    if (m.contains('not a jury') || m.contains('not jury') || m.contains('permission') || m.contains('forbidden')) {
      return 'No tienes permisos para realizar esta acción.';
    }
    if (m.contains('not found')) return 'Recurso no encontrado.';
    if (m.contains('unauthorized') || m.contains('authentication')) {
      return 'Sesión expirada. Por favor vuelve a iniciar sesión.';
    }
    if (m.contains('comment') && m.contains('required')) {
      return 'El comentario es obligatorio para la evaluación del jurado.';
    }
    return msg;
  }

  Future<void> _submit() async {
    if (widget.isJury && _commentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El comentario es obligatorio para la evaluación del jurado.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    final details = _scores.entries
        .map((e) => VoteDetail(criterionId: e.key, score: e.value))
        .toList();
    try {
      if (_existingVote != null) {
        await (widget.isJury
            ? VoteService.editJuryVote(widget.projectId, details,
                comment: _commentCtrl.text.trim())
            : VoteService.editVote(widget.projectId, details));
      } else {
        await (widget.isJury
            ? VoteService.submitJuryVote(widget.projectId, details,
                comment: _commentCtrl.text.trim())
            : VoteService.submitVote(widget.projectId, details));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isJury
                ? '¡Evaluación enviada exitosamente!'
                : '¡Voto enviado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.isJury ? const Color(0xFF263238) : const Color(0xFFC2185B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.projectTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC2185B)))
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
                backgroundColor: const Color(0xFFC2185B), foregroundColor: Colors.white),
            onPressed: _load,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    if (_criteria.isEmpty) {
      return const Center(
        child: Text('No hay criterios de evaluación disponibles.',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: [
        // Banner superior
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: (widget.isJury ? const Color(0xFF263238) : const Color(0xFFC2185B))
              .withValues(alpha: 0.07),
          child: Row(
            children: [
              Icon(
                widget.isJury ? Icons.rate_review : Icons.star,
                color: widget.isJury ? const Color(0xFF263238) : const Color(0xFFC2185B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isJury
                      ? (_existingVote != null
                          ? 'Ya evaluaste — puedes modificar tu evaluación'
                          : 'Evalúa cada criterio de la rúbrica')
                      : (_existingVote != null
                          ? 'Ya votaste — puedes modificar tu voto'
                          : 'Califica cada criterio del 1 al 5'),
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isJury ? const Color(0xFF263238) : const Color(0xFFC2185B),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(16, 16, 16, widget.isJury ? 0 : 16),
            itemCount: _criteria.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) => _buildCriterionCard(_criteria[i]),
          ),
        ),
        if (widget.isJury) _buildCommentField(),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildCriterionCard(EvaluationCriterion criterion) {
    final score = _scores[criterion.id] ?? criterion.minScore;
    final range = criterion.maxScore - criterion.minScore;
    final starValue = range > 0
        ? ((score - criterion.minScore) / range * 4 + 1).clamp(1.0, 5.0)
        : 1.0;
    final accentColor = widget.isJury ? const Color(0xFF263238) : const Color(0xFFC2185B);

    return Card(
      elevation: 2,
      shadowColor: accentColor.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Barra de acento superior
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.4)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(criterion.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentColor, accentColor.withValues(alpha: 0.75)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          score.toStringAsFixed(1),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  if (criterion.description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(criterion.description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < starValue.round();
                      return GestureDetector(
                        onTap: () {
                          final newScore = criterion.minScore + i / 4.0 * range;
                          setState(() => _scores[criterion.id] = newScore.clamp(
                              criterion.minScore, criterion.maxScore));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(
                            filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: filled ? Colors.amber[500] : Colors.grey[300],
                            size: 42,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(criterion.minScore.toStringAsFixed(0),
                          style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                      Text(criterion.maxScore.toStringAsFixed(0),
                          style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comentario privado',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Solo visible para el expositor y su grupo.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Escribe tu retroalimentación aquí (obligatorio)...',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF263238), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final colors = widget.isJury
        ? [const Color(0xFF263238), const Color(0xFF455A64)]
        : [const Color(0xFFC2185B), const Color(0xFF7B1FA2)];
    final label = widget.isJury
        ? (_existingVote != null ? 'Actualizar evaluación' : 'Enviar evaluación')
        : (_existingVote != null ? 'Actualizar voto' : 'Enviar voto');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isSaving
                    ? [Colors.grey[400]!, Colors.grey[500]!]
                    : colors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _isSaving
                  ? []
                  : [
                      BoxShadow(
                        color: colors.first.withValues(alpha: 0.38),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}
