import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'register_page.dart';

class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({super.key});

  @override
  State<CustomerLoginPage> createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage> {
  bool _loading = false;

  static const primaryColor = Color(0xFF087F8C);
  static const backgroundColor = Color(0xFFF5F8FA);
  static const textColor = Color(0xFF263746);
  static const hintColor = Color(0xFF82909C);

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: '171719716098-nb5akmdb4b3oomge06p061eq80qmvo2k.apps.googleusercontent.com');
      final googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw 'فشل في الحصول على بيانات المصادقة من جوجل.';
      }

      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (!mounted) return;

      final user = response.user;
      final accountType = user?.userMetadata?['account_type'];

      // إذا كان الحساب مسجلاً مسبقاً كفني ولا يملكه العميل
      if (accountType != null && accountType != 'customer') {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هذا الحساب مسجل كفني وليس كعميل'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      // إذا كان حساباً جديداً تماماً، نقوم بتحديث الـ Metadata ليكون عميلاً تلقائياً
      if (accountType == null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'full_name': googleUser.displayName ?? 'عميل',
              'account_type': 'customer',
            },
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الدخول بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تسجيل الدخول: $e'),
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
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text(
            'تسجيل دخول العميل',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
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
                        color: primaryColor.withValues(alpha: 0.11),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.home_repair_service_rounded,
                        size: 40,
                        color: primaryColor,
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
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سجل دخولك باستخدام حساب جوجل لمتابعة طلبات الصيانة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: hintColor, height: 1.6),
                  ),
                  const SizedBox(height: 45),

                  // زر تسجيل الدخول بجوجل
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.red),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: textColor,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                          side: const BorderSide(color: Colors.grey, width: 0.3),
                        ),
                      ),
                      label: _loading
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(strokeWidth: 2.3),
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