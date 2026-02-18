# lockedIn

A productivity leaderboard app for Notre Dame students that ranks users by verified focused time, with social profiles and accountability features.

## Features

- **Focus Sessions**: Start timed focus sessions with camera verification
- **Leaderboard**: Compete with classmates on weekly/monthly/all-time rankings
- **Social Profiles**: Share study tools, Spotify playlists, and tips
- **Activity Feed**: See when friends complete focus sessions
- **Follow System**: Follow classmates and build accountability networks

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Firebase account

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode
2. Create a new iOS App project
3. Product Name: `lockedIn`
4. Organization Identifier: `com.yourname`
5. Interface: SwiftUI
6. Language: Swift

### 2. Add Firebase SDK

1. In Xcode, go to File > Add Package Dependencies
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: Up to Next Major Version
4. Add the following packages:
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseStorage

### 3. Configure Firebase

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project named "lockedIn"
3. Add an iOS app with your bundle identifier
4. Download `GoogleService-Info.plist`
5. Add it to your Xcode project (drag into the project navigator)

### 4. Set Up Firestore

1. In Firebase Console, go to Firestore Database
2. Create database in production mode
3. Set up security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read any user profile
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;

      // Sessions subcollection
      match /sessions/{sessionId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null && request.auth.uid == userId;
      }

      // Following subcollection
      match /following/{followedId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null && request.auth.uid == userId;
      }

      // Followers subcollection
      match /followers/{followerId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null && request.auth.uid == followerId;
      }
    }
  }
}
```

### 5. Set Up Firebase Storage

1. In Firebase Console, go to Storage
2. Set up security rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_photos/{userId}.jpg {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 6. Enable Authentication

1. In Firebase Console, go to Authentication
2. Enable Email/Password sign-in method

### 7. Copy Source Files

Copy all files from the `lockedIn/lockedIn/` directory into your Xcode project, maintaining the folder structure.

### 8. Add Required Capabilities (Optional - for Screen Time)

To enable app blocking during focus sessions:
1. In Xcode, select your target
2. Go to Signing & Capabilities
3. Add "Family Controls" capability
4. Note: This requires Apple Developer Program membership

## Project Structure

```
lockedIn/
├── App/
│   ├── lockedInApp.swift      # App entry point
│   └── ContentView.swift       # Main tab view
├── Models/
│   ├── User.swift              # User profile model
│   ├── FocusSession.swift      # Focus session model
│   └── LeaderboardEntry.swift  # Leaderboard item
├── Views/
│   ├── Auth/                   # Login, SignUp
│   ├── Focus/                  # Timer, Active Session
│   ├── Leaderboard/            # Rankings
│   ├── Profile/                # User profiles
│   └── Social/                 # Feed, Search, Followers
├── ViewModels/                 # Business logic
├── Services/                   # Firebase, Camera, etc.
└── Utilities/                  # Extensions, Constants
```

## Architecture

- **MVVM Pattern**: Views observe ViewModels, which interact with Services
- **Firebase Backend**: Firestore for data, Storage for images, Auth for users
- **Real-time Updates**: Firestore listeners for live leaderboard updates
- **Camera Verification**: AVFoundation for presence verification during sessions

## Testing

1. Sign up with a test email
2. Complete a focus session
3. Check leaderboard for rank updates
4. Search and follow other users
5. View activity feed

## Future Enhancements

- Canvas LMS integration
- Spotify API for playlist embedding
- Push notifications
- Study groups/circles
- Achievement badges

## License

This project is for educational purposes at the University of Notre Dame.
