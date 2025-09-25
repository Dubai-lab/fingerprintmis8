import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageDepartmentsPage extends StatefulWidget {
  const ManageDepartmentsPage({Key? key}) : super(key: key);

  @override
  _ManageDepartmentsPageState createState() => _ManageDepartmentsPageState();
}

class _ManageDepartmentsPageState extends State<ManageDepartmentsPage> {
  final TextEditingController _departmentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _addDepartment() async {
    final departmentName = _departmentController.text.trim();
    if (departmentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a department name')),
      );
      return;
    }

    try {
      // Check if department already exists
      final existingDept = await _firestore
          .collection('departments')
          .where('name', isEqualTo: departmentName)
          .get();

      if (existingDept.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Department already exists')),
        );
        return;
      }

      await _firestore.collection('departments').add({
        'name': departmentName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _departmentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Department "$departmentName" added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add department: $e')),
      );
    }
  }

  Future<void> _deleteDepartment(String departmentId, String departmentName) async {
    try {
      // Check if department is being used by students or courses
      final studentsUsingDept = await _firestore
          .collection('students')
          .where('department', isEqualTo: departmentName)
          .get();

      final coursesUsingDept = await _firestore
          .collection('instructor_courses')
          .where('department', isEqualTo: departmentName)
          .get();

      if (studentsUsingDept.docs.isNotEmpty || coursesUsingDept.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete department that is being used by students or courses')),
        );
        return;
      }

      await _firestore.collection('departments').doc(departmentId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Department "$departmentName" deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete department: $e')),
      );
    }
  }

  Future<void> _editDepartment(String departmentId, String currentName) async {
    final TextEditingController editController = TextEditingController(text: currentName);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Department'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(labelText: 'Department Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = editController.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a department name')),
                );
                return;
              }

              try {
                // Check if new name already exists
                final existingDept = await _firestore
                    .collection('departments')
                    .where('name', isEqualTo: newName)
                    .get();

                if (existingDept.docs.isNotEmpty && existingDept.docs.first.id != departmentId) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Department name already exists')),
                  );
                  return;
                }

                await _firestore.collection('departments').doc(departmentId).update({
                  'name': newName,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Department updated to "$newName"')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update department: $e')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Departments'),
        backgroundColor: Colors.deepPurple.shade600,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade200, Colors.deepPurple.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Add Department Section
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Add New Department',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _departmentController,
                      decoration: InputDecoration(
                        labelText: 'Department Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.school, color: Colors.deepPurple),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _addDepartment,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Add Department', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Departments List
            Expanded(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: Colors.white.withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Existing Departments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _firestore.collection('departments').orderBy('name').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final departments = snapshot.data!.docs;

                            if (departments.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No departments found. Add your first department above.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: departments.length,
                              itemBuilder: (context, index) {
                                final department = departments[index];
                                final departmentName = department['name'] ?? 'Unnamed Department';

                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    title: Text(
                                      departmentName,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () => _editDepartment(department.id, departmentName),
                                          tooltip: 'Edit Department',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteDepartment(department.id, departmentName),
                                          tooltip: 'Delete Department',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
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
