import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class DeviceFeedbackService {
  const DeviceFeedbackService();

  Future<void> scanSuccess() async {
    await _vibrate(pattern: [0, 45]);
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> scanWarning() async {
    await _vibrate(pattern: [0, 35, 45, 35]);
    await SystemSound.play(SystemSoundType.alert);
  }

  Future<void> actionSuccess() async {
    await _vibrate(pattern: [0, 30]);
    await HapticFeedback.lightImpact();
  }

  Future<void> _vibrate({required List<int> pattern}) async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        await Vibration.vibrate(pattern: pattern);
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {
      await HapticFeedback.mediumImpact();
    }
  }
}
