
Recommended folder structure: 

lib/
├── main.dart                  # App entry point
├── app/                      # Global config (themes, routing, DI, constants)
│   ├── router.dart
│   ├── app_theme.dart
│   └── constants.dart

├── models/                   # Pure data models (no Firebase logic)
│   ├── user_profile.dart
│   ├── post.dart
│   ├── follow_info.dart
│   └── comment.dart

├── services/                 # Firebase or API interaction logic
│   ├── user_service.dart
│   ├── post_service.dart
│   └── auth_service.dart

├── repositories/             # Business logic: combines services + handles flows
│   ├── feed_repository.dart
│   └── profile_repository.dart

├── ui/                       # UI layer
│   ├── screens/
│   │   ├── home/
│   │   ├── feed/
│   │   ├── profile/
│   │   └── auth/
│   ├── widgets/
│   │   ├── user_avatar.dart
│   │   ├── post_card.dart
│   │   └── ...
│   └── shared/              # Shared visual components
│       └── loading_spinner.dart

├── state/                   # State management (Riverpod, Bloc, etc.)
│   ├── user_provider.dart
│   ├── feed_provider.dart
│   └── auth_state.dart

├── utils/                   # Helper functions, extensions, formatters
│   ├── date_utils.dart
│   ├── firestore_refs.dart
│   └── extensions/
│       ├── context_ext.dart
│       └── string_ext.dart
└── firebase_options.dart    # Generated from `flutterfire configure`
