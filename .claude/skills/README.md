# Project skills

Claude Code loads these automatically for this project.

The QA skills below are copied unchanged from the Flutter team's official
repo, https://github.com/flutter/skills (commit b7d5a0be4195, BSD-3-Clause,
see LICENSE-flutter-skills):

- `dart-run-static-analysis` — `dart analyze`, then `dart fix`
- `dart-collect-coverage` — test coverage report
- `flutter-fix-layout-issues` — overflow / unbounded-constraint errors
- `flutter-add-widget-test` — screen-level tests with `WidgetTester`
- `flutter-add-integration-test` — end-to-end tests with `integration_test`

They're instructions only (no scripts). To update one, copy its `SKILL.md`
from the repo again. Notes for this project: `flutter test --coverage`
already writes `coverage/lcov.info` (no extra package needed), and screen
tests should stand in fake data with Riverpod overrides (see
`test/helpers/`), not a real Firebase.
