import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/role_request_models.dart';
import '../../services/role_request_service.dart';

class RoleRequestsScreen extends StatefulWidget {
  const RoleRequestsScreen({super.key});

  @override
  State<RoleRequestsScreen> createState() => _RoleRequestsScreenState();
}

class _RoleRequestsScreenState extends State<RoleRequestsScreen> {
  List<RoleRequest> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;
  // Track which request IDs are being processed
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final requests = await RoleRequestService.getPendingRequests();
      setState(() => _requests = requests);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Error de conexión.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAction(RoleRequest req, bool approve) async {
    setState(() => _processingIds.add(req.id));
    try {
      if (approve) {
        await RoleRequestService.approve(req.id);
      } else {
        await RoleRequestService.reject(req.id);
      }
      if (mounted) {
        setState(() => _requests.removeWhere((r) => r.id == req.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve
                ? 'Solicitud aprobada'
                : 'Solicitud rechazada'),
            backgroundColor: approve ? Colors.green : Colors.red,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(req.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Solicitudes de Rol',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)))
          : _errorMessage != null
              ? _buildError()
              : _buildBody(),
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
                backgroundColor: const Color(0xFFB71C1C),
                foregroundColor: Colors.white),
            onPressed: _load,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_turned_in_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay solicitudes pendientes',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFB71C1C),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (_, i) => _buildCard(_requests[i]),
      ),
    );
  }

  Widget _buildCard(RoleRequest req) {
    final isProcessing = _processingIds.contains(req.id);
    final roleLabel = _roleLabel(req.requestedRole);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + info
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      const Color(0xFFB71C1C).withValues(alpha: 0.1),
                  child: Text(
                    req.userName.isNotEmpty
                        ? req.userName[0].toUpperCase()
                        : req.userEmail.isNotEmpty
                            ? req.userEmail[0].toUpperCase()
                            : '?',
                    style: const TextStyle(
                        color: Color(0xFFB71C1C),
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (req.userName.isNotEmpty)
                        Text(req.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(req.userEmail,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis),
                      if (req.createdAt.isNotEmpty)
                        Text(
                          _formatDate(req.createdAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ),
                // Role badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB71C1C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    roleLabel,
                    style: const TextStyle(
                        color: Color(0xFFB71C1C),
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Approve / Reject buttons
            if (isProcessing)
              const Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Color(0xFFB71C1C), strokeWidth: 2)))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _handleAction(req, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Aprobar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _handleAction(req, true),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'JURY':
      case 'JURADO':
        return 'Jurado';
      case 'EXPOSITOR':
      case 'EXPOSER':
        return 'Expositor';
      case 'SECRETARY':
      case 'SECRETARIO':
        return 'Secretario';
      default:
        return role;
    }
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}
