import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Feedback audio + haptique pour les événements de scan et d'action.
///
/// Un seul [AudioPlayer] partagé (singleton) évite la latence
/// liée à l'initialisation répétée du moteur audio.
class DeviceFeedbackService {
  const DeviceFeedbackService();

  // Lecteur partagé entre toutes les instances (const constructor).
  static final AudioPlayer _player = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  // ── Scan OK — bip scanner caisse ──────────────────────────────────────
  Future<void> scanSuccess() async {
    // Son + vibration en parallèle (non-bloquant pour le son).
    _playBeep();
    await _vibrate(pattern: [0, 45]);
  }

  // ── Scan KO / avertissement ───────────────────────────────────────────
  Future<void> scanWarning() async {
    await _vibrate(pattern: [0, 35, 45, 35]);
    await SystemSound.play(SystemSoundType.alert);
  }

  // ── Action générale (ex : ouvrir panier) ──────────────────────────────
  Future<void> actionSuccess() async {
    await _vibrate(pattern: [0, 30]);
    await HapticFeedback.lightImpact();
  }

  // ── Privé ─────────────────────────────────────────────────────────────

  // stop() avant play() : si un scan rapide arrive avant la fin du bip
  // précédent, on repart à zéro — pas de queue de sons qui s'accumulent.
  static Future<void> _playBeep() async {
    try {
      await _player.stop();
      await _player.play(
        AssetSource('sounds/scan_beep.wav'),
        volume: 1.0,
      );
    } catch (_) {
      // Audio indisponible (ex. : mode silencieux matériel) — silencieux.
    }
  }

  Future<void> _vibrate({required List<int> pattern}) async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(pattern: pattern);
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {
      await HapticFeedback.mediumImpact();
    }
  }
}
