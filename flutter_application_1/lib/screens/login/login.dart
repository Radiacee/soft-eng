import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isPasswordVisible = false;
  bool _isLoading = false; // Add loading state variable

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email and password cannot be empty")),
      );
      return;
    }

    setState(() {
      _isLoading = true; // Set loading state to true
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user is signed in
      if (userCredential.user != null) {
        Navigator.pushNamed(context, '/adminPanel'); // Navigate to admin panel
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No user found for that email")),
        );
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided for that user.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Wrong password provided")),
        );
      } else if (e.code == 'invalid-email') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid email address.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.message}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An unexpected error occurred")),
      );
    } finally {
      setState(() {
        _isLoading = false; // Set loading state to false
      });
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email")),
      );
      return;
    }
    try {
      // Send password reset email regardless of email registration status
      await _auth.sendPasswordResetEmail(email: email);
      // Display a generic message for security
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("A password reset link has been sent to the email."),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a valid email address.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.message}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An unexpected error occurred")),
      );
    }
  }

  Future<bool> checkIfAdmin() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Custom claims will be in the ID token payload
      IdTokenResult tokenResult = await user.getIdTokenResult();
      return tokenResult.claims?['admin'] == true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("TableServe"),
        automaticallyImplyLeading: false, // Remove the auto back button
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: 0, // Make sure it's at the bottom of the screen
            left: 0,
            right: 0,
            child: Builder(
              builder: (context) {
                // Get the screen width
                double screenWidth = MediaQuery.of(context).size.width;

                // Assuming the image's aspect ratio (width / height) is 16:9 (you can adjust based on your image)
                double aspectRatio = 16 / 9;
                double imageHeight = screenWidth / aspectRatio;

                return Container(
                  width: screenWidth,
                  height: imageHeight, // Responsive height based on aspect ratio
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('images/bg.png'), // Replace with your background image path
                      fit: BoxFit.cover, // Ensure it covers the width and scales the height responsively
                    ),
                  ),
                );
              },
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Admin Panel",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                  ),
                  const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: Text("Forgot password?"),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _isLoading
                      ? CircularProgressIndicator() // Show loading indicator
                      : ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          child: Text(
                            "Login",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}