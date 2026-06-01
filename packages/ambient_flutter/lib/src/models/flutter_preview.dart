import 'package:ambient_core/ambient_core.dart';

class FlutterPreviewInfo {
  const FlutterPreviewInfo({
    required this.id,
    required this.sourcePath,
    required this.targetName,
    required this.group,
    required this.name,
    required this.imagePath,
    required this.dpr,
    this.width,
    this.height,
    this.textScaleFactor,
    this.variant,
    this.wrapperName,
    this.themeName,
    this.localizationsName,
  });

  final String id;
  final String sourcePath;
  final String targetName;
  final String group;
  final String name;
  final String imagePath;
  final double dpr;
  final double? width;
  final double? height;
  final double? textScaleFactor;
  final Variant? variant;
  final String? wrapperName;
  final String? themeName;
  final String? localizationsName;

  factory FlutterPreviewInfo.fromJson(Map<String, Object?> json) {
    final variantJson = json['variant'] as Map<String, Object?>?;
    return FlutterPreviewInfo(
      id: json['id']! as String,
      sourcePath: json['sourcePath']! as String,
      targetName: json['targetName']! as String,
      group: json['group']! as String,
      name: json['name']! as String,
      imagePath: json['imagePath']! as String,
      dpr: (json['dpr']! as num).toDouble(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      textScaleFactor: (json['textScaleFactor'] as num?)?.toDouble(),
      variant: variantJson == null
          ? null
          : Variant(
              theme: variantJson['theme'] as String?,
              brightness: switch (variantJson['brightness']) {
                'light' => Brightness.light,
                'dark' => Brightness.dark,
                _ => null,
              },
              locale: variantJson['locale'] as String?,
              sizeName: variantJson['sizeName'] as String?,
            ),
      wrapperName: json['wrapperName'] as String?,
      themeName: json['themeName'] as String?,
      localizationsName: json['localizationsName'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'sourcePath': sourcePath,
      'targetName': targetName,
      'group': group,
      'name': name,
      'imagePath': imagePath,
      'dpr': dpr,
      'width': width,
      'height': height,
      'textScaleFactor': textScaleFactor,
      'variant': variant?.toJson(),
      'wrapperName': wrapperName,
      'themeName': themeName,
      'localizationsName': localizationsName,
    };
  }

  ManifestEntry toManifestEntry({
    required int width,
    required int height,
    required String contentHash,
    required String envFingerprint,
  }) {
    return ManifestEntry(
      id: id,
      platform: Platform.flutter,
      imagePath: imagePath,
      width: width,
      height: height,
      dpr: dpr,
      contentHash: contentHash,
      envFingerprint: envFingerprint,
      variant: variant,
    );
  }
}
