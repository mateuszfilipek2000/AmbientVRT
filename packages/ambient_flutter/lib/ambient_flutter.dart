/// AmbientVRT Flutter capture adapter.
///
/// Discovers `@Preview`/`MultiPreview` widgets, renders them to PNGs via a
/// generated golden harness, and emits the [ambient_core] manifest format.
/// Implemented across backlog phase 4.
library;

import 'package:ambient_core/ambient_core.dart';

/// Marker for the Flutter adapter version, kept in step with the core.
const String ambientFlutterVersion = ambientCoreVersion;
