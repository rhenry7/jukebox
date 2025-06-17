

Notes for organizing code: 
/lib
├── models/              👈 Dart classes for your data
│   ├── user_profile.dart
│   ├── post.dart
│   ├── follow_info.dart
│   └── ... 
├── services/            👈 Firestore access + network logic
│   ├── user_service.dart
│   ├── post_service.dart
│   └── follow_service.dart
├── ui/
│   ├── screens/
│   ├── widgets/
│   └── ...
