import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_theme.dart';
import '../models/app_services.dart';
import '../models/maintenance_request.dart';
import 'request_helpers.dart';

class _LoadedImagesResult {
  final List<String> urls;
  final int failedCount;

  const _LoadedImagesResult({
    required this.urls,
    required this.failedCount,
  });
}

class RequestDetailsPage extends StatefulWidget {
  final MaintenanceRequest request;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onRejectTechnician;
  final VoidCallback? onWithdraw;
  final bool forTechnician;

  const RequestDetailsPage({
    super.key,
    required this.request,
    this.onEdit,
    this.onCancel,
    this.onRejectTechnician,
    this.onWithdraw,
    this.forTechnician = false,
  });

  @override
  State<RequestDetailsPage> createState() => _RequestDetailsPageState();
}

class _RequestDetailsPageState extends State<RequestDetailsPage> {
  late MaintenanceRequest _request;
  RealtimeChannel? _channel;
  late Future<_LoadedImagesResult> _imagesFuture;
  String? _customerPhone;
  String? _technicianPhone;
  bool _contactsLoading = false;

  String get currentStatus => _request.status;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _imagesFuture = _loadImageUrls();
    _syncLatestRequest();
    _listenRealtime();
  }

  @override
  void didUpdateWidget(covariant RequestDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.request.status != widget.request.status ||
        oldWidget.request.description != widget.request.description ||
        oldWidget.request.address != widget.request.address) {
      setState(() {
        _request = widget.request;
        _imagesFuture = _loadImageUrls();
      });
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _syncLatestRequest() async {
    setState(() => _contactsLoading = true);
    try {
      final row = await Supabase.instance.client
          .from('service_requests')
          .select()
          .eq('id', _request.id)
          .maybeSingle();
      if (!mounted || row == null) {
        if (mounted) setState(() => _contactsLoading = false);
        return;
      }
      final updated =
          maintenanceRequestFromRow(Map<String, dynamic>.from(row));
      final imagesChanged =
          updated.imageUrls.join('|') != _request.imageUrls.join('|');
      setState(() {
        _request = updated;
        _customerPhone = row['customer_phone']?.toString();
        _technicianPhone = row['technician_phone']?.toString();
        _contactsLoading = false;
        if (imagesChanged) {
          _imagesFuture = _loadImageUrls();
        }
      });
    } catch (_) {
      if (mounted) setState(() => _contactsLoading = false);
    }
  }

  void _listenRealtime() {
    final supabase = Supabase.instance.client;
    _channel = supabase
        .channel('request_details_${_request.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'service_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _request.id,
          ),
          callback: (payload) {
            if (!mounted) return;
            final record = Map<String, dynamic>.from(payload.newRecord);
            setState(() {
              if (record.containsKey('service_type') &&
                  record.containsKey('created_at')) {
                _request = maintenanceRequestFromRow(record);
              } else {
                final newDbStatus = record['status']?.toString();
                if (newDbStatus != null) {
                  _request = _request.copyWith(
                    status: arabicRequestStatus(newDbStatus),
                  );
                }
              }
            });
            _syncLatestRequest();
          },
        )
        .subscribe();
  }

  bool get _tech => widget.forTechnician;

  Color get _accent => _tech ? const Color(0xFF0E7490) : AppTheme.primaryBlue;
  Color get _accentDark =>
      _tech ? const Color(0xFF164E63) : AppTheme.deepNavy;
  Color get _pageBg =>
      _tech ? const Color(0xFFEEF6F8) : const Color(0xFFF1F5FB);

  Color get _statusColor {
    switch (currentStatus) {
      case 'بانتظار قبول فني':
        return const Color(0xFFF59E0B);
      case 'تم قبول الطلب':
        return AppTheme.primaryBlue;
      case 'الفني في الطريق':
        return const Color(0xFF7C3AED);
      case 'جاري التنفيذ':
        return const Color(0xFFEA580C);
      case 'مكتمل':
        return const Color(0xFF16A34A);
      case 'ملغي':
        return const Color(0xFFDC2626);
      default:
        return _accent;
    }
  }

  IconData get _statusIcon {
    switch (currentStatus) {
      case 'بانتظار قبول فني':
        return Icons.hourglass_top_rounded;
      case 'تم قبول الطلب':
        return Icons.check_circle_outline;
      case 'الفني في الطريق':
        return Icons.directions_car_rounded;
      case 'جاري التنفيذ':
        return Icons.build_circle_outlined;
      case 'مكتمل':
        return Icons.verified_rounded;
      case 'ملغي':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Future<_LoadedImagesResult> _loadImageUrls() async {
    final paths = _request.imageUrls;
    if (paths.isEmpty) {
      return const _LoadedImagesResult(urls: [], failedCount: 0);
    }
    final storage = Supabase.instance.client.storage.from('service-images');

    // تحميل الروابط بالتوازي بدل الانتظار التسلسلي لكل صورة
    final results = await Future.wait<String?>(
      paths.map((path) async {
        try {
          return await storage.createSignedUrl(path, 3600);
        } catch (_) {
          return null;
        }
      }),
    );

    final urls = <String>[];
    var failed = 0;
    for (final url in results) {
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      } else {
        failed++;
      }
    }
    return _LoadedImagesResult(urls: urls, failedCount: failed);
  }

  void _openImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white54, size: 48),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Widget _decorCircle(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }

  Widget _statusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon, color: _statusColor, size: 20),
          const SizedBox(width: 8),
          Text(
            currentStatus,
            style: TextStyle(
              color: _statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final r = _request;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accent, _accentDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          Positioned(left: -40, top: -20, child: _decorCircle(150, 0.07)),
          Positioned(right: -30, bottom: -50, child: _decorCircle(130, 0.06)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        AppServices.iconForService(r.service),
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.service,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _copy(r.number, 'تم نسخ رقم الطلب'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    r.number,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.copy_rounded,
                                      size: 13, color: Colors.white70),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _statusPill(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _accent, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.trim().isEmpty ? '—' : value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _stateBanner() {
    final cancelled = currentStatus == 'ملغي';
    final color = _statusColor;
    final text = cancelled
        ? 'تم إلغاء هذا الطلب.'
        : (_tech
            ? 'هذا الطلب متاح للقبول من الفنيين المناسبين.'
            : 'طلبك وصل للفنيين المناسبين، وبمجرد قبول أحدهم ستظهر مراحل التنفيذ هنا.');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(_statusIcon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard() {
    const labels = [
      'تم قبول الطلب',
      'الفني في الطريق',
      'جاري التنفيذ',
      'مكتمل',
    ];
    const hints = [
      'تم تعيين فني لطلبك',
      'الفني متجه إلى موقع الصيانة',
      'الفني يعمل على حل المشكلة',
      'تم إنهاء الخدمة بنجاح',
    ];

    final finished = currentStatus == 'مكتمل';
    var current = 0;
    if (currentStatus == 'الفني في الطريق') current = 1;
    if (currentStatus == 'جاري التنفيذ') current = 2;
    if (finished) current = 3;

    return _sectionCard(
      title: 'مراحل الطلب',
      icon: Icons.timeline_rounded,
      child: Column(
        children: List.generate(labels.length, (i) {
          final done = i < current || finished;
          final active = i == current && !finished;
          final reached = done || active;
          final dotColor = done
              ? const Color(0xFF16A34A)
              : (active ? _accent : Colors.grey.shade300);
          final isLast = i == labels.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 30,
                  child: Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: _accent.withValues(alpha: 0.3),
                                    blurRadius: 0,
                                    spreadRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          done
                              ? Icons.check_rounded
                              : (active
                                  ? Icons.more_horiz_rounded
                                  : Icons.circle),
                          size: done || active ? 16 : 8,
                          color: Colors.white,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 3,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: done
                                  ? const Color(0xFF16A34A)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                reached ? FontWeight.bold : FontWeight.w500,
                            color: reached ? Colors.black87 : Colors.grey,
                          ),
                        ),
                        if (active || (finished && isLast))
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              hints[i],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _phoneTile(String label, String? phone) {
    final value = phone?.trim() ?? '';
    if (value.isEmpty) return const SizedBox.shrink();
    return _infoTile(
      icon: Icons.phone_rounded,
      color: const Color(0xFF0D9488),
      label: label,
      value: value,
      trailing: IconButton(
        tooltip: 'نسخ الرقم',
        onPressed: () => _copy(value, 'تم نسخ رقم التليفون'),
        icon: const Icon(Icons.copy_rounded),
      ),
    );
  }

  Widget _contactCard() {
    final contactAvailable = [
      'تم قبول الطلب',
      'الفني في الطريق',
      'جاري التنفيذ',
      'مكتمل',
    ].contains(currentStatus);
    if (!contactAvailable) return const SizedBox.shrink();
    final phone = _tech ? _customerPhone : _technicianPhone;
    final label = _tech ? 'رقم العميل' : 'رقم الفني';
    if (_contactsLoading && phone == null) {
      return _sectionCard(
        title: 'بيانات التواصل',
        icon: Icons.contact_phone_outlined,
        child: const LinearProgressIndicator(),
      );
    }
    if (phone == null || phone.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return _sectionCard(
      title: 'بيانات التواصل',
      icon: Icons.contact_phone_outlined,
      child: _phoneTile(label, phone),
    );
  }

  Widget _detailsCard() {
    final r = _request;
    final emergency = r.visitType == 'emergency';

    return _sectionCard(
      title: 'بيانات الطلب',
      icon: Icons.assignment_outlined,
      child: Column(
        children: [
          _infoTile(
            icon: emergency ? Icons.bolt_rounded : Icons.event_available,
            color: emergency
                ? const Color(0xFFEA580C)
                : const Color(0xFF2563EB),
            label: 'نوع الزيارة',
            value: emergency ? 'طارئة الآن' : 'زيارة بموعد',
          ),
          const SizedBox(height: 10),
          _infoTile(
            icon: Icons.schedule_rounded,
            color: const Color(0xFF0D9488),
            label: 'موعد الزيارة',
            value: emergency ? 'في أقرب وقت' : formatDateTime(r.visitDateTime),
          ),
          const SizedBox(height: 10),
          _infoTile(
            icon: Icons.location_on_rounded,
            color: const Color(0xFFE11D48),
            label: 'العنوان',
            value: r.address,
            trailing: IconButton(
              tooltip: 'نسخ العنوان',
              visualDensity: VisualDensity.compact,
              onPressed: () => _copy(r.address, 'تم نسخ العنوان'),
              icon: Icon(Icons.copy_rounded,
                  size: 20, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 10),
          _infoTile(
            icon: Icons.description_outlined,
            color: const Color(0xFF7C3AED),
            label: 'وصف المشكلة',
            value: r.description.trim().isEmpty
                ? 'لا يوجد وصف إضافي'
                : r.description,
          ),
          const SizedBox(height: 10),
          _infoTile(
            icon: Icons.calendar_today_rounded,
            color: const Color(0xFF475569),
            label: 'تاريخ إنشاء الطلب',
            value: formatDateTime(r.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _imagesCard() {
    final count = _request.imagesCount;
    return _sectionCard(
      title: 'الصور المرفقة ($count)',
      icon: Icons.photo_library_outlined,
      child: FutureBuilder<_LoadedImagesResult>(
        future: _imagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            );
          }
          final result = snapshot.data ??
              const _LoadedImagesResult(urls: [], failedCount: 0);
          final urls = result.urls;
          if (urls.isEmpty) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    'تعذر تحميل روابط الصور حاليًا.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _imagesFuture = _loadImageUrls();
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: urls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final url = urls[i];
                    return GestureDetector(
                      onTap: () => _openImage(url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          url,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              width: 96,
                              height: 96,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, _, _) => Container(
                            width: 96,
                            height: 96,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_outlined,
                                color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (result.failedCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'تعذر تحميل ${result.failedCount} من الصور المرفقة.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _imagesFuture = _loadImageUrls();
                        });
                      },
                      child: const Text('إعادة التحميل'),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _mapCard() {
    final point = latlong.LatLng(
      _request.latitude!,
      _request.longitude!,
    );
    return _sectionCard(
      title: 'موقع الصيانة',
      icon: Icons.map_outlined,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 190,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'project_1',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 45,
                    height: 45,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 45,
                    ),
                  ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    final canEdit =
        widget.onEdit != null && isCustomerEditableStatus(currentStatus);
    final canCancel =
        widget.onCancel != null && isCustomerCancellableStatus(currentStatus);
    if (!canEdit && !canCancel) return const SizedBox.shrink();

    return Row(
      children: [
        if (canEdit)
          Expanded(
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: widget.onEdit,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تعديل الطلب'),
              ),
            ),
          ),
        if (canEdit && canCancel) const SizedBox(width: 10),
        if (canCancel)
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('إلغاء الطلب'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _selectionAction() {
    if (!isTechnicianRejectableStatus(currentStatus)) {
      return const SizedBox.shrink();
    }

    final callback = _tech ? widget.onWithdraw : widget.onRejectTechnician;
    if (callback == null) return const SizedBox.shrink();
    final label = _tech ? 'إلغاء قبولي للطلب' : 'إلغاء اختيار الفني';
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: callback,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.person_remove_alt_1_rounded),
        label: Text(label),
      ),
    );
  }

  Widget _customerNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'يتم تحديث مرحلة تنفيذ طلبك لحظيًا بمجرد قيام الفني بالانتقال إلى الخطوة التالية.',
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.6,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _request;
    final waiting = currentStatus == 'بانتظار قبول فني';
    final showProgress = !waiting && currentStatus != 'ملغي';
    final showMap =
        r.latitude != null && r.longitude != null && !(_tech && waiting);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          title: const Text(
            'تفاصيل الطلب',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showProgress) _progressCard() else _stateBanner(),
                  const SizedBox(height: 16),
                  _detailsCard(),
                  const SizedBox(height: 16),
                  _contactCard(),
                  if (r.imagesCount > 0) ...[
                    const SizedBox(height: 16),
                    _imagesCard(),
                  ],
                  if (showMap) ...[
                    const SizedBox(height: 16),
                    _mapCard(),
                  ],
                  if (widget.onEdit != null || widget.onCancel != null) ...[
                    const SizedBox(height: 16),
                    _actions(),
                  ],
                  if (widget.onWithdraw != null ||
                      widget.onRejectTechnician != null) ...[
                    const SizedBox(height: 12),
                    _selectionAction(),
                  ],
                  if (!_tech) ...[
                    const SizedBox(height: 16),
                    _customerNote(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
