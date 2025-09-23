import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _status = '';
  bool _loading = false;
  bool _obscurePassword = true; // Add this for password visibility toggle

  Future<void> _login() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _status = 'Logging in...';
    });

    try {
      // Firebase Auth login
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      // Helper to fetch user document from all collections
      Future<DocumentSnapshot?> getUserDoc() async {
        final collections = ['instructors', 'invigilators', 'admins', 'security'];
        for (var col in collections) {
          final doc = await FirebaseFirestore.instance.collection(col).doc(uid).get();
          if (doc.exists) return doc;
        }
        return null;
      }

      final userDoc = await getUserDoc();
      if (userDoc == null) {
        setState(() {
          _status = 'User data not found. Access denied.';
        });
        await FirebaseAuth.instance.signOut();
        return;
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final String role = data['role'] ?? '';
      final bool defaultPasswordFlag = data['defaultPasswordFlag'] ?? false;
      final String? passwordSetTimeStr = data['passwordSetTime'];

      setState(() {
        _status = 'Login successful';
      });

      // Check default password flag and 24-hour expiry
      if (defaultPasswordFlag && passwordSetTimeStr != null && role != 'admin') {
        final DateTime passwordSetTime = DateTime.parse(passwordSetTimeStr);
        final Duration diff = DateTime.now().difference(passwordSetTime);
        if (diff.inHours >= 24) {
          // Redirect to change password page
          Navigator.pushReplacementNamed(context, '/change-password');
          return;
        }
      }

      // Redirect based on role
      if (role == 'instructor') {
        Navigator.pushReplacementNamed(context, '/instructor_dashboard');
      } else if (role == 'invigilator') {
        Navigator.pushReplacementNamed(context, '/invigilator_dashboard');
      } else if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      } else if (role == 'security') {
        Navigator.pushReplacementNamed(context, '/security_dashboard');
      } else {
        setState(() {
          _status = 'User role not found. Access denied.';
        });
        await FirebaseAuth.instance.signOut();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _status = 'Login failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _status = 'Login failed: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(''),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/image/logo.png',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.3),
              colorBlendMode: BlendMode.darken,
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                color: Colors.black.withOpacity(0.3),
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SingleChildScrollView(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      color: Colors.white.withOpacity(0.2),
                      padding: EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset('assets/image/logo.png', height: 100),
                            SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              // Email validation
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Enter email' : null,
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: const Color.fromARGB(255, 28, 1, 177),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              obscureText: _obscurePassword,
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Enter password' : null,
                            ),
                            SizedBox(height: 24),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(double.infinity, 50),
                                backgroundColor: Colors.white.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _loading ? null : _login,
                              child: _loading
                                  ? CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      'Login',
                                      style: TextStyle(color: Colors.white, fontSize: 18),
                                    ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              _status,
                              style: TextStyle(
                                color: _status.toLowerCase().contains('success')
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
