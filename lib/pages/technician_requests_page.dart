import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_theme.dart';
import '../auth_service.dart';
import '../models/app_services.dart';
import 'request_details_page.dart';
import 'request_helpers.dart';

class TechnicianRequestsPage extends StatefulWidget {
  final bool showAvailable;
  final VoidCallback? onAccepted;

  const TechnicianRequestsPage({
    super.key,
    required this.showAvailable,
    this.onAccepted,
  });

  @override
  State<TechnicianRequestsPage> createState() => TechnicianRequestsPageState();
}

class TechnicianRequestsPageState extends State<TechnicianRequestsPage> {
  static const categories = AppServices.technicianCategories;

  bool get _showAvailable => widget.showAvailable;
  String _selectedCategory = 'الكل';
  bool _loading = true;
  bool _isApproved = false;
  String? _applicationStatus;
  List<String> _techServices = [];
  String? _error;
  String? _acceptingId;
  String? _advancingId;
  List<Map<String, dynamic>> _rows = [];
  RealtimeChannel? _techChannel;
  Timer? _realtimeDebounce;

  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
    _listenRealtime();
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _techChannel?.unsubscribe();
    super.dispose();
  }

  void _scheduleReload() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _load(silent: true);
    });
  }

  void _listenRealtime() {
    _techChannel = _supabase
        .channel('public:service_requests_tech_${_showAvailable ? 'avail' : 'mine'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'service_requests',
          callback: (_) => _scheduleReload(),
        )
        .subscribe();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final uid = _uid;
      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _rows = [];
          _loading = false;
        });
        return;
      }

      // تصفية الاستعلام على مستوى الخادم بدل سحب جميع الطلبات من الجدول
      final requestsQuery = _showAvailable
          ? _supabase
              .from('service_requests')
              .select()
              .eq('status', 'pending')
              .isFilter('technician_id', null)
              .neq('customer_id', uid)
              .order('created_at', ascending: false)
          : _supabase
              .from('service_requests')
              .select()
              .eq('technician_id', uid)
              .inFilter('status', ['accepted', 'on_the_way', 'in_progress'])
              .order('created_at', ascending: false);

      final results = await Future.wait<dynamic>([
        requestsQuery,
        _supabase
            .from('technician_profiles')
            .select('is_approved, application_status')
            .eq('user_id', uid)
            .maybeSingle(),
        _supabase
            .from('technician_services')
            .select('service_type')
            .eq('technician_id', uid),
      ]);

      final data = results[0];
      final profile = results[1] as Map?;
      final servicesRows = results[2] as List;

      if (!mounted) return;
      setState(() {
        _rows = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isApproved = profile?['is_approved'] == true;
        _applicationStatus = profile?['application_status']?.toString();
        _techServices = servicesRows
            .map((e) => (e as Map)['service_type'].toString())
            .toList();
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AuthService.friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> reload() => _load();

  List<Map<String, dynamic>> get _available => _rows.where((r) {
        final rejected = (r['rejected_technician_ids'] as List? ?? [])
            .map((id) => id.toString())
            .toSet();
        final serviceType = r['service_type']?.toString() ?? '';
        return r['status'] == 'pending' &&
            r['technician_id'] == null &&
            r['customer_id'] != _uid &&
            !rejected.contains(_uid) &&
            AppServices.matchesSpecialty(_techServices, serviceType);
      }).toList();

  List<Map<String, dynamic>> get _mine => _rows
      .where((r) =>
          r['technician_id'] == _uid &&
          const ['accepted', 'on_the_way', 'in_progress']
              .contains(r['status']))
      .toList();

  List<Map<String, dynamic>> get _visible {
    final base = _showAvailable ? _available : _mine;
    if (_selectedCategory == 'الكل') return base;
    return base.where((r) {
      final service = r['service_type']?.toString() ?? '';
      if (_selectedCategory == 'أجهزة منزلية') {
        return AppServices.applianceServicesSet.contains(service);
      }
      if (_selectedCategory == 'خدمات أخرى') {
        final knownCategories = categories
            .skip(1)
            .take(categories.length - 2)
            .toList();
        final matchesKnown = knownCategories.any((c) => service.contains(c)) ||
            AppServices.applianceServicesSet.contains(service);
        return !matchesKnown;
      }
      return service.contains(_selectedCategory);
    }).toList();
  }

  Future<void> _accept(String id) async {
    if (!_isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن قبول الطلبات قبل اعتماد حسابك من الإدارة'),
        ),
      );
      return;
    }

    setState(() => _acceptingId = id);
    try {
      final result = await _supabase.rpc(
        'technician_accept_service_request',
        params: {'p_request_id': id},
      );
      if (result is! Map || result['success'] != true) {
        throw Exception(result is Map
            ? result['message']?.toString() ?? 'تعذر قبول الطلب'
            : 'تعذر قبول الطلب');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قبول الطلب بنجاح')),
      );
      await _load(silent: true);
      if (mounted) widget.onAccepted?.call();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      await _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تعذر قبول الطلب: ${AuthService.friendlyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  Future<bool> _withdraw(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء قبول الطلب'),
          content: const Text('هل تريد التراجع عن قبول هذا الطلب؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return false;
    try {
      final result = await _supabase.rpc(
        'technician_withdraw_service_request',
        params: {'p_request_id': id},
      );
      if (result is! Map || result['success'] != true) {
        throw Exception(result is Map
            ? result['message']?.toString() ?? 'تعذر إلغاء القبول'
            : 'تعذر إلغاء القبول');
      }
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء قبولك للطلب')),
      );
      await _load(silent: true);
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إلغاء القبول: ${AuthService.friendlyError(e)}'),
        ),
      );
      return false;
    }
  }

  Future<void> _advanceStatus(String id) async {
    final isFinishing = _rows
        .any((r) => r['id'].toString() == id && r['status'] == 'in_progress');
    setState(() => _advancingId = id);
    try {
      final res = await _supabase
          .rpc('advance_request_status', params: {'p_request_id': id});
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFinishing
                ? 'تم إنهاء الطلب وإزالته من الطلبات الجارية'
                : 'تم الانتقال للمرحلة التالية بنجاح'),
          ),
        );
        await _load(silent: true);
      } else {
        throw Exception(res is Map
            ? (res['message'] ?? 'تعذر تحديث الحالة')
            : 'تعذر تحديث الحالة');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${AuthService.friendlyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _advancingId = null);
    }
  }

  void _openDetails(Map<String, dynamic> r) {
    final detailsNavigator = Navigator.of(context);
    detailsNavigator
        .push(
          MaterialPageRoute(
            builder: (_) => RequestDetailsPage(
              request: maintenanceRequestFromRow(r),
              forTechnician: true,
              onWithdraw: ['accepted', 'on_the_way'].contains(r['status'])
                  ? () async {
                      final done = await _withdraw(r['id'].toString());
                      if (done && mounted) {
                        detailsNavigator.maybePop();
                      }
                    }
                  : null,
            ),
          ),
        )
        .then((_) => _load(silent: true));
  }

  String _visitText(Map<String, dynamic> r) {
    final visitAt = r['visit_at'];
    if (visitAt == null) return 'زيارة طارئة الآن';
    return 'موعد الزيارة: ${formatDateTime(DateTime.tryParse(visitAt.toString())?.toLocal())}';
  }

  Widget _detailLine(IconData icon, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$label: $value',
                style: const TextStyle(color: Colors.black87, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _approvalBanner() {
    if (!_showAvailable || _isApproved) return const SizedBox.shrink();
    final isRejected = _applicationStatus == 'rejected';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            (isRejected ? Colors.red : Colors.orange).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              (isRejected ? Colors.red : Colors.orange).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isRejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
            color: isRejected ? Colors.red : Colors.orange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isRejected
                  ? 'تم رفض طلب انضمامك؛ راجع تفاصيل حسابك قبل محاولة قبول الطلبات.'
                  : 'حسابك قيد مراجعة الإدارة. يمكنك تصفح الطلبات، وسيُفعّل قبول الطلبات بعد الاعتماد.',
              style: const TextStyle(height: 1.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressView(String? status) {
    const stages = ['accepted', 'on_the_way', 'in_progress', 'completed'];
    final current = stages.indexOf(status ?? '');
    final safeCurrent = current < 0 ? 0 : current;
    const labels = ['تم القبول', 'في الطريق', 'جاري التنفيذ', 'مكتمل'];
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Row(
        children: List.generate(stages.length, (i) {
          final done = i <= safeCurrent;
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        color: i == 0
                            ? Colors.transparent
                            : (done
                                ? AppTheme.primaryBlue
                                : Colors.grey.shade300),
                      ),
                    ),
                    CircleAvatar(
                      radius: 11,
                      backgroundColor:
                          done ? AppTheme.primaryBlue : Colors.grey.shade300,
                      child: Icon(
                        done ? Icons.check : Icons.circle,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 4,
                        color: i == stages.length - 1
                            ? Colors.transparent
                            : (i < safeCurrent
                                ? AppTheme.primaryBlue
                                : Colors.grey.shade300),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: done ? AppTheme.primaryBlue : Colors.grey,
                    fontWeight: done ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final id = r['id'].toString();
    final canAccept = _showAvailable;
    final accepting = _acceptingId == id;
    final advancing = _advancingId == id;
    final status = r['status']?.toString();

    String nextButtonLabel = 'الانتقال للمرحلة التالية';
    if (status == 'accepted') {
      nextButtonLabel = 'الانتقال إلى: الفني في الطريق';
    } else if (status == 'on_the_way') {
      nextButtonLabel = 'الانتقال إلى: جاري التنفيذ';
    } else if (status == 'in_progress') {
      nextButtonLabel = 'إنهاء وتكتمل الخدمة';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r['service_type']?.toString() ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              Text(
                'SY-${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'الحالة: ${arabicRequestStatus(status)}',
            style: const TextStyle(
                color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
          ),
          if (!_showAvailable) _progressView(status),
          const SizedBox(height: 8),
          Text(
            r['description']?.toString().isNotEmpty == true
                ? r['description'].toString()
                : 'لا يوجد وصف إضافي للعطل',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          _detailLine(Icons.location_on_outlined, 'العنوان',
              r['address']?.toString() ?? ''),
          _detailLine(Icons.event_outlined, 'موعد الزيارة', _visitText(r)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _openDetails(r),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('تفاصيل الطلب'),
          ),
          if (canAccept) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: (_acceptingId != null || !_isApproved)
                    ? null
                    : () => _accept(id),
                icon: accepting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(accepting ? 'جاري القبول...' : 'قبول الطلب'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ] else if (status != 'completed') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed:
                    _advancingId != null ? null : () => _advanceStatus(id),
                icon: advancing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(advancing ? 'جاري التحديث...' : nextButtonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _approvalBanner(),
        const SizedBox(height: 60),
        Icon(Icons.inbox_rounded, size: 62, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _showAvailable
                ? 'لا توجد طلبات متاحة لتخصصاتك حاليًا'
                : 'لا توجد طلبات جارية حاليًا',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (_showAvailable)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              'تظهر لك الطلبات التي تطابق تخصصاتك فقط، وبشرط أن يكون حسابك معتمدًا من الإدارة. اسحب للأسفل للتحديث.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.6),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          title: Text(
            _showAvailable ? 'الطلبات المتاحة' : 'الطلبات الجارية',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 10),
            SizedBox(
              height: 58,
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = category),
                    selectedColor: const Color(0xFFDCE9FF),
                    labelStyle: TextStyle(
                      color: _selectedCategory == category
                          ? AppTheme.primaryBlue
                          : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 50),
                                const SizedBox(height: 12),
                                const Text(
                                  'تعذر تحميل الطلبات',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _load,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: visible.isEmpty
                              ? _empty()
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: visible.length +
                                      (_showAvailable && !_isApproved ? 1 : 0),
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    if (_showAvailable && !_isApproved) {
                                      if (i == 0) return _approvalBanner();
                                      return _card(visible[i - 1]);
                                    }
                                    return _card(visible[i]);
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
