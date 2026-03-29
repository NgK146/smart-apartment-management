class InternalTaskModel {
  final String id;
  final String title;
  final String? description;
  final String type;
  final String priority;
  final String status;
  final String? apartmentId;
  final String? assignedToUserId;
  final String? createdByUserId;
  final DateTime? dueDate;
  final DateTime? completedAtUtc;
  final String? notes;
  final DateTime createdAtUtc;

  InternalTaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.priority,
    required this.status,
    this.apartmentId,
    this.assignedToUserId,
    this.createdByUserId,
    this.dueDate,
    this.completedAtUtc,
    this.notes,
    required this.createdAtUtc,
  });

  factory InternalTaskModel.fromJson(Map<String, dynamic> j) => InternalTaskModel(
        id: j['id'],
        title: j['title'],
        description: j['description'],
        type: j['type'].toString(),
        priority: j['priority'].toString(),
        status: j['status'].toString(),
        apartmentId: j['apartmentId'],
        assignedToUserId: j['assignedToUserId'],
        createdByUserId: j['createdByUserId'],
        dueDate: j['dueDate'] != null ? DateTime.parse(j['dueDate']) : null,
        completedAtUtc: j['completedAtUtc'] != null ? DateTime.parse(j['completedAtUtc']) : null,
        notes: j['notes'],
        createdAtUtc: DateTime.parse(j['createdAtUtc']),
      );
}

























