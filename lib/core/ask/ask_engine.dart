import 'package:flutter/services.dart';

abstract interface class AskEngine {
  Future<bool> installed();
  Future<void> download();
  Future<String> answer(String evidence);
  Future<void> cancel();
  Future<void> deleteModel();
  Stream<Map<String, dynamic>> get events;
}

class LocalQwenEngine implements AskEngine {
  static const channel = MethodChannel('org.quranteacher/ask');
  static const eventChannel = EventChannel('org.quranteacher/ask/events');
  @override
  Future<bool> installed() async =>
      await channel.invokeMethod<bool>('status') ?? false;
  @override
  Future<void> download() => channel.invokeMethod<void>('download');
  @override
  Future<String> answer(String evidence) async {
    final result = await channel.invokeMapMethod<String, dynamic>('answer', {
      'evidence': evidence,
    });
    return result!['text'] as String;
  }

  @override
  Future<void> cancel() => channel.invokeMethod<void>('cancel');
  @override
  Future<void> deleteModel() => channel.invokeMethod<void>('deleteModel');
  @override
  Stream<Map<String, dynamic>> get events => eventChannel
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map));
}
