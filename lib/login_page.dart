import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'technician_application_page.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      final payload = await AuthService.signInWithGoogle();
      if (payload == null) return;

      final user = payload.authResponse.user!;

      final profile = await supabase
          .from('technician_profiles')
          .select('is_approved, application_status')
          .eq('user_id', user.id)
          .maybeSingle();

      var accountType = AuthService.accountTypeOf(user);

      if (accountType == 'customer') {
        await AuthService.signOut();
        throw Exception(
            'هذا الحساب مسجل كعميل. يمكنك التحويل إلى حساب فني من صفحة حسابي.');
      }

      if (accountType == null && profile != null) {
        accountType = await AuthService.claimTechnicianAccount();
      }

      if (accountType != 'technician' || profile == null) {
        await AuthService.signOut();
        throw Exception('لم يتم العثور على حساب فني مسجل لهذا البريد');
      }

      if (!mounted) return;

      final isApproved = profile['is_approved'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isApproved
              ? 'تم تسجيل الدخول بنجاح'
              : 'تم تسجيل الدخول — حسابك قيد مراجعة الإدارة'),
          backgroundColor: AppTheme.tealPrimary,
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      await AuthService.signOut();
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
        backgroundColor: AppTheme.lightBg,
        appBar: AppBar(
          backgroundColor: AppTheme.lightBg,
          elevation: 0,
          foregroundColor: AppTheme.tealPrimary,
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
                        color: AppTheme.tealPrimary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.home_repair_service_rounded,
                        color: AppTheme.tealPrimary,
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
                            side: const BorderSide(
                                color: Colors.grey, width: 0.3),
                          ),
                        ),
                        label: _isLoading
                            ? const SizedBox(
                                width: 23,
                                height: 23,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.4),
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
