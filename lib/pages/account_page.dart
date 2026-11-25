import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project_1/app_theme.dart';

import '../auth_service.dart';
import '../customer_login_page.dart';
import '../login_page.dart';
import '../register_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    this.onOpenRequests,
    this.onOpenAvailable,
    this.onOpenOngoing,
  });

  final VoidCallback? onOpenRequests;
  final VoidCallback? onOpenAvailable;
  final VoidCallback? onOpenOngoing;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  StreamSubscription<AuthState>? _authSub;

  bool _loadingData = false;
  bool _uploadingAvatar = false;
  bool _deletingAccount = false;
  int _total = 0;
  int _active = 0;
  int _completed = 0;
  Map<String, dynamic>? _techProfile;
  List<String> _techServices = [];
  String? _overrideName;

  SupabaseClient get _supabase => Supabase.instance.client;
  User? get _user => _supabase.auth.currentUser;
  bool get _isLoggedIn => _user != null;
  bool get _isTechnician {
    final user = _user;
    return user != null && AuthService.accountTypeOf(user) == 'technician';
  }

  String get _displayName {
    final name =
        (_overrideName ?? _user?.userMetadata?['full_name']?.toString() ?? '')
            .trim();
    if (name.isEmpty) {
      return _isTechnician ? 'فني صيانتي' : 'عميل صيانتي';
    }
    return name;
  }

  String get _roleLabel {
    if (!_isTechnician) return 'عميل';
    final p = _techProfile;
    if (p == null) return 'فني';
    if (p['is_approved'] == true) return 'فني معتمد';
    if (p['application_status'] == 'rejected') return 'فني · طلب مرفوض';
    return 'فني · قيد المراجعة';
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _authSub = _supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedOut) {
        _overrideName = null;
      }
      setState(() {});
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.signedOut ||
          data.event == AuthChangeEvent.tokenRefreshed ||
          data.event == AuthChangeEvent.userUpdated) {
        _loadProfileData();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final user = _user;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _total = 0;
        _active = 0;
        _completed = 0;
        _techProfile = null;
        _techServices = [];
        _overrideName = null;
        _loadingData = false;
      });
      return;
    }

    if (mounted) setState(() => _loadingData = true);

    try {
      final isTech = _isTechnician;

      final rows = await _supabase
          .from('service_requests')
          .select('status')
          .eq(isTech ? 'technician_id' : 'customer_id', user.id);

      final statuses = (rows as List)
          .map((e) => (e as Map)['status']?.toString() ?? '')
          .toList();

      Map<String, dynamic>? profile;
      List<String> services = [];

      if (isTech) {
        final p = await _supabase
            .from('technician_profiles')
            .select(
                'is_approved, application_status, service_area, rejection_reason')
            .eq('user_id', user.id)
            .maybeSingle();
        profile = p == null ? null : Map<String, dynamic>.from(p);

        final sv = await _supabase
            .from('technician_services')
            .select('service_type')
            .eq('technician_id', user.id);
        services = (sv as List)
            .map((e) => (e as Map)['service_type'].toString())
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _total = statuses.length;
        _completed = statuses.where((e) => e == 'completed').length;
        _active = statuses
            .where((e) => (isTech
                    ? const ['accepted', 'on_the_way', 'in_progress']
                    : const [
                        'pending',
                        'accepted',
                        'on_the_way',
                        'in_progress'
                      ])
                .contains(e))
            .length;
        _techProfile = profile;
        _techServices = services;
        _loadingData = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _openCustomerLogin() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerLoginPage()),
    );
  }

  Future<void> _openTechnicianLogin() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _openRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  Future<void> _editName() async {
    final current = _displayName;
    final controller = TextEditingController(text: current);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل الاسم'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'الاسم بالكامل',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 400), controller.dispose);

    if (newName == null || newName.isEmpty || newName == current) return;

    try {
      await _supabase.auth.updateUser(
        UserAttributes(data: {'full_name': newName}),
      );
      if (!mounted) return;
      setState(() => _overrideName = newName);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الاسم')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تعذر تحديث الاسم: ${AuthService.friendlyError(e)}')),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await _logout();
  }

  Future<void> _logout() async {
    try {
      await AuthService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الخروج بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تسجيل الخروج: ${AuthService.friendlyError(e)}'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    if (_deletingAccount || _user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الحساب نهائيًا'),
          content: Text(
            _isTechnician
                ? 'سيتم حذف حساب الفني وملفك المهني وبياناتك نهائيًا ولا يمكن التراجع عن هذا الإجراء. هل أنت متأكد؟'
                : 'سيتم حذف حسابك وبياناتك نهائيًا ولا يمكن التراجع عن هذا الإجراء. هل أنت متأكد؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف نهائي'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await AuthService.deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الحساب بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حذف الحساب: ${AuthService.friendlyError(e)}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingAccount = false);
      }
    }
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: padding == null ? child : Padding(padding: padding, child: child),
    );
  }

  Widget _roleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isTechnician ? Icons.handyman_rounded : Icons.person_rounded,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            _roleLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeTechnicianAvatar() async {
    if (!_isTechnician || _user == null || _uploadingAvatar) return;

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1200,
      );
      if (image == null) return;

      setState(() => _uploadingAvatar = true);

      final userId = _user!.id;
      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';
      final safeExtension = ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
          ? extension
          : 'jpg';
      final path =
          '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
      final bytes = await image.readAsBytes();

      await _supabase.storage.from('profile-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: image.mimeType ??
                  (safeExtension == 'png'
                      ? 'image/png'
                      : safeExtension == 'webp'
                          ? 'image/webp'
                          : 'image/jpeg'),
              upsert: true,
            ),
          );

      final publicUrl =
          _supabase.storage.from('profile-images').getPublicUrl(path);

      await _supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': publicUrl}),
      );

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الصورة الشخصية بنجاح')),
      );
    } on StorageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر رفع الصورة: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'حدث خطأ أثناء تغيير الصورة: ${AuthService.friendlyError(e)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Widget _headerCard() {
    final name = _displayName;
    final avatarUrl = _user?.userMetadata?['avatar_url'];
    final hasAvatar = avatarUrl is String && avatarUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 10, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.darkBlue],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                child: hasAvatar
                    ? null
                    : Text(
                        name.isEmpty
                            ? 'ص'
                            : String.fromCharCode(name.runes.first),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
              ),
              if (_isTechnician)
                Positioned(
                  bottom: -3,
                  right: -3,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _uploadingAvatar ? null : _changeTechnicianAvatar,
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: _uploadingAvatar
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt,
                                size: 16, color: AppTheme.primaryBlue),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _user?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (_isTechnician) ...[
                  const SizedBox(height: 10),
                  _roleBadge(),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'تعديل الاسم',
            onPressed: _editName,
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: _card(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              _loadingData ? '…' : '$value',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        _statBox(
          _isTechnician ? 'الطلبات المقبولة' : 'إجمالي الطلبات',
          _total,
          Icons.assignment_outlined,
          AppTheme.primaryBlue,
        ),
        const SizedBox(width: 10),
        _statBox('جارية', _active, Icons.timelapse_rounded, Colors.orange),
        const SizedBox(width: 10),
        _statBox(
            'مكتملة', _completed, Icons.check_circle_outline, Colors.green),
      ],
    );
  }

  Widget _technicianStatusCard() {
    final p = _techProfile;
    final approved = p?['is_approved'] == true;
    final rejected = p?['application_status'] == 'rejected';
    final color =
        approved ? Colors.green : (rejected ? Colors.red : Colors.orange);
    final icon = approved
        ? Icons.verified_rounded
        : (rejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded);
    final title = p == null
        ? 'لم يتم العثور على طلب الانضمام'
        : approved
            ? 'حسابك معتمد'
            : rejected
                ? 'تم رفض طلب الانضمام'
                : 'طلب الانضمام قيد المراجعة';
    final reason = rejected ? (p?['rejection_reason']?.toString()) : null;
    final area = p?['service_area']?.toString();

    return _card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (p != null && !approved && !rejected)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'ستتمكن من استلام الطلبات بعد اعتماد الإدارة لحسابك.',
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
            ),
          if (reason != null && reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('السبب: $reason'),
            ),
          if (area != null && area.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text('منطقة العمل: $area'),
                ],
              ),
            ),
          if (_techServices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _techServices
                    .map(
                      (service) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.scaffoldBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          service,
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 22),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    final phone = _user?.userMetadata?['phone']?.toString();
    final created = DateTime.tryParse(_user?.createdAt ?? '')?.toLocal();
    return _card(
      child: Column(
        children: [
          if (!_isTechnician) ...[
            _infoRow(Icons.person_outline, 'الاسم', _displayName),
            const Divider(height: 1),
          ],
          _infoRow(
              Icons.email_outlined, 'البريد الإلكتروني', _user?.email ?? '-'),
          if (phone != null && phone.isNotEmpty) ...[
            const Divider(height: 1),
            _infoRow(Icons.phone_outlined, 'رقم الهاتف', phone),
          ],
          if (_isTechnician && created != null) ...[
            const Divider(height: 1),
            _infoRow(
              Icons.calendar_month_outlined,
              'عضو منذ',
              '${created.year}/${created.month.toString().padLeft(2, '0')}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = AppTheme.primaryBlue,
    bool showArrow = true,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: color == AppTheme.primaryBlue ? Colors.black87 : color,
        ),
      ),
      trailing: showArrow
          ? Icon(Icons.chevron_left, color: Colors.grey.shade500)
          : null,
    );
  }

  Widget _logoutButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'تسجيل الخروج',
        child: Material(
          color: Colors.red.withValues(alpha: 0.1),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _confirmLogout,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.logout_rounded, color: Colors.red, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuCard() {
    final tiles = <Widget>[
      if (_isTechnician) ...[
        if (widget.onOpenAvailable != null)
          _menuTile(
              icon: Icons.inbox_outlined,
              title: 'الطلبات المتاحة',
              onTap: widget.onOpenAvailable!),
        if (widget.onOpenOngoing != null)
          _menuTile(
              icon: Icons.handyman_outlined,
              title: 'الطلبات الجارية',
              onTap: widget.onOpenOngoing!),
      ] else ...[
        if (widget.onOpenRequests != null)
          _menuTile(
            icon: Icons.receipt_long_outlined,
            title: 'طلباتي',
            onTap: widget.onOpenRequests!,
          ),
      ],
    ];

    if (tiles.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) children.add(const Divider(height: 1));
      children.add(tiles[i]);
    }

    return _card(child: Column(children: children));
  }

  Widget _deleteAccountCard() {
    return _card(
      child: ListTile(
        onTap: _deletingAccount ? null : _confirmDeleteAccount,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _deletingAccount
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.red,
                  ),
                )
              : const Icon(Icons.delete_forever_outlined,
                  color: Colors.red, size: 22),
        ),
        title: Text(
          _deletingAccount ? 'جاري حذف الحساب...' : 'حذف الحساب',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.red,
          ),
        ),
        subtitle: const Text(
          'حذف الحساب وجميع البيانات المرتبطة به نهائيًا',
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildProfile() {
    final hasMenu = _isTechnician
        ? (widget.onOpenAvailable != null || widget.onOpenOngoing != null)
        : (widget.onOpenRequests != null);

    return ColoredBox(
      color: AppTheme.softPageBg,
      child: RefreshIndicator(
        onRefresh: _loadProfileData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _logoutButton(),
            const SizedBox(height: 10),
            _headerCard(),
            const SizedBox(height: 16),
            _statsRow(),
            if (_isTechnician) ...[
              const SizedBox(height: 16),
              _technicianStatusCard(),
            ],
            const SizedBox(height: 16),
            _infoCard(),
            if (hasMenu) ...[
              const SizedBox(height: 16),
              _menuCard(),
            ],
            const SizedBox(height: 16),
            _deleteAccountCard(),
          ],
        ),
      ),
    );
  }

  Widget _technicianEntry() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppTheme.scaffoldBg,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: _openTechnicianLogin,
            child: const SizedBox(
              width: 43,
              height: 43,
              child: Icon(
                Icons.handyman_rounded,
                color: AppTheme.primaryBlue,
                size: 23,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'دخول الفنيين',
          style: TextStyle(
            color: AppTheme.primaryBlue,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedOut() {
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 43,
                  backgroundColor: AppTheme.scaffoldBg,
                  child: Icon(
                    Icons.person_outline,
                    size: 52,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'أهلاً بيك في صيانتي',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'سجل دخولك أو أنشئ حساب جديد عشان تقدر تطلب خدمات الصيانة وتتابع طلباتك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('تسجيل الدخول'),
                    onPressed: _openCustomerLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('إنشاء حساب جديد'),
                    onPressed: _openRegister,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      side: BorderSide(color: AppTheme.primaryBlue),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 14,
          child: _technicianEntry(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _isLoggedIn ? _buildProfile() : _buildLoggedOut(),
    );
  }
}
