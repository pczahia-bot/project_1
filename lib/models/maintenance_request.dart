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
}
