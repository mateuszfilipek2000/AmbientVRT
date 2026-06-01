import 'package:flutter/material.dart';

import 'src/previews.dart';

void main() {
  runApp(const PreviewExampleApp());
}

class PreviewExampleApp extends StatelessWidget {
  const PreviewExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'AmbientPreviewSans',
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Ambient Flutter previews')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: <Widget>[
              PlainMessageCard(),
              FixtureDrivenCard(),
              ProductStatusTile(),
              SizedSummaryCard(),
            ],
          ),
        ),
      ),
    );
  }
}
