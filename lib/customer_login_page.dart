import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'auth_service.dart';
import 'register_page.dart';

class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({super.key});

  @override
  State<CustomerLoginPage> createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage> {
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final payload = await AuthService.signInWithGoogle();
      if (payload == null) return;

      final user = payload.authResponse.user!;
      var accountType = AuthService.accountTypeOf(user);

      if (accountType == 'technician') {
        await AuthService.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هذا الحساب مسجل كفني وليس كعميل'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      accountType ??=
          await AuthService.claimCustomerAccount(fullName: payload.displayName);

      if (accountType != 'customer') {
        await AuthService.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر التحقق من نوع الحساب كعميل'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الدخول بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      await AuthService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'حدث خطأ أثناء تسجيل الدخول: ${AuthService.friendlyError(e)}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _openRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.lightBg,
        appBar: AppBar(
          title: const Text(
            'تسجيل دخول العميل',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: AppTheme.lightBg,
          foregroundColor: AppTheme.textDark,
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 25, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppTheme.tealPrimary.withValues(alpha: 0.11),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.home_repair_service_rounded,
                        size: 40,
                        color: AppTheme.tealPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'أهلاً بعودتك في صيانتي',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سجل دخولك باستخدام حساب جوجل لمتابعة طلبات الصيانة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.hintGrey,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 45),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata,
                          size: 32, color: Colors.red),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.textDark,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                          side:
                              const BorderSide(color: Colors.grey, width: 0.3),
                        ),
                      ),
                      label: _loading
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.3),
                            )
                          : const Text(
                              'المتابعة باستخدام جوجل',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'ليس لديك حساب؟',
                        style: TextStyle(color: Colors.black, fontSize: 14),
                      ),
                      TextButton(
                        onPressed: _openRegister,
                        child: const Text(
                          'أنشئ حساب الآن',
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
    );
  }
}
