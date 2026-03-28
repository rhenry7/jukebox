/// Environment values are supplied at build time with --dart-define.
///
/// This remains a no-op so startup code can keep awaiting it without needing
/// platform-specific branching.
Future<void> loadEnvVariables() async {}
