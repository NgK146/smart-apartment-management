class Amenity {
  final String id, name; final String? description; final double? pricePerHour; final bool? allowBooking;
  final String? category, imageUrl, location, usageRules;
  final int? openHourStart, openHourEnd, minDurationMinutes, maxDurationMinutes, maxAdvanceDays, maxPerDay, maxPerWeek;
  final bool? requireManualApproval, requirePrepayment;

  Amenity({required this.id, required this.name, this.description, this.pricePerHour, this.allowBooking,
    this.category, this.imageUrl, this.location, this.openHourStart, this.openHourEnd, this.usageRules,
    this.minDurationMinutes, this.maxDurationMinutes, this.maxAdvanceDays, this.requireManualApproval,
    this.maxPerDay, this.maxPerWeek, this.requirePrepayment});

  factory Amenity.fromJson(Map<String,dynamic> j) => Amenity(
      id: j['id'], name: j['name'], description: j['description'], allowBooking: j['allowBooking'] as bool?, pricePerHour: j['pricePerHour'] == null ? null : (j['pricePerHour'] as num).toDouble(),
      category: j['category'], imageUrl: j['imageUrl'], location: j['location'], usageRules: j['usageRules'],
      openHourStart: j['openHourStart'], openHourEnd: j['openHourEnd'],
      minDurationMinutes: j['minDurationMinutes'], maxDurationMinutes: j['maxDurationMinutes'], maxAdvanceDays: j['maxAdvanceDays'],
      requireManualApproval: j['requireManualApproval'] as bool?, maxPerDay: j['maxPerDay'], maxPerWeek: j['maxPerWeek'], requirePrepayment: j['requirePrepayment'] as bool?);

  Map<String,dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    if (pricePerHour != null) 'pricePerHour': pricePerHour,
    if (allowBooking != null) 'allowBooking': allowBooking,
    'category': category ?? '', // Luôn gửi category, ít nhất là chuỗi rỗng
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (location != null) 'location': location,
    if (usageRules != null) 'usageRules': usageRules,
    if (openHourStart != null) 'openHourStart': openHourStart,
    if (openHourEnd != null) 'openHourEnd': openHourEnd,
    if (minDurationMinutes != null) 'minDurationMinutes': minDurationMinutes,
    if (maxDurationMinutes != null) 'maxDurationMinutes': maxDurationMinutes,
    if (maxAdvanceDays != null) 'maxAdvanceDays': maxAdvanceDays,
    if (requireManualApproval != null) 'requireManualApproval': requireManualApproval,
    if (maxPerDay != null) 'maxPerDay': maxPerDay,
    if (maxPerWeek != null) 'maxPerWeek': maxPerWeek,
    if (requirePrepayment != null) 'requirePrepayment': requirePrepayment,
  };
}
