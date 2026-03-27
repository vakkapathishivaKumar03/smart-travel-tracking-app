import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';
import 'login_screen.dart';
import '../app_shell.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final bool isRegistration;
  final String? regName;
  final String? regEmail;
  final String? regPassword;

  OtpScreen({
    required this.phone, 
    this.isRegistration = false, 
    this.regName, 
    this.regEmail, 
    this.regPassword
  });

  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _authService = AuthService();
  final _otpController = TextEditingController();
  bool _isLoading = false;

  void _verifyOtp() async {
    setState(() => _isLoading = true);
    try {
      final code = _otpController.text.trim();
      if (code.isEmpty) throw Exception("Please enter OTP");

      final result = await _authService.verifyOtp(widget.phone, code);
      if (result['status'] == 'needs_registration') {
        if (widget.isRegistration) {
          await _authService.register(
            name: widget.regName!,
            phone: widget.phone,
            email: widget.regEmail?.isEmpty ?? true ? null : widget.regEmail,
            password: widget.regPassword ?? "",
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration successful. Please login.')));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (ctx) => LoginScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account not found. Please register.')));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (ctx) => RegisterScreen()),
          );
        }
      } else {
        // Returned a token, user exists
        if (widget.isRegistration) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Phone number is already registered. Please login.')));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (ctx) => LoginScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (ctx) => AppShell(
              userName: result['user']?['name'] ?? 'Traveler',
              userEmail: result['user']?['email'] ?? '',
            )),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Enter OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("OTP sent to ${widget.phone}"),
            SizedBox(height: 16),
            TextField(
              controller: _otpController,
              decoration: InputDecoration(labelText: '6-digit OTP', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 24),
            _isLoading
              ? CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _verifyOtp,
                  child: Text('Verify'),
                )
          ],
        ),
      ),
    );
  }
}
