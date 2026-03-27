import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _register() async {
    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (name.isEmpty) throw Exception("Name is required");
      if (phone.isEmpty && email.isEmpty) throw Exception("Email or Phone is required");
      if (password.isEmpty) throw Exception("Password is required");

      if (phone.isNotEmpty) {
        await _authService.sendOtp(phone);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (ctx) => OtpScreen(
            phone: phone,
            isRegistration: true,
            regName: name,
            regEmail: email,
            regPassword: password,
          )),
        );
      } else {
        await _authService.register(
          name: name,
          phone: null,
          email: email.isEmpty ? null : email,
          password: password,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration successful. Please login.')));
        Navigator.pop(context);
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
      appBar: AppBar(title: Text('Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: 'Phone (Optional if using email)', border: OutlineInputBorder()),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email (Optional if using phone)', border: OutlineInputBorder()),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
            SizedBox(height: 24),
            _isLoading 
              ? CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _register,
                  child: Text('Register'),
                ),
          ],
        ),
      ),
    );
  }
}
