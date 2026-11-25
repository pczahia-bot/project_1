import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_theme.dart';
import '../auth_service.dart';
import '../customer_login_page.dart';
import '../models/maintenance_request.dart';
import '../register_page.dart';
import 'request_details_page.dart';
import 'request_helpers.dart';
import 'request_page.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => MyRequestsPageState();
}

class MyRequestsPageState extends State<MyRequestsPage> {
  int selectedTab = 0;
  final tabs = const ['الجارية', 'المكتملة', 'الملغاة'];

  bool isLoading = true;
  bool needsLogin = false;
  String? errorMessage;

  List<MaintenanceRequest> requests = [];
  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _requestsChannel;
  Timer? _realtimeDebounce;

  @override
  void initState() {
    super.initState();
    loadRequests();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.signedOut) {
        loadRequests();
      }
    });

    final supabase = Supabase.instance.client;
    _requestsChannel = supabase
        .channel('public:service_requests_customer')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'service_requests',
          callback: (_) {
            _realtimeDebounce?.cancel();
            _realtimeDebounce = Timer(const Duration(milliseconds: 350), () {
              if (mounted) loadRequests(silent: true);
            });
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _requestsChannel?.unsubscribe();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> loadRequests({bool silent = false}) async {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        isLoading = true;
        needsLogin = false;
        errorMessage = null;
      });
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          requests = [];
          needsLogin = true;
          isLoading = false;
        });
        return;
      }

      final data = await supabase
          .from('service_requests')
          .select()
          .eq('customer_id', user.id)
          .order('created_at', ascending: false);

      final loadedRequests = (data as List)
          .map((item) => maintenanceRequestFromRow(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();

      if (!mounted) return;

      setState(() {
        requests = loadedRequests;
        errorMessage = null;
        needsLogin = false;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = AuthService.friendlyError(error);
      });
    }
  }

  List<MaintenanceRequest> get filteredRequests {
    final statuses = [
      [
        'بانتظار قبول فني',
        'تم قبول الطلب',
        'الفني في الطريق',
        'جاري التنفيذ',
      ],
      ['مكتمل'],
      ['ملغي'],
    ];

    return requests
        .where(
          (request) => statuses[selectedTab].contains(request.status),
        )
        .toList();
  }

  Color statusColor(String status) {
    if (status == 'مكتمل') return Colors.green;
    if (status == 'ملغي') return Colors.red;

    if (status == 'جاري التنفيذ' || status == 'الفني في الطريق') {
      return Colors.orange;
    }

    return AppTheme.primaryBlue;
  }

  Future<void> editRequest(MaintenanceRequest request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestPage(editRequest: request),
      ),
    );
    if (mounted) await loadRequests();
  }

  Future<bool> cancelRequest(MaintenanceRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء طلب الصيانة'),
          content: const Text(
            'هل أنت متأكد من إلغاء هذا الطلب؟ لا يمكن التراجع عن الإلغاء من التطبيق.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return false;

    try {
      final result = await Supabase.instance.client.rpc(
        'customer_cancel_service_request',
        params: {'p_request_id': request.id},
      );
      final ok = result is Map && result['success'] == true;
      if (!ok) {
        throw Exception(result is Map
            ? result['message']?.toString() ?? 'تعذر إلغاء الطلب'
            : 'تعذر إلغاء الطلب');
      }
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الطلب')),
      );
      await loadRequests(silent: true);
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تعذر إلغاء الطلب: ${AuthService.friendlyError(e)}')),
      );
      return false;
    }
  }

  Future<bool> rejectTechnician(MaintenanceRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء اختيار الفني'),
          content: const Text(
            'هل تريد إلغاء اختيار الفني؟ سيعود الطلب متاحًا لفنيين آخرين، ولن يستطيع هذا الفني قبوله مرة أخرى.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return false;
    try {
      final result = await Supabase.instance.client.rpc(
        'customer_reject_technician',
        params: {'p_request_id': request.id},
      );
      if (result is! Map || result['success'] != true) {
        throw Exception(result is Map
            ? result['message']?.toString() ?? 'تعذر إلغاء اختيار الفني'
            : 'تعذر إلغاء اختيار الفني');
      }
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء اختيار الفني')),
      );
      await loadRequests(silent: true);
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('تعذر إلغاء اختيار الفني: ${AuthService.friendlyError(e)}'),
        ),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedRequests = filteredRequests;

    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(tabs.length, (index) {
              final isSelected = selectedTab == index;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        tabs[index],
                        textAlign: TextAlign.center,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        selectedTab = index;
                      });
                    },
                    selectedColor: const Color(0xFFDCE9FF),
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primaryBlue : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Builder(
            builder: (context) {
              if (isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryBlue,
                  ),
                );
              }

              if (needsLogin) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'سجّل دخولك لمتابعة طلباتك',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'بعد تسجيل الدخول هتلاقي طلباتك هنا.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: 220,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CustomerLoginPage(),
                                ),
                              );
                              if (mounted) loadRequests();
                            },
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('تسجيل الدخول'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                            if (mounted) loadRequests();
                          },
                          child: const Text('إنشاء حساب جديد'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (errorMessage != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 50,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'تعذر تحميل طلباتك',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: loadRequests,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (displayedRequests.isEmpty) {
                return RefreshIndicator(
                  onRefresh: loadRequests,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 350,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'مفيش طلبات ${tabs[selectedTab]} حاليًا',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'لما تبعت طلب صيانة جديد هتلاقيه ظاهر هنا.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: loadRequests,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: displayedRequests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final request = displayedRequests[index];
                    final color = statusColor(request.status);

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        final detailsNavigator = Navigator.of(context);
                        detailsNavigator
                            .push(
                              MaterialPageRoute(
                                builder: (_) => RequestDetailsPage(
                                  request: request,
                                  onEdit: isCustomerEditableStatus(request.status)
                                      ? () => editRequest(request)
                                      : null,
                                  onCancel:
                                      isCustomerCancellableStatus(request.status)
                                          ? () async {
                                              final done =
                                                  await cancelRequest(request);
                                              if (done && mounted) {
                                                detailsNavigator.maybePop();
                                              }
                                            }
                                          : null,
                                  onRejectTechnician:
                                      isTechnicianRejectableStatus(
                                              request.status)
                                          ? () async {
                                              final done =
                                                  await rejectTechnician(
                                                      request);
                                              if (done && mounted) {
                                                detailsNavigator.maybePop();
                                              }
                                            }
                                          : null,
                                ),
                              ),
                            )
                            .then((_) => loadRequests(silent: true));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    request.service,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    request.status,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'رقم الطلب: ${request.number}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              request.visitType == 'emergency'
                                  ? 'زيارة طارئة الآن'
                                  : 'موعد الزيارة: ${formatDateTime(request.visitDateTime)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'عرض التفاصيل',
                                  style: TextStyle(
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_back_ios,
                                  size: 13,
                                  color: AppTheme.primaryBlue,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
