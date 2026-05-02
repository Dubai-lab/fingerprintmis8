import 'package:flutter/material.dart';

class StudentPaymentCard extends StatelessWidget {
  final String studentName;
  final String regNumber;
  final String department;
  final double dueBalance;
  final String paymentStatus;
  final double? attendancePercentage; // NEW: Student's course attendance percentage
  final VoidCallback onApprove;
  final VoidCallback onCancel;

  const StudentPaymentCard({
    Key? key,
    required this.studentName,
    required this.regNumber,
    required this.department,
    required this.dueBalance,
    required this.paymentStatus,
    this.attendancePercentage,
    required this.onApprove,
    required this.onCancel,
  }) : super(key: key);

  Color _getPaymentColor() {
    if (dueBalance == 0 || paymentStatus == 'CLEARED') {
      return Colors.green;
    } else if (paymentStatus == 'OVERDUE') {
      return Colors.red;
    }
    return Colors.orange;
  }

  Color _getAttendanceColor() {
    if (attendancePercentage == null) return Colors.grey;
    if (attendancePercentage! >= 80) {
      return Colors.green;
    } else if (attendancePercentage! >= 60) {
      return Colors.orange;
    }
    return Colors.red;
  }

  String _getAttendanceStatus() {
    if (attendancePercentage == null) return 'No Data';
    if (attendancePercentage! >= 80) {
      return '✅ EXCELLENT';
    } else if (attendancePercentage! >= 60) {
      return '⚠️ ACCEPTABLE';
    }
    return '❌ POOR';
  }

  String _getPaymentLabel() {
    if (dueBalance == 0 || paymentStatus == 'CLEARED') {
      return '✅ CLEARED';
    } else if (paymentStatus == 'OVERDUE') {
      return '❌ OVERDUE';
    }
    return '⚠️ PENDING';
  }

  bool _isPaymentCleared() {
    return dueBalance == 0 && paymentStatus == 'CLEARED';
  }

  @override
  Widget build(BuildContext context) {
    final paymentColor = _getPaymentColor();
    final attendanceColor = _getAttendanceColor();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ============ STUDENT INFO HEADER (Compact) ============
            Row(
              children: [
                Icon(Icons.account_circle, size: 48, color: Colors.deepPurple),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Reg: $regNumber',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        department,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),
            Divider(height: 1),
            SizedBox(height: 16),

            // ============ STATUS ROW (Compact) ============
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Attendance Status (Left)
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: attendanceColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: attendanceColor, width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Attendance',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          attendancePercentage != null
                              ? '${attendancePercentage!.toStringAsFixed(1)}%'
                              : 'N/A',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: attendanceColor,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          _getAttendanceStatus(),
                          style: TextStyle(
                            fontSize: 10,
                            color: attendanceColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(width: 12),

                // Payment Status (Right)
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: paymentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: paymentColor, width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Payment',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        if (dueBalance > 0)
                          Text(
                            'PKR ${dueBalance.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: paymentColor,
                            ),
                          )
                        else
                          Text(
                            'Cleared',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: paymentColor,
                            ),
                          ),
                        SizedBox(height: 3),
                        Text(
                          _getPaymentLabel(),
                          style: TextStyle(
                            fontSize: 10,
                            color: paymentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // ============ ACTION BUTTONS ============
            if (_isPaymentCleared())
              // Payment cleared - Show Mark Present button
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.check_circle, size: 18),
                      label: Text('Mark Present'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onApprove,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.close, size: 18),
                      label: Text('Cancel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onCancel,
                    ),
                  ),
                ],
              )
            else
              // Payment pending/overdue - Show warning and cancel
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: paymentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: paymentColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: paymentColor, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Outstanding payment. Cannot mark attendance.',
                            style: TextStyle(
                              fontSize: 11,
                              color: paymentColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.close, size: 18),
                      label: Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onCancel,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
