import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DefaultPasswordWarningWidget extends StatefulWidget {
  const DefaultPasswordWarningWidget({Key? key}) : super(key: key);

  @override
  _DefaultPasswordWarningWidgetState createState() => _DefaultPasswordWarningWidgetState();
}

class _DefaultPasswordWarningWidgetState extends State<DefaultPasswordWarningWidget> {
  bool _showWarning = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkDefaultPasswordStatus();
  }

  Future<void> _checkDefaultPasswordStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _showWarning = false;
        });
        return;
      }

      final uid = user.uid;

      // Check all possible collections for the user
      final collections = ['instructors', 'invigilators', 'security'];
      bool hasDefaultPassword = false;

      for (var collection in collections) {
        final doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          final defaultPassword = data?['defaultPassword'];

          // Check if defaultPassword exists and is a non-empty string
          if (defaultPassword != null && defaultPassword.toString().isNotEmpty) {
            hasDefaultPassword = true;
            break;
          }
        }
      }

      setState(() {
        _showWarning = hasDefaultPassword;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showWarning = false;
      });
    }
  }

  void _hideWarning() {
    setState(() {
      _showWarning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (!_showWarning) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        border: Border.all(color: Colors.orange.shade300, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade800,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Security Alert: Change Your Default Password',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You are currently using a default password. For your security, please change it immediately.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () async {
                  // Navigate to change password page
                  final result = await Navigator.pushNamed(context, '/change-password');

                  // If password was changed successfully, hide the warning
                  if (result == true) {
                    _hideWarning();
                    _checkDefaultPasswordStatus(); // Refresh the status
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Change Password Now'),
              ),
              TextButton(
                onPressed: _hideWarning,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange.shade600,
                ),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
