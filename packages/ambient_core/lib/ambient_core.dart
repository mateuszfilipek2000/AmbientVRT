/// AmbientVRT core engine.
///
/// Houses the manifest model, comparator, baseline/ID logic, storage
/// backends, and report generation shared by every capture adapter.
library;

export 'src/baseline/id.dart';
export 'src/baseline/rename.dart';
export 'src/compare/compare.dart';
export 'src/config/adapter.dart';
export 'src/config/compare_config.dart';
export 'src/config/config.dart';
export 'src/config/errors.dart';
export 'src/config/storage_config.dart';
export 'src/manifest/brightness.dart';
export 'src/manifest/errors.dart';
export 'src/manifest/manifest.dart';
export 'src/manifest/manifest_entry.dart';
export 'src/manifest/manifest_version.dart';
export 'src/manifest/platform.dart';
export 'src/manifest/variant.dart';
export 'src/report/report.dart';
export 'src/run/run.dart';
export 'src/storage/storage.dart';

/// Marker for the core package version.
const String ambientCoreVersion = '0.1.0';
