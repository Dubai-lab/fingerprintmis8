# Firestore Collections and Document Structure for FingerprintMIS8

This document outlines the Firestore collections and document structures based on the ERD diagram and the project code.

## Collections and Documents

### Users (Abstract)
- Stored in separate collections by role: `students`, `instructors`, `invigilators`, `admins`, `security`
- Common fields:
  - userId (document ID)
  - name: string
  - email: string
  - role: string (student, instructor, invigilator, admin, security)
  - defaultPassword: bool
  - passwordSetTime: timestamp (nullable)

### Students
- Collection: `students`
- Document ID: regNumber (string)
- Fields:
  - name: string
  - department: string
  - fingerprintTemplate: string (base64)

### Instructors
- Collection: `instructors`
- Document ID: userId (string)
- Fields:
  - name: string
  - email: string
  - role: string
  - defaultPassword: bool
  - passwordSetTime: timestamp

### Invigilators
- Collection: `invigilators`
- Document ID: userId (string)
- Fields:
  - name: string
  - email: string
  - role: string
  - defaultPassword: bool
  - passwordSetTime: timestamp

### Admins
- Collection: `admins`
- Document ID: userId (string)
- Fields:
  - name: string
  - email: string
  - role: string

### Security
- Collection: `security`
- Document ID: userId (string)
- Fields:
  - name: string
  - email: string
  - role: string
  - defaultPassword: bool
  - passwordSetTime: timestamp

### Courses
- Collection: `instructor_courses`
- Document ID: courseId (string)
- Fields:
  - courseName: string
  - session: string
  - instructorId: string (reference to instructors)
  - startDate: timestamp
  - endDate: timestamp
  - department: string

### Students Joined to Course
- Subcollection: `students` under each course document
- Document ID: studentId (string)
- Fields:
  - joinedAt: timestamp

### Attendance Sessions
- Collection: `attendance_sessions`
- Document ID: sessionId (string)
- Fields:
  - courseId: string (reference to course)
  - sessionName: string
  - createdAt: timestamp

### Attendance Records (Instructor)
- Subcollection: `attendance` under each course document
- Document ID: attendanceId (string)
- Fields:
  - regNumber: string (student regNumber)
  - courseId: string
  - courseName: string
  - sessionId: string (reference to attendance session)
  - status: string (e.g., Present, Absent)
  - timestamp: timestamp

### Attendance Records (Invigilator)
- Collection: `invigilator_activities`
- Document ID: activity name (e.g., CAT, EXAM, CONFERENCE)
- Subcollection: `attendance`
- Document ID: attendanceId (string)
- Fields:
  - regNumber: string
  - activity: string
  - courseId: string (nullable for CONFERENCE)
  - status: string
  - timestamp: timestamp

### Fingerprint Data
- Stored as part of student documents in `students` collection under `fingerprintTemplate` field (base64 string)

## Indexes and Security Rules

- Indexes should be created on fields used in queries, such as:
  - `instructor_courses` by `instructorId`
  - `attendance` subcollections by `timestamp`, `regNumber`
  - `invigilator_activities` attendance by `courseId`, `timestamp`

- Security rules should enforce role-based access control and data validation.

---

This structure aligns with the ERD and the codebase you provided.

If you want, I can help you create Firestore security rules or scripts to initialize these collections.
