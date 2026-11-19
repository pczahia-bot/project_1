import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'technician_application_page.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  static const Color _primaryColor = Color(0xFF087F8C);
  static const Color _backgroundColor = Color(0xFFF5F8FA);

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      final payload = await AuthService.signInWithGoogle();
      if (payload == null) return; // المستخدم ألغى العملية (finally يعيد الحالة)

      final user = payload.authResponse.user!;

      // طلب الانضمام (إن وُجد) — يُجلب مرة واحدة ويُستخدم أدناه
      final profile = await supabase
          .from('technician_profiles')
          .select('is_approved, application_status')
          .eq('user_id', user.id)
          .maybeSingle();

      var accountType = AuthService.accountTypeOf(user);

      // إصلاح تلقائي: الطلب محفوظ لكن نوع الحساب لم يُثبَّت (فشل سابق في الخطوة الأخيرة)
      if (accountType == null && profile != null) {
        accountType = await AuthService.claimTechnicianAccount();
      }

      if (accountType != 'technician') {
        await AuthService.signOut();
        throw Exception('هذا الحساب ليس حساب فني مسجل');
      }

      if (profile == null) {
        await AuthService.signOut();
        throw Exception('لم يتم العثور على طلب انضمام الفني الخاص بك');
      }

      if (!mounted) return;

      final isApproved = profile['is_approved'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isApproved
              ? 'تم تسجيل الدخول بنجاح'
              : 'تم تسجيل الدخول — حسابك قيد مراجعة الإدارة'),
          backgroundColor: _primaryColor,
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthService.friendlyError(error)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openTechnicianApplication() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const TechnicianApplicationPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _backgroundColor,
          elevation: 0,
          foregroundColor: _primaryColor,
          title: const Text(
            'تسجيل دخول الفني',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.home_repair_service_rounded,
                        color: _primaryColor,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'أهلًا بيك في صيانتي (فني)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF183238),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سجّل دخولك باستخدام حساب جوجل لمتابعة طلبات الصيانة',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        icon: const Icon(Icons.g_mobiledata,
                            size: 32, color: Colors.red),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Colors.grey, width: 0.3),
                          ),
                        ),
                        label: _isLoading
                            ? const SizedBox(
                                width: 23,
                                height: 23,
                                child: CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Text(
                                'تسجيل الدخول بجوجل',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'لسه معندكش حساب فني؟',
                          style: TextStyle(color: Colors.black, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: _openTechnicianApplication,
                          child: const Text(
                            'قدّم طلب انضمام',
                            style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
