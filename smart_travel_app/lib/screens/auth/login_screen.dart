import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';
import 'otp_screen.dart';
import '../app_shell.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _loginWithEmailOrPhone() async {
    setState(() => _isLoading = true);
    try {
      final identifier = _identifierController.text.trim();
      final password = _passwordController.text;

      if (identifier.isEmpty) {
         throw Exception("Please enter email or phone");
      }
      if (password.isEmpty) {
         throw Exception("Please enter password");
      }

      final data = await _authService.login(identifier, password);
      // Navigate to Home
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (ctx) => AppShell(
          userName: data['user']?['name'] ?? 'Traveler',
          userEmail: data['user']?['email'] ?? '',
        )),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final data = await _authService.googleLogin();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (ctx) => AppShell(
            userName: data['user']?['name'] ?? 'Traveler',
            userEmail: data['user']?['email'] ?? '',
        )),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _identifierController,
              decoration: InputDecoration(
                labelText: 'Email or Phone',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            SizedBox(height: 24),
            _isLoading 
              ? CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _loginWithEmailOrPhone,
                  child: Text('Login'),
                ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => RegisterScreen()),
                );
              },
              child: Text('Create an Account'),
            ),
            Divider(),
            ElevatedButton.icon(
              icon: Icon(Icons.login),
              label: Text('Sign in with Google'),
              onPressed: _loginWithGoogle,
            )
          ],
        ),
      ),
    );
  }
}
