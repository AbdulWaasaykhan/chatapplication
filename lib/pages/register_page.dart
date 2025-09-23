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
  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _confirmPwController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _pwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  Future<void> register(BuildContext context) async {
    final _auth = AuthService();

    if (_pwController.text == _confirmPwController.text) {
      try {
        var userCredential = await _auth.signUpWithEmailPassword(
          _emailController.text,
          _pwController.text,
        );

        if (userCredential != null && userCredential.user != null) {
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(userCredential.user!.uid)
              .set({
            'email': userCredential.user!.email,
            'uid': userCredential.user!.uid,
            'username': _usernameController.text,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Error"),
            content: Text(e.toString()),
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Passwords don't match!"),
        ),
      );
    }
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
                Icons.message,
                size: 60,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 50),

              Text(
                "Let's create an account for you",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 25),

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

              MyTextfield(
                hintText: "Confirm password",
                obscureText: true,
                controller: _confirmPwController,
              ),
              const SizedBox(height: 25),

              MyButton(
                text: "Register",
                onTap: () => register(context),
                backgroundColor: theme.colorScheme.primary,
                textColor: theme.colorScheme.onPrimary,
              ),
              const SizedBox(height: 25),

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
