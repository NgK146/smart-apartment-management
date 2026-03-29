import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_client.dart';
import '../../core/services/suggestions_service.dart';
import 'models/suggestion_model.dart';

class SuggestionsPage extends StatefulWidget {
  const SuggestionsPage({super.key});

  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> {
  final _suggestionsService = SuggestionsService(api.dio);
  final _suggestions = <Suggestion>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _suggestionsService.getMySuggestions();
      if (mounted) {
        setState(() {
          _suggestions
            ..clear()
            ..addAll(data);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gợi ý hoạt động',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Lỗi: $_error',
                        style: GoogleFonts.inter(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadSuggestions,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSuggestions,
                  child: _suggestions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'Chưa có gợi ý nào',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            return _SuggestionCard(suggestion: _suggestions[index]);
                          },
                        ),
                ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Suggestion suggestion;

  const _SuggestionCard({required this.suggestion});

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    if (score >= 20) return Colors.blue;
    return Colors.grey;
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 5:
        return Colors.red.shade700; // Rất quan trọng
      case 4:
        return Colors.orange.shade700; // Quan trọng
      case 3:
        return Colors.blue.shade700; // Bình thường
      case 2:
        return Colors.grey.shade700; // Thấp
      default:
        return Colors.grey.shade400; // Rất thấp
    }
  }

  IconData _getIcon(String code) {
    if (code.contains('PAY')) return Icons.payment;
    if (code.contains('GYM')) return Icons.fitness_center;
    if (code.contains('POOL')) return Icons.pool;
    if (code.contains('EVENT')) return Icons.event;
    if (code.contains('CHECK')) return Icons.check_circle;
    if (code.contains('ORDER')) return Icons.shopping_cart;
    if (code.contains('BOOK')) return Icons.book;
    if (code.contains('REGISTER')) return Icons.app_registration;
    if (code.contains('WALK')) return Icons.directions_walk;
    if (code.contains('STUDY')) return Icons.school;
    if (code.contains('CLEAN')) return Icons.cleaning_services;
    if (code.contains('CAR')) return Icons.car_repair;
    return Icons.lightbulb;
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _getScoreColor(suggestion.score);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Có thể mở chi tiết hoặc thực hiện hành động
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIcon(suggestion.code),
                  color: scoreColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            suggestion.title,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: scoreColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${suggestion.score.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: scoreColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(suggestion.priority).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  5,
                                  (index) => Icon(
                                    Icons.star,
                                    size: 10,
                                    color: index < suggestion.priority
                                        ? _getPriorityColor(suggestion.priority)
                                        : Colors.grey.shade300,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suggestion.description,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (suggestion.tagList.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: suggestion.tagList.take(3).map((tag) {
                          return Chip(
                            label: Text(
                              tag,
                              style: GoogleFonts.inter(fontSize: 10),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

