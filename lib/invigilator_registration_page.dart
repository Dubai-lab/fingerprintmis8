import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InvigilatorRegistrationPage extends StatefulWidget {
  @override
  _InvigilatorRegistrationPageState createState() =>
      _InvigilatorRegistrationPageState();
}

class _InvigilatorRegistrationPageState
    extends State<InvigilatorRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _status = 'Idle';
  bool _isLoading = false;

  /// Generate a random password with letters + numbers
  String _generatePassword([int length = 10]) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final rand = Random.secure();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)])
        .join();
  }

  Future<void> _saveInvigilator() async {
    if (_formKey.currentState == null ||
        !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _status = 'Registering...';
    });

    String name = _nameController.text.trim();
    String email = _emailController.text.trim();

    // Generate a random temporary password
    String tempPassword = _generatePassword(12);

    try {
      // ✅ Create Firebase Auth account
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );

      final uid = userCredential.user!.uid;

      // ✅ Save to Firestore: invigilators collection (do not store actual password)
      await FirebaseFirestore.instance.collection('invigilators').doc(uid).set({
        'name': name,
        'email': email,
        'role': 'invigilator',
        'defaultPassword': true, // flag
        'passwordSetTime': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ Save also to users collection (this will be used by Cloud Function to send email)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'role': 'invigilator',
        'defaultPassword': tempPassword, // store actual temporary password
        'passwordSetTime': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _status = '✅ Invigilator registered successfully';
        _nameController.clear();
        _emailController.clear();
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _status = '❌ Failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade600,
        elevation: 0,
        title: Text(
          'Invigilator Registration',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade200, Colors.deepPurple.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Invigilator Registration',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Status: $_status',
                        style: TextStyle(
                          color: _status.toLowerCase().contains('success')
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Invigilator Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon:
                              Icon(Icons.person, color: Colors.deepPurple),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty
                                ? 'Enter invigilator name'
                                : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon:
                              Icon(Icons.email, color: Colors.deepPurple),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty
                                ? 'Enter email'
                                : null,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveInvigilator,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('Save Invigilator',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
