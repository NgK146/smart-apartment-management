class Suggestion {
  final String code;
  final String title;
  final String description;
  final String tags;
  final double score;
  final int priority;

  Suggestion({
    required this.code,
    required this.title,
    required this.description,
    required this.tags,
    required this.score,
    required this.priority,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      code: json['code'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      tags: json['tags'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
      priority: json['priority'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'title': title,
      'description': description,
      'tags': tags,
      'score': score,
      'priority': priority,
    };
  }

  List<String> get tagList => tags.split(',').where((t) => t.isNotEmpty).toList();

  bool hasTag(String tag) => tagList.contains(tag);
}

