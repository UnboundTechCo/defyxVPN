import 'dart:io';
import 'package:defyx_vpn/core/data/local/remote/api/flowline_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class FileListener {
  ProviderContainer? _container;

  void _startListening(void Function(String dfxPath) onDfxFile) {
    ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) async {
        if (files.isEmpty) return;
        final file = files.first;
        if (file.path.endsWith('.dfx')) {
          final content = await _readFileAsString(file.path);
          onDfxFile(content);
        }
      },
      onError: (err) {
        debugPrint('Error receiving shared media: $err');
      },
    );

    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> files) async {
          if (files.isEmpty) return;
          final file = files.first;
          if (file.path.endsWith('.dfx')) {
            final content = await _readFileAsString(file.path);
            onDfxFile(content);
          }
        })
        .catchError((err) {
          debugPrint('Error getting initial shared media: $err');
        });
  }

  Future<String> _readFileAsString(String path) async {
    final file = File(path);
    return await file.readAsString();
  }

  Future<void> _handleFile(String content) async {
    _container ??= ProviderContainer();
    await _container
        ?.read(flowlineServiceProvider)
        .saveFlowline(offlineMode: true, flowLine: content);
  }

  void init(ProviderContainer container) {
    _container = container;
    _startListening(_handleFile);
  }
}
