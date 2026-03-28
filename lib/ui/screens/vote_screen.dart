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

  @override
  void initState() {
    super.initState();
    _load();
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
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    final details = _scores.entries
        .map((e) => VoteDetail(criterionId: e.key, score: e.value))
        .toList();
    try {
      if (_existingVote != null) {
        await (widget.isJury
            ? VoteService.editJuryVote(widget.projectId, details)
            : VoteService.editVote(widget.projectId, details));
      } else {
        await (widget.isJury
            ? VoteService.submitJuryVote(widget.projectId, details)
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
        backgroundColor: widget.isJury ? const Color(0xFF263238) : const Color(0xFFB71C1C),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.projectTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)))
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
                backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white),
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
          color: (widget.isJury ? const Color(0xFF263238) : const Color(0xFFB71C1C))
              .withValues(alpha: 0.07),
          child: Row(
            children: [
              Icon(
                widget.isJury ? Icons.rate_review : Icons.star,
                color: widget.isJury ? const Color(0xFF263238) : const Color(0xFFB71C1C),
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
                    color: widget.isJury ? const Color(0xFF263238) : const Color(0xFFB71C1C),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _criteria.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) => _buildCriterionCard(_criteria[i]),
          ),
        ),
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
    final accentColor = widget.isJury ? const Color(0xFF263238) : const Color(0xFFB71C1C);

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

  Widget _buildSubmitButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isJury ? const Color(0xFF263238) : const Color(0xFFB71C1C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    widget.isJury
                        ? (_existingVote != null ? 'Actualizar evaluación' : 'Enviar evaluación')
                        : (_existingVote != null ? 'Actualizar voto' : 'Enviar voto'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}
