import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({Key? key}) : super(key: key);

  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String _selectedRole = 'instructor'; // Default role
  String _status = 'Idle';
  bool _isLoading = false;

  /// Generate a random password with letters + numbers + symbols
  String _generatePassword([int length = 12]) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final rand = Random.secure();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)])
        .join();
  }

  /// Get the collection name based on selected role
  String _getCollectionName() {
    switch (_selectedRole) {
      case 'instructor':
        return 'instructors';
      case 'invigilator':
        return 'invigilators';
      case 'security':
        return 'security';
      default:
        return 'instructors';
    }
  }

  /// Get the display name for the selected role
  String _getRoleDisplayName() {
    switch (_selectedRole) {
      case 'instructor':
        return 'Instructor';
      case 'invigilator':
        return 'Invigilator';
      case 'security':
        return 'Security';
      default:
        return 'User';
    }
  }

  Future<void> _registerUser() async {
    if (_formKey.currentState == null ||
        !_formKey.currentState!.validate()) return;

    String name = _nameController.text.trim();
    String email = _emailController.text.trim();

    // Generate random temporary password
    String tempPassword = _generatePassword(12);

    setState(() {
      _isLoading = true;
      _status = 'Registering...';
    });

    try {
      // Create Firebase Auth account
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );

      final uid = userCredential.user!.uid;
      final collectionName = _getCollectionName();

      // Save to role-specific collection (flag only)
      await FirebaseFirestore.instance.collection(collectionName).doc(uid).set({
        'name': name,
        'email': email,
        'role': _selectedRole,
        'defaultPassword': tempPassword, // flag
        'passwordSetTime': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Save to users collection (for Cloud Function to send welcome email)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'role': _selectedRole,
        'defaultPassword': tempPassword, // actual temporary password
        'passwordSetTime': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _status = '✅ ${_getRoleDisplayName()} registered successfully';
        _nameController.clear();
        _emailController.clear();
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          _status = '❌ Email already in use';
        } else if (e.code == 'weak-password') {
          _status = '❌ Password is too weak';
        } else {
          _status = '❌ Failed to register ${_getRoleDisplayName().toLowerCase()}: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _status = '❌ An error occurred: $e';
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
          'User Registration',
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
                        'User Registration',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Role Selection Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          labelText: 'User Role',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.person_outline, color: Colors.deepPurple),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'instructor',
                            child: Text('Instructor'),
                          ),
                          DropdownMenuItem(
                            value: 'invigilator',
                            child: Text('Invigilator'),
                          ),
                          DropdownMenuItem(
                            value: 'security',
                            child: Text('Security'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                          });
                        },
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please select a role'
                            : null,
                      ),
                      SizedBox(height: 16),

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
                          labelText: '${_getRoleDisplayName()} Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon:
                              Icon(Icons.person, color: Colors.deepPurple),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter ${_getRoleDisplayName().toLowerCase()} name'
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
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter email'
                            : null,
                      ),
                      SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: _isLoading ? null : _registerUser,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('Register ${_getRoleDisplayName()}',
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
