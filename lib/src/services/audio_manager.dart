import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central Audio Manager for BGM and Sound Effects (SFX)
class AudioManager extends ChangeNotifier {
  static final AudioManager _instance = AudioManager._internal();
  static AudioManager get instance => _instance;

  AudioManager._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final List<AudioPlayer> _sfxPool = [];
  int _poolIndex = 0;
  static const int _poolSize = 5;

  /// Intro plays once; a pre-crossfaded loop clip then sustains.
  static const Duration _handoffWindow = Duration(milliseconds: 120);
  static const int _crossfadeSteps = 8;

  static const _preferencesKey = 'figureout.audio-preferences.v1';
  bool _allEnabled = true;
  bool _effectsEnabled = true;
  bool _bgmEnabled = true;
  bool _preferencesReady = false;
  bool _saving = false;
  Future<void>? _initialization;

  bool get isAllSoundEnabled => _allEnabled;
  bool get isSoundEnabled => _allEnabled && _effectsEnabled;
  bool get isBgmEnabled => _allEnabled && _bgmEnabled;
  bool get canChangePreferences => _preferencesReady && !_saving;

  bool _isBgmPlaying = false;
  bool _isBgmStarting = false;
  bool get isBgmPlaying => _isBgmPlaying;

  final _TailSustainPlayer _pentagonHold = _TailSustainPlayer(
    introAsset: 'audio/pop_pentagon_hold.mp3',
    loopAsset: 'audio/pop_pentagon_hold_loop.mp3',
  );
  final _TailSustainPlayer _hexagonStretch = _TailSustainPlayer(
    introAsset: 'audio/pop_hexagon.mp3',
    loopAsset: 'audio/pop_hexagon_loop.mp3',
  );

  /// Initialize Audio Manager and pool of SFX players
  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_preferencesKey);
    if (stored != null) {
      final data = jsonDecode(stored);
      if (data is! Map<String, dynamic> ||
          data['all'] is! bool ||
          data['effects'] is! bool ||
          data['bgm'] is! bool) {
        throw const FormatException('Invalid stored audio preferences');
      }
      _allEnabled = data['all'] as bool;
      _effectsEnabled = data['effects'] as bool;
      _bgmEnabled = data['bgm'] as bool;
    }
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(isBgmEnabled ? 0.85 : 0);

    await _pentagonHold.init();
    await _hexagonStretch.init();

    if (_sfxPool.isEmpty) {
      for (int i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(isSoundEnabled ? 1.0 : 0);
        _sfxPool.add(player);
      }
    }
    _preferencesReady = true;
    notifyListeners();
  }

  Future<void> setAllSoundEnabled(bool enabled) =>
      _savePreferences(enabled, enabled, enabled);

  Future<void> setSoundEnabled(bool enabled) async {
    if (!_allEnabled) return;
    await _savePreferences(_allEnabled, enabled, _bgmEnabled);
  }

  Future<void> setBgmEnabled(bool enabled) async {
    if (!_allEnabled) return;
    await _savePreferences(_allEnabled, _effectsEnabled, enabled);
  }

  Future<void> _savePreferences(bool all, bool effects, bool bgm) async {
    if (!canChangePreferences) return;
    _saving = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(
        _preferencesKey,
        jsonEncode({'all': all, 'effects': effects, 'bgm': bgm}),
      );
      if (!saved) throw StateError('Audio preferences were not saved');
      _allEnabled = all;
      _effectsEnabled = effects;
      _bgmEnabled = bgm;
      // Mute the player too: a web autoplay request may still be awaiting input.
      await _bgmPlayer.setVolume(isBgmEnabled ? 0.85 : 0);
      for (final player in _sfxPool) {
        await player.setVolume(isSoundEnabled ? 1.0 : 0);
        if (!isSoundEnabled) await player.stop();
      }
      if (!isSoundEnabled) await stopLoopingSfx();
      if (!isBgmEnabled) {
        await stopBGM();
      } else {
        unawaited(playBGM());
      }
    } catch (error, stack) {
      debugPrint('[Audio] Preference update failed: $error');
      debugPrintStack(stackTrace: stack);
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Play shape explosion / pop sound effect with specific audio asset
  Future<void> playPopSound([String soundFile = 'pop.mp3']) async {
    if (!isSoundEnabled) return;
    try {
      if (_sfxPool.isEmpty) {
        await init();
      }
      final player = _sfxPool[_poolIndex];
      _poolIndex = (_poolIndex + 1) % _poolSize;
      await player.stop();
      await player.play(AssetSource('audio/$soundFile'));
    } catch (e) {
      // Audio playback error fallback handling
    }
  }

  DateTime? _lastRectanglePopTime;
  String _currentBgmTrack = 'bgm_tiny_garden.mp3';

  Future<void> playCirclePop() => playPopSound('pop_circle.mp3');

  Future<void> playRectanglePop() async {
    final now = DateTime.now();
    if (_lastRectanglePopTime != null &&
        now.difference(_lastRectanglePopTime!).inMilliseconds < 40) {
      return; // Ignore sub-40ms duplicate calls from same frame
    }
    _lastRectanglePopTime = now;
    await playPopSound('sword-slicing.mp3');
  }

  Future<void> playTrianglePop() => playPopSound('pop_triangle.mp3');

  /// Play the hold clip once, then sustain on a soft loop tail.
  Future<void> startPentagonHold() async {
    if (!isSoundEnabled) return;
    await _pentagonHold.start();
  }

  Future<void> stopPentagonHold() => _pentagonHold.stop();

  Future<void> playPentagonBurst() async {
    await stopPentagonHold();
    await playPopSound('pop.mp3');
  }


  /// Play the stretch clip once, then sustain on a soft loop tail.
  Future<void> startHexagonStretch() async {
    if (!isSoundEnabled) return;
    await _hexagonStretch.start();
  }

  Future<void> stopHexagonStretch() => _hexagonStretch.stop();

  Future<void> playHexagonBurst() async {
    await stopHexagonStretch();
    await playPopSound('pop.mp3');
  }


  /// Stop looping SFX (pause / overlay / hard reset).
  Future<void> stopLoopingSfx() async {
    await stopPentagonHold();
    await stopHexagonStretch();
  }

  /// Switch background music sample track:
  /// 1: Arcade 8-Bit
  /// 2: Cozy Synthwave
  /// 3: Lo-Fi Chill
  /// 4: Pixel Orgel
  /// 5: Tiny Garden (default)
  Future<void> setBgmTrack(int trackIndex) async {
    switch (trackIndex) {
      case 2:
        _currentBgmTrack = 'bgm_cozysynth.mp3';
        break;
      case 3:
        _currentBgmTrack = 'bgm_lofi.mp3';
        break;
      case 4:
        _currentBgmTrack = 'bgm_pixelorgel.mp3';
        break;
      case 1:
        _currentBgmTrack = 'bgm_arcade8bit.mp3';
        break;
      case 5:
      default:
        _currentBgmTrack = 'bgm_tiny_garden.mp3';
        break;
    }
    _isBgmPlaying = false;
    await playBGM();
  }

  /// Play background music (BGM)
  Future<void> playBGM() async {
    if (!isBgmEnabled) return;
    if (_isBgmPlaying || _isBgmStarting) return;

    _isBgmStarting = true;
    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('audio/$_currentBgmTrack'));
      if (!isBgmEnabled) {
        await stopBGM();
        return;
      }
      _isBgmPlaying = true;
    } catch (e) {
      _isBgmPlaying = false;
      debugPrint('[Audio] BGM playback failed: $e');
    } finally {
      _isBgmStarting = false;
    }
  }

  /// Pause background music
  Future<void> pauseBGM() async {
    try {
      await _bgmPlayer.pause();
      _isBgmPlaying = false;
    } catch (_) {}
  }

  /// Resume background music
  Future<void> resumeBGM() async {
    if (!isBgmEnabled) return;
    try {
      await _bgmPlayer.resume();
      _isBgmPlaying = true;
    } catch (_) {}
  }

  /// Toggle BGM ON/OFF
  Future<void> toggleBGM() async {
    await setBgmEnabled(!isBgmEnabled);
  }

  /// Stop background music
  Future<void> stopBGM() async {
    try {
      await _bgmPlayer.stop();
      _isBgmPlaying = false;
    } catch (_) {}
  }
}

/// Plays [introAsset] fully once, then crossfades into [loopAsset] which
/// keeps looping. The loop files are pre-processed with acrossfade so hard
/// seek-clicks are avoided.
class _TailSustainPlayer {
  _TailSustainPlayer({
    required this.introAsset,
    required this.loopAsset,
  });

  final String introAsset;
  final String loopAsset;

  final AudioPlayer _intro = AudioPlayer();
  final AudioPlayer _loop = AudioPlayer();

  int _token = 0;
  bool _playing = false;
  bool _handedOff = false;
  bool _handingOff = false;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<void>? _completeSub;
  Timer? _fadeTimer;

  bool get isPlaying => _playing;

  Future<void> init() async {
    await _intro.setReleaseMode(ReleaseMode.stop);
    await _intro.setVolume(1.0);
    await _loop.setReleaseMode(ReleaseMode.loop);
    await _loop.setVolume(1.0);
  }

  Future<void> start() async {
    if (_playing) return;
    final token = ++_token;
    await _detach();
    _handedOff = false;
    _handingOff = false;
    try {
      await _intro.stop();
      await _loop.stop();
      if (token != _token) return;

      await _intro.setReleaseMode(ReleaseMode.stop);
      await _intro.setVolume(1.0);
      await _loop.setReleaseMode(ReleaseMode.loop);
      await _loop.setVolume(0.0);

      _posSub = _intro.onPositionChanged.listen((pos) async {
        if (token != _token || !_playing || _handedOff || _handingOff) return;
        final dur = await _intro.getDuration();
        if (dur == null || dur <= Duration.zero) return;
        if (pos >= dur - AudioManager._handoffWindow) {
          await _handoffToLoop(token);
        }
      });

      _completeSub = _intro.onPlayerComplete.listen((_) async {
        if (token != _token || !_playing || _handedOff) return;
        await _handoffToLoop(token, force: true);
      });

      await _intro.play(AssetSource(introAsset));
      if (token != _token) {
        await _intro.stop();
        return;
      }
      _playing = true;
    } catch (_) {
      if (token == _token) _playing = false;
    }
  }

  Future<void> stop() async {
    _token++;
    _playing = false;
    _handedOff = false;
    _handingOff = false;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    await _detach();
    try {
      await _intro.stop();
      await _loop.stop();
      await _intro.setVolume(1.0);
      await _loop.setVolume(1.0);
    } catch (_) {}
  }

  Future<void> _handoffToLoop(int token, {bool force = false}) async {
    if (_handingOff || _handedOff) return;
    if (token != _token || !_playing) return;
    _handingOff = true;
    try {
      await _loop.stop();
      if (token != _token || !_playing) return;
      await _loop.setReleaseMode(ReleaseMode.loop);
      await _loop.setVolume(force ? 1.0 : 0.0);
      await _loop.play(AssetSource(loopAsset));
      if (token != _token || !_playing) {
        await _loop.stop();
        return;
      }

      if (force) {
        await _intro.stop();
        await _loop.setVolume(1.0);
        _handedOff = true;
        return;
      }

      // Equal-ish linear crossfade over the handoff window.
      final stepMs = math.max(
        16,
        AudioManager._handoffWindow.inMilliseconds ~/ AudioManager._crossfadeSteps,
      );
      var step = 0;
      final completer = Completer<void>();
      _fadeTimer?.cancel();
      _fadeTimer = Timer.periodic(Duration(milliseconds: stepMs), (timer) async {
        if (token != _token || !_playing) {
          timer.cancel();
          if (!completer.isCompleted) completer.complete();
          return;
        }
        step++;
        final t = (step / AudioManager._crossfadeSteps).clamp(0.0, 1.0);
        try {
          await _intro.setVolume(1.0 - t);
          await _loop.setVolume(t);
        } catch (_) {}
        if (step >= AudioManager._crossfadeSteps) {
          timer.cancel();
          try {
            await _intro.stop();
            await _loop.setVolume(1.0);
          } catch (_) {}
          _handedOff = true;
          if (!completer.isCompleted) completer.complete();
        }
      });
      await completer.future;
    } catch (_) {
    } finally {
      _handingOff = false;
    }
  }

  Future<void> _detach() async {
    await _posSub?.cancel();
    await _completeSub?.cancel();
    _posSub = null;
    _completeSub = null;
  }
}
