import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'customer_login_page.dart';
import 'technician_application_page.dart';

const Color primaryColor = Color(0xFF176B65);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isLoading = false;
  SupabaseClient get supabase => Supabase.instance.client;

  void _openTechnicianApplication() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TechnicianApplicationPage()),
    );
  }

  void _openCustomerLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CustomerLoginPage()),
    );
  }

  Future<void> _registerWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw 'فشل في جلب بيانات المصادقة من جوجل';
      }

      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (!mounted) return;

      // تعيين نوع الحساب كعميل وتحديث البيانات بالاسم من جوجل
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': googleUser.displayName ?? 'عميل جديد',
            'account_type': 'customer',
          },
        ),
      );

      _showMessage('تم إنشاء حسابك وتسجيل الدخول بنجاح.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _showMessage('حدث خطأ أثناء إنشاء الحساب: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _technicianEntry() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: const Color(0xFFEAF3F4),
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: _openTechnicianApplication,
              child: const SizedBox(
                width: 43,
                height: 43,
                child: Icon(
                  Icons.handyman_rounded,
                  color: primaryColor,
                  size: 23,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'انضمام كفني',
            style: TextStyle(
              color: primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('إنشاء حساب عميل'),
          centerTitle: true,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _technicianEntry(),
                const SizedBox(height: 25),
                const Icon(
                  Icons.home_repair_service_rounded,
                  size: 65,
                  color: primaryColor,
                ),
                const SizedBox(height: 10),
                const Text(
                  'مرحبًا بك في صيانتي',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'أنشئ حسابك بضغطة زر عبر جوجل لطلب خدمات الصيانة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 45),

                // زر التسجيل بجوجل
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _registerWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.red),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.grey, width: 0.3),
                      ),
                    ),
                    label: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'المتابعة بـ Google لإنشاء الحساب',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('لديك حساب بالفعل؟'),
                    TextButton(
                      onPressed: _openCustomerLogin,
                      child: const Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          color: primaryColor,
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
    );
  }
}