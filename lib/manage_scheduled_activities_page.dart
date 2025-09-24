import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageScheduledActivitiesPage extends StatefulWidget {
  const ManageScheduledActivitiesPage({Key? key}) : super(key: key);

  @override
  _ManageScheduledActivitiesPageState createState() => _ManageScheduledActivitiesPageState();
}

class _ManageScheduledActivitiesPageState extends State<ManageScheduledActivitiesPage> {
  String _filter = 'all'; // 'all', 'scheduled', 'completed'
  bool _loading = true;
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _loading = true;
    });

    try {
      Query query = FirebaseFirestore.instance.collection('scheduled_activities');

      // Apply filter if not 'all'
      if (_filter == 'scheduled') {
        query = query.where('status', isEqualTo: 'scheduled');
      } else if (_filter == 'completed') {
        query = query.where('status', isEqualTo: 'completed');
      }

      final querySnapshot = await query.get();

      final activities = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return {
          'id': doc.id,
          'courseId': data['courseId'] ?? '',
          'courseName': data['courseName'] ?? '',
          'activityType': data['activityType'] ?? '',
          'scheduledDate': data['scheduledDate']?.toDate(),
          'startTime': data['startTime'] ?? '',
          'endTime': data['endTime'] ?? '',
          'status': data['status'] ?? 'scheduled',
          'completedAt': data['completedAt']?.toDate(),
        };
      }).toList();

      // Sort by scheduled date (newest first)
      activities.sort((a, b) {
        if (a['scheduledDate'] == null && b['scheduledDate'] == null) return 0;
        if (a['scheduledDate'] == null) return 1;
        if (b['scheduledDate'] == null) return -1;
        return b['scheduledDate'].compareTo(a['scheduledDate']);
      });

      setState(() {
        _activities = activities;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load activities: $e')),
      );
    }
  }

  Future<void> _reopenActivity(String activityId) async {
    try {
      await FirebaseFirestore.instance
          .collection('scheduled_activities')
          .doc(activityId)
          .update({
        'status': 'scheduled',
        'completedAt': FieldValue.delete(), // Remove completed timestamp
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activity reopened successfully')),
      );

      // Reload activities to reflect changes
      _loadActivities();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reopen activity: $e')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Scheduled Activities'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter buttons
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _filter == 'all' ? Colors.deepPurple : Colors.grey[300],
                      foregroundColor: _filter == 'all' ? Colors.white : Colors.black,
                    ),
                    onPressed: () {
                      setState(() {
                        _filter = 'all';
                      });
                      _loadActivities();
                    },
                    child: Text('All'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _filter == 'scheduled' ? Colors.green : Colors.grey[300],
                      foregroundColor: _filter == 'scheduled' ? Colors.white : Colors.black,
                    ),
                    onPressed: () {
                      setState(() {
                        _filter = 'scheduled';
                      });
                      _loadActivities();
                    },
                    child: Text('Scheduled'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _filter == 'completed' ? Colors.blue : Colors.grey[300],
                      foregroundColor: _filter == 'completed' ? Colors.white : Colors.black,
                    ),
                    onPressed: () {
                      setState(() {
                        _filter = 'completed';
                      });
                      _loadActivities();
                    },
                    child: Text('Completed'),
                  ),
                ),
              ],
            ),
          ),

          // Activities list
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _activities.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.schedule, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No activities found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            Text(
                              'Create some scheduled activities to see them here',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _activities.length,
                        itemBuilder: (context, index) {
                          final activity = _activities[index];
                          return Card(
                            elevation: 3,
                            margin: EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          activity['courseName'] ?? 'Unknown Course',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(activity['status']).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _getStatusColor(activity['status']),
                                          ),
                                        ),
                                        child: Text(
                                          _getStatusText(activity['status']),
                                          style: TextStyle(
                                            color: _getStatusColor(activity['status']),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Activity Type: ${activity['activityType']?.toUpperCase() ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Scheduled Date: ${activity['scheduledDate'] != null ? '${activity['scheduledDate'].day}/${activity['scheduledDate'].month}/${activity['scheduledDate'].year}' : 'N/A'}',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                  ),
                                  if (activity['startTime'].isNotEmpty && activity['endTime'].isNotEmpty)
                                    Text(
                                      'Time: ${activity['startTime']} - ${activity['endTime']}',
                                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                    ),
                                  if (activity['status'] == 'completed' && activity['completedAt'] != null)
                                    Text(
                                      'Completed: ${activity['completedAt'].day}/${activity['completedAt'].month}/${activity['completedAt'].year} at ${activity['completedAt'].hour}:${activity['completedAt'].minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(fontSize: 12, color: Colors.blue),
                                    ),
                                  SizedBox(height: 12),
                                  if (activity['status'] == 'completed')
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          icon: Icon(Icons.replay),
                                          label: Text('Reopen Activity'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () => _reopenActivity(activity['id']),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadActivities,
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.refresh),
        tooltip: 'Refresh',
      ),
    );
  }
}
