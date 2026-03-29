// Models cho Community Events
class CommunityEvent {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final EventCategory category;
  final int maxParticipants;
  final int currentParticipants;
  final double? fee;
  final bool requiresRegistration;
  final EventStatus status;
  final String? qrCode; // QR code for check-in
  final DateTime createdAt;

  CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.category,
    required this.maxParticipants,
    this.currentParticipants = 0,
    this.fee,
    this.requiresRegistration = true,
    this.status = EventStatus.upcoming,
    this.qrCode,
    required this.createdAt,
  });

  bool get isFull => currentParticipants >= maxParticipants;
  bool get canRegister => status == EventStatus.upcoming && !isFull;
  bool get isPast => DateTime.now().isAfter(endDate);

  factory CommunityEvent.fromJson(Map<String, dynamic> json) {
    return CommunityEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      location: json['location'] as String,
      category: EventCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['category'],
        orElse: () => EventCategory.other,
      ),
      maxParticipants: json['maxParticipants'] as int,
      currentParticipants: json['currentParticipants'] as int? ?? 0,
      fee: (json['fee'] as num?)?.toDouble(),
      requiresRegistration: json['requiresRegistration'] as bool? ?? true,
      status: EventStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => EventStatus.upcoming,
      ),
      qrCode: json['qrCode'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

enum EventCategory {
  social, // Sự kiện xã hội
  fitness, // Thể dục thể thao
  education, // Giáo dục
  entertainment, // Giải trí
  food, // Ẩm thực
  other,
}

enum EventStatus {
  upcoming,
  ongoing,
  completed,
  cancelled,
}

class EventRegistration {
  final String id;
  final String eventId;
  final String residentId;
  final String residentName;
  final String apartmentCode;
  final DateTime registeredAt;
  final RegistrationStatus status;
  final String? checkInQrCode;
  final DateTime? checkedInAt;

  EventRegistration({
    required this.id,
    required this.eventId,
    required this.residentId,
    required this.residentName,
    required this.apartmentCode,
    required this.registeredAt,
    this.status = RegistrationStatus.registered,
    this.checkInQrCode,
    this.checkedInAt,
  });

  bool get canCheckIn => status == RegistrationStatus.registered && checkInQrCode != null;

  factory EventRegistration.fromJson(Map<String, dynamic> json) {
    return EventRegistration(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      residentId: json['residentId'] as String,
      residentName: json['residentName'] as String,
      apartmentCode: json['apartmentCode'] as String,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      status: RegistrationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => RegistrationStatus.registered,
      ),
      checkInQrCode: json['checkInQrCode'] as String?,
      checkedInAt: json['checkedInAt'] != null
          ? DateTime.parse(json['checkedInAt'] as String)
          : null,
    );
  }
}

enum RegistrationStatus {
  registered,
  checkedIn,
  cancelled,
}



