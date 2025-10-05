import 'package:chatapplication/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import '../components/my_button.dart';
import '../components/my_textfield.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  final void Function()? onTap;

  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _confirmPwController = TextEditingController();

  bool _showConfirmPw = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _pwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _pwController.addListener(() {
      setState(() {
        _showConfirmPw = _pwController.text.isNotEmpty;
      });
    });
  }

  // --- CORRECTED REGISTER METHOD ---
  Future<void> register(BuildContext context) async {
    setState(() => _isLoading = true);
    final auth = AuthService();

    if (_emailController.text.trim().isEmpty) {
      _showErrorDialog(context, "Email required", "Please enter an email address.");
      return;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showErrorDialog(context, "Invalid email", "Please enter a valid email address.");
      return;
    }
    if (_usernameController.text.trim().isEmpty) {
      _showErrorDialog(context, "Username required", "Please enter a username.");
      return;
    }
    if (_pwController.text.trim().isEmpty) {
      _showErrorDialog(context, "Password required", "Please enter a password.");
      return;
    }
    if (_pwController.text.trim().length < 6) {
      _showErrorDialog(context, "Weak Password", "Password must be at least 6 characters long.");
      return;
    }
    if (_pwController.text != _confirmPwController.text) {
      _showErrorDialog(context, "Passwords don't match!", "Please re-enter your password.");
      return;
    }

    try {
      // check if username already exists
      final existingUser = await FirebaseFirestore.instance
          .collection('Users')
          .where('username', isEqualTo: _usernameController.text.trim())
          .get();

      if (existingUser.docs.isNotEmpty) {
        _showErrorDialog(context, "Username taken", "That username already exists, please try another one.");
        return;
      }

      // create user in firebase auth and firestore in one go
      await auth.signUpWithEmailPassword(
        _emailController.text.trim(),
        _pwController.text.trim(),
        _usernameController.text.trim(), // pass username here
      );
    } catch (e) {
      _showErrorDialog(context, "Registration Failed", e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    // No need to set isLoading here anymore
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mail_lock_rounded,
                size: 60,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(
                "Let's create an account for you!",
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              MyTextfield(
                hintText: "Email",
                obscureText: false,
                controller: _emailController,
              ),
              const SizedBox(height: 10),
              MyTextfield(
                hintText: "Username",
                obscureText: false,
                controller: _usernameController,
              ),
              const SizedBox(height: 10),
              MyTextfield(
                hintText: "Password",
                obscureText: true,
                controller: _pwController,
              ),
              const SizedBox(height: 10),
              if (_showConfirmPw) ...[
                MyTextfield(
                  hintText: "Confirm password",
                  obscureText: true,
                  controller: _confirmPwController,
                ),
                const SizedBox(height: 20),
              ],
              _isLoading
                  ? const CircularProgressIndicator()
                  : MyButton(
                text: "Register",
                onTap: () => register(context),
                backgroundColor: theme.colorScheme.primary,
                textColor: theme.colorScheme.onPrimary,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onTap,
                    child: Text(
                      "Login now",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}