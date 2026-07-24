import 'package:flutter/material.dart';
import '../../../services/hango_api.dart';
import '../../../data/services/auth_service.dart';
import '../../../utils/toast_helper.dart';
import 'package:flutter/foundation.dart';
import '../../../utils/config.dart';
import 'matrix_builder_page.dart';

class MatrixManagementPage extends StatefulWidget {
  final VoidCallback onBack;
  const MatrixManagementPage({super.key, required this.onBack});

  @override
  State<MatrixManagementPage> createState() => _MatrixManagementPageState();
}

class _MatrixManagementPageState extends State<MatrixManagementPage> {
  final _authService = AuthService();
  late HangoApi _api;
  List<Map<String, dynamic>> _matrices = [];
  bool _isLoading = true;

  String get apiBaseUrl => EnvConfig.v1BaseUrl;

  @override
  void initState() {
    super.initState();
    _initApi();
  }

  Future<void> _initApi() async {
    final token = await _authService.getToken();
    _api = HangoApi(baseUrl: apiBaseUrl, token: token);
    _fetchMatrices();
  }

  Future<void> _fetchMatrices() async {
    try {
      final data = await _api.getExamMatrices();
      if (mounted) {
        setState(() {
          _matrices = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.show(context, 'Failed to load matrices: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 16),
              const Text(
                'Quản lý Ma trận đề (Course Manager)',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MatrixBuilderPage(
                        api: _api,
                        onSaved: () => _fetchMatrices(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Tạo Ma trận mới',
                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20B486),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _matrices.isEmpty
                    ? const Center(child: Text('Chưa có ma trận nào.'))
                    : ListView.builder(
                        itemCount: _matrices.length,
                        itemBuilder: (context, index) {
                          final matrix = _matrices[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            child: ListTile(
                              title: Text(matrix['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                              subtitle: Text(matrix['description'] ?? 'No description', style: const TextStyle(fontFamily: 'Outfit')),
                              trailing: Text('ID: ${matrix['id']}', style: const TextStyle(color: Colors.grey, fontFamily: 'Outfit')),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
