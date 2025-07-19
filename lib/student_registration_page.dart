import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'fingerprint_sdk.dart';

class StudentRegistrationPage extends StatefulWidget {
  @override
  _StudentRegistrationPageState createState() => _StudentRegistrationPageState();
}

class _StudentRegistrationPageState extends State<StudentRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _regNumberController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();

  String _status = 'Idle';
  String? _fingerprintTemplateBase64;

  Future<void> _navigateToFingerprintCapture() async {
    final result = await Navigator.pushNamed(context, '/fingerprint_enrollment');
    if (result != null && result is String && result.isNotEmpty) {
      setState(() {
        _fingerprintTemplateBase64 = result;
        _status = 'Fingerprint captured';
      });
    } else {
      setState(() {
        _status = 'Fingerprint capture cancelled or failed';
      });
    }
  }

  Future<void> _saveStudent() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;
    if (_fingerprintTemplateBase64 == null) {
      setState(() {
        _status = 'Please capture fingerprint first';
      });
      return;
    }
    String name = _nameController.text.trim();
    String regNumber = _regNumberController.text.trim();
    String sanitizedRegNumber = regNumber.replaceAll('/', '_');

    try {
      await FirebaseFirestore.instance.collection('students').doc(sanitizedRegNumber).set({
        'name': name,
        'regNumber': regNumber,
        'department': _departmentController.text.trim(),
        'fingerprintTemplate': _fingerprintTemplateBase64,
      });
      setState(() {
        _status = 'Student registered successfully';
        _nameController.clear();
        _regNumberController.clear();
        _departmentController.clear();
        _fingerprintTemplateBase64 = null;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to save student: $e';
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
          'Student Registration',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Student Registration',
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
                          color: _status.toLowerCase().contains('success') ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Student Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.person, color: Colors.deepPurple),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Enter student name' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _regNumberController,
                        decoration: InputDecoration(
                          labelText: 'Registration Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.confirmation_number, color: Colors.deepPurple),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter registration number';
                          }
                          final regExp = RegExp(r'^\d{5}/\d{4}$');
                          if (!regExp.hasMatch(value)) {
                            return 'Enter registration number in format 5digits/year';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _departmentController,
                        decoration: InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.school, color: Colors.deepPurple),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Enter department' : null,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _navigateToFingerprintCapture,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Fingerprint Capture', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _saveStudent,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Save Student', style: TextStyle(fontSize: 18, color: Colors.white)),
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
