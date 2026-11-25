class MaintenanceRequest {
  final String id;
  final String number;
  final String service;
  final String description;
  final String address;
  final String visitType;
  final DateTime? visitDateTime;
  final int imagesCount;
  final List<String> imageUrls;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  String status;

  MaintenanceRequest({
    this.id = '',
    required this.number,
    required this.service,
    required this.description,
    required this.address,
    required this.visitType,
    required this.visitDateTime,
    required this.imagesCount,
    this.imageUrls = const [],
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.status = 'بانتظار قبول فني',
  });

  MaintenanceRequest copyWith({
    String? id,
    String? number,
    String? service,
    String? description,
    String? address,
    String? visitType,
    DateTime? visitDateTime,
    int? imagesCount,
    List<String>? imageUrls,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
    String? status,
  }) {
    return MaintenanceRequest(
      id: id ?? this.id,
      number: number ?? this.number,
      service: service ?? this.service,
      description: description ?? this.description,
      address: address ?? this.address,
      visitType: visitType ?? this.visitType,
      visitDateTime: visitDateTime ?? this.visitDateTime,
      imagesCount: imagesCount ?? this.imagesCount,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
    );
  }
}
