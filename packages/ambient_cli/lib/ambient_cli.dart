/// The `ambient` CLI: command parsing and orchestration over [ambient_core].
///
/// Commands (init, test, capture, accept) are implemented in backlog phase 3.
library;

import 'package:ambient_core/ambient_core.dart';

/// Marker for the CLI package version, kept in step with the core.
const String ambientCliVersion = ambientCoreVersion;
