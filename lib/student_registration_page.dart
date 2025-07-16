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
        title: Text('Student Registration'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text('Status: $_status'),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Student Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter student name' : null,
              ),
          TextFormField(
            controller: _regNumberController,
            decoration: InputDecoration(labelText: 'Registration Number'),
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
          TextFormField(
            controller: _departmentController,
            decoration: InputDecoration(labelText: 'Department'),
            validator: (value) =>
                value == null || value.isEmpty ? 'Enter department' : null,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _navigateToFingerprintCapture,
            child: Text('Fingerprint Capture'),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveStudent,
            child: Text('Save Student'),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
