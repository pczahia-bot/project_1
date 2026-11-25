import '../models/maintenance_request.dart';

String arabicRequestStatus(String? status) {
  switch (status) {
    case 'pending':
      return 'بانتظار قبول فني';
    case 'accepted':
      return 'تم قبول الطلب';
    case 'on_the_way':
      return 'الفني في الطريق';
    case 'in_progress':
      return 'جاري التنفيذ';
    case 'completed':
      return 'مكتمل';
    case 'cancelled':
      return 'ملغي';
    default:
      return status ?? '';
  }
}

bool isCustomerEditableStatus(String status) {
  return status == 'بانتظار قبول فني';
}

bool isCustomerCancellableStatus(String status) {
  return const [
    'بانتظار قبول فني',
    'تم قبول الطلب',
    'الفني في الطريق',
  ].contains(status);
}

bool isTechnicianRejectableStatus(String status) {
  return const [
    'تم قبول الطلب',
    'الفني في الطريق',
  ].contains(status);
}

String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return 'لم يتم تحديد موعد';

  final date = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');

  return '$date - $hour:$minute';
}

MaintenanceRequest maintenanceRequestFromRow(Map<String, dynamic> row) {
  final requestId = row['id'].toString();
  final visitAt = row['visit_at'];
  final imageUrls = row['image_urls'] as List? ?? [];
  final createdAt =
      DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now();

  return MaintenanceRequest(
    id: requestId,
    number:
        'SY-${requestId.substring(0, requestId.length < 8 ? requestId.length : 8).toUpperCase()}',
    service: row['service_type']?.toString() ?? '',
    description: row['description']?.toString() ?? '',
    address: row['address']?.toString() ?? '',
    visitType: visitAt == null ? 'emergency' : 'scheduled',
    visitDateTime: visitAt == null
        ? null
        : DateTime.tryParse(visitAt.toString())?.toLocal(),
    imagesCount: imageUrls.length,
    imageUrls: imageUrls.map((e) => e.toString()).toList(),
    createdAt: createdAt.toLocal(),
    latitude: (row['latitude'] as num?)?.toDouble(),
    longitude: (row['longitude'] as num?)?.toDouble(),
    status: arabicRequestStatus(row['status']?.toString()),
  );
}
