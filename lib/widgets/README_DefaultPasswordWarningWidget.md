# Default Password Warning Widget

## Overview
This reusable widget automatically checks if a user is using a default password and displays a warning message with a link to change it. Once the password is changed, the warning disappears automatically.

## Usage

### 1. Import the widget
```dart
import 'package:fingerprintmis8/widgets/default_password_warning_widget.dart';
```

### 2. Add to any dashboard
Simply add the widget to your dashboard's widget tree:

```dart
class YourDashboardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: Column(
        children: [
          // Add the warning widget at the top
          const DefaultPasswordWarningWidget(),

          // Your other dashboard content
          // ... rest of your widgets
        ],
      ),
    );
  }
}
```

## Features

### ✅ Automatic Detection
- Checks all user collections (instructors, invigilators, security)
- Automatically shows/hides based on `defaultPassword` string field in Firestore
- Shows warning when `defaultPassword` field contains a non-empty string
- No manual state management needed

### ✅ User-Friendly Interface
- Orange warning design with clear messaging
- "Change Password Now" button that navigates to change password page
- "Dismiss" button to hide warning temporarily
- Responsive design that works on all screen sizes

### ✅ Smart Navigation
- Returns `true` when password is successfully changed
- Automatically refreshes status after password change
- Integrates with existing `change_password_page.dart`

### ✅ Security Features
- Only shows for users with `defaultPassword` field containing a string value
- Excludes admin users from showing warnings
- Works with Firebase Authentication and Firestore

## Integration Examples

### Instructor Dashboard
```dart
// In your instructor dashboard
body: Padding(
  padding: const EdgeInsets.all(20.0),
  child: Column(
    children: [
      const DefaultPasswordWarningWidget(), // Add this line
      // ... rest of your dashboard content
    ],
  ),
),
```

### Security Dashboard
```dart
// In your security dashboard
body: Column(
  children: [
    const DefaultPasswordWarningWidget(), // Add this line
    // ... rest of your dashboard content
  ],
),
```

### Invigilator Dashboard
```dart
// In your invigilator dashboard
body: Column(
  children: [
    const DefaultPasswordWarningWidget(), // Add this line
    // ... rest of your dashboard content
  ],
),
```

## How It Works

1. **Initialization**: Widget checks user's authentication status
2. **Database Query**: Searches all user collections for the current user
3. **Password Check**: Looks for `defaultPassword` field with string value in user document
4. **Display Logic**: Shows warning only if `defaultPassword` field contains a non-empty string
5. **Navigation**: Provides direct link to password change page
6. **Auto-Hide**: Warning disappears after successful password change and database update

## Benefits

- **Reusable**: One widget works across all dashboards
- **Automatic**: No manual checking or state management needed
- **Consistent**: Same warning experience across all user types
- **Maintainable**: Single source of truth for password warnings
- **User-Friendly**: Clear messaging and easy-to-use interface

## Notes

- The widget automatically handles loading states
- Works with existing Firebase Authentication setup
- Compatible with current Firestore database structure
- No additional dependencies required
- Follows existing app design patterns and color scheme
