import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'customer_login_page.dart';
import 'technician_application_page.dart';

const Color primaryColor = Color(0xFF176B65);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool _isLoading = false;

  SupabaseClient get supabase => Supabase.instance.client;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _openTechnicianApplication() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TechnicianApplicationPage(),
      ),
    );
  }

  void _openCustomerLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerLoginPage(),
      ),
    );
  }

  Future<void> _registerWithGoogle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final wasSignedInBefore = supabase.auth.currentUser != null;

    try {
      final payload = await AuthService.signInWithGoogle();
      if (payload == null) return; // المستخدم ألغى العملية

      if (!mounted) return;

      final user = payload.authResponse.user!;
      var accountType = AuthService.accountTypeOf(user);

      if (accountType == 'technician') {
        if (!wasSignedInBefore) {
          await AuthService.signOut();
        }
        throw Exception('هذا الحساب مسجل كفني ولا يمكن استخدامه كحساب عميل');
      }

      accountType ??= await AuthService.claimCustomerAccount(
        fullName: payload.displayName,
      );

      if (accountType != 'customer') {
        if (!wasSignedInBefore) {
          await AuthService.signOut();
        }
        throw Exception('تعذر تثبيت الحساب كعميل');
      }

      final displayName = (payload.displayName?.trim().isNotEmpty == true)
          ? payload.displayName!.trim()
          : (user.userMetadata?['full_name']?.toString().trim().isNotEmpty ==
                  true
              ? user.userMetadata!['full_name'].toString().trim()
              : 'عميل جديد');

      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': displayName,
            'phone': _phoneController.text.trim(),
          },
        ),
      );

      if (!mounted) return;

      _showMessage('تم إنشاء حسابك وتسجيل الدخول بنجاح');
      Navigator.pop(context, true);
    } catch (e) {
      if (!wasSignedInBefore) {
        await AuthService.signOut();
      }
      if (mounted) {
        _showMessage(
          'حدث خطأ أثناء إنشاء الحساب: ${AuthService.friendlyError(e)}',
        );
      }
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
            child: Form(
              key: _formKey,
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
                    'أدخل رقم هاتفك لإنشاء حسابك وطلب خدمات الصيانة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 35),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: InputDecoration(
                      labelText: 'رقم الموبايل',
                      hintText: '01xxxxxxxxx',
                      prefixIcon: const Icon(
                        Icons.phone_android,
                        color: primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final phone = value?.trim() ?? '';

                      if (phone.isEmpty) {
                        return 'من فضلك أدخل رقم الموبايل';
                      }

                      if (!RegExp(r'^01[0125][0-9]{8}$').hasMatch(phone)) {
                        return 'أدخل رقم موبايل مصري صحيح مكون من 11 رقمًا';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _registerWithGoogle,
                      icon: const Icon(
                        Icons.g_mobiledata,
                        size: 32,
                        color: Colors.red,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Colors.grey,
                            width: 0.3,
                          ),
                        ),
                      ),
                      label: _isLoading
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(strokeWidth: 2.3),
                            )
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
      ),
    );
  }
}