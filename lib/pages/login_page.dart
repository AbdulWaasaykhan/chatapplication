import 'package:chatapplication/services/auth/auth_service.dart';
import 'package:chatapplication/components/my_button.dart';
import 'package:chatapplication/components/my_textfield.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {

  //email and pw text controller
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  // tap to go to register page
  final void Function()? onTap;


  LoginPage({super.key, required this.onTap});

// login method
  Future<void> login(BuildContext context) async {
    final authService = AuthService();

    // email required
    if (_emailController.text.trim().isEmpty) {
      _showErrorDialog(context, "Email required", "Please enter your email.");
      return;
    }

    // email format check
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showErrorDialog(context, "Invalid email", "Please enter a valid email address.");
      return;
    }

    // password required
    if (_pwController.text.trim().isEmpty) {
      _showErrorDialog(context, "Password required", "Please enter your password.");
      return;
    }

    try {
      // attempt login
      await authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _pwController.text.trim(),
      );
    } catch (e) {
      _showErrorDialog(context, "Login failed", e.toString());
    }
  }

// helper method for showing errors
  void _showErrorDialog(BuildContext context, String title, String message) {
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
      backgroundColor: Theme
          .of(context)
          .colorScheme
          .background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // logo
              Icon(
                Icons.mail_lock_rounded,
                size: 70,
                color: Theme
                    .of(context)
                    .colorScheme
                    .primary,
              ),
              const SizedBox(height: 10),

              // welcome back message
              Text(
                "Welcome Back, You've been missed!",
                style: TextStyle(
                  color: Theme
                      .of(context)
                      .colorScheme
                      .primary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),

              // email textfield
              MyTextfield(
                hintText: "Email",
                obscureText: false,
                controller: _emailController,
              ),
              const SizedBox(height: 10),

              // pw textfield
              MyTextfield(
                hintText: "Password",
                obscureText: true,
                controller: _pwController,
              ),
              const SizedBox(height: 20),

              // login button
              MyButton(
                text: "Login",
                onTap: () => login(context),
              ),
              const SizedBox(height: 20),

              // register now
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Not a member? ",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  GestureDetector(
                    onTap: onTap,
                    child: Text(
                      "Register now",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme
                            .of(context)
                            .colorScheme
                            .primary,
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
