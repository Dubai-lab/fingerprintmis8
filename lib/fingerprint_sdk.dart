import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class FingerprintSdk {
  static const MethodChannel _channel = MethodChannel('com.example.fingerprintmis8/fingerprint_sdk');

  final StreamController<String> _statusController = StreamController<String>.broadcast();
  final StreamController<Uint8List> _imageController = StreamController<Uint8List>.broadcast();
  final StreamController<Uint8List> _templateController = StreamController<Uint8List>.broadcast();

  FingerprintSdk() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Stream<String> get statusStream => _statusController.stream;
  Stream<Uint8List> get imageStream => _imageController.stream;
  Stream<Uint8List> get templateStream => _templateController.stream;

  Future<void> openDevice() async {
    final bool result = await _channel.invokeMethod('openDevice');
    if (!result) {
      throw Exception('Failed to open fingerprint device');
    }
  }

  Future<void> closeDevice() async {
    await _channel.invokeMethod('closeDevice');
  }

  Future<void> enrollTemplate() async {
    await _channel.invokeMethod('enrollTemplate');
  }

  Future<void> generateTemplate() async {
    await _channel.invokeMethod('generateTemplate');
  }

  Future<void> pauseUnregister() async {
    await _channel.invokeMethod('pauseUnregister');
  }

  Future<void> resumeRegister() async {
    await _channel.invokeMethod('resumeRegister');
  }

  Future<int> matchTemplates(Uint8List template1, Uint8List template2) async {
    final int score = await _channel.invokeMethod('matchTemplates', {
      'template1': template1,
      'template2': template2,
    });
    return score;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onStatus':
        final String status = call.arguments as String;
        _statusController.add(status);
        break;
      case 'onImage':
        final Uint8List imageData = call.arguments as Uint8List;
        _imageController.add(imageData);
        break;
      case 'onTemplate':
        final Uint8List templateData = call.arguments as Uint8List;
        _templateController.add(templateData);
        break;
      default:
        throw MissingPluginException('Not implemented: ${call.method}');
    }
  }

  void dispose() {
    _statusController.close();
    _imageController.close();
    _templateController.close();
  }
}
