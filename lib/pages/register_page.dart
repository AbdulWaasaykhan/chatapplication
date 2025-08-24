import 'package:chatapplication/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import '../components/my_button.dart';
import '../components/my_textfield.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class RegisterPage extends StatelessWidget{
  //email and pw text controller
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _confirmPwController = TextEditingController();
  
  // tap to go to register page
  final void Function()? onTap;

   RegisterPage({super.key, required this.onTap});


//register method
Future<void> register(BuildContext context) async { // <-- make async
  // get auth service
  final _auth = AuthService();

  // password match => create user
  if (_pwController.text == _confirmPwController.text) {
    try {
      // Wait for sign up and get the user
      var userCredential = await _auth.signUpWithEmailPassword(
        _emailController.text,
        _pwController.text,
      );

      // Add user to Firestore Users collection
      if (userCredential != null && userCredential.user != null) {
        await FirebaseFirestore.instance.collection('Users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          'uid': userCredential.user!.uid,
        });
      }

    } catch (e) {
      showDialog(
        context: context, 
        builder: (context) => AlertDialog(
          title: Text(e.toString()),
        ),
      );
    }
  }
  //password dont match => tell user to fix it
  else {
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
    return Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        //logo
        Icon(
          Icons.message,
          size: 60,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 50),

        //welcome back message
        Text(
          "Let's create an account for you",
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 16,
          ),
          ),

          const SizedBox(height: 25),

        //email textfield
         MyTextfield(
          hintText: "Email",
           obscureText: false,
           controller: _emailController,
         ),

          const SizedBox(height: 10),

        //pw textfield
          MyTextfield(
          hintText: "Password",
          obscureText: true,
          controller: _pwController,
         ),

          const SizedBox(height: 10),

         //Confirm pw textfield
          MyTextfield(
          hintText: "Confirm password",
          obscureText: true,
          controller: _confirmPwController,
         ),

         const SizedBox(height: 25),

        // login buttion
        MyButton(
          text: "Register",
          onTap: () => register(context),
        ),

        const SizedBox(height: 25),

        // register now
        Row(
          children: [
            Text("Already have an account? ",
            style: 
            TextStyle(color:  Theme.of(context).colorScheme.primary),
            ),
            GestureDetector(
              onTap: onTap,
              child: Text(
                "Login now",
               style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
      ],
     ),
    )
   );
  }
}