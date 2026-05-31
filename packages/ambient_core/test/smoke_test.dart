import 'package:ambient_core/ambient_core.dart';
import 'package:test/test.dart';

void main() {
  // A trivial smoke test so the CI test job has something real to run.
  // It also backs the "break a test → workflow goes red" CI check.
  // Replace/expand as the core engine lands (backlog phases 1–2).
  test('ambientCoreVersion is exposed', () {
    expect(ambientCoreVersion, '0.1.0');
  });
}
