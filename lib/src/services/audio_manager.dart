import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';

/// Central Audio Manager for BGM and Sound Effects (SFX)
class AudioManager {
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

  bool isSoundEnabled = true; // Always true for now as requested
  bool isBgmEnabled = true; // Always true for now as requested

  bool _isBgmPlaying = false;
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
  Future<void> init() async {
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(0.85);

    await _pentagonHold.init();
    await _hexagonStretch.init();

    if (_sfxPool.isEmpty) {
      for (int i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(1.0);
        _sfxPool.add(player);
      }
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

  Future<void> playPentagonPop() => playPentagonBurst();

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

  Future<void> playHexagonPop() => playHexagonBurst();

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
    if (_isBgmPlaying) return;

    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('audio/$_currentBgmTrack'));
      _isBgmPlaying = true;
    } catch (e) {
      _isBgmPlaying = false;
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
    isBgmEnabled = !isBgmEnabled;
    if (isBgmEnabled) {
      await playBGM();
    } else {
      await stopBGM();
    }
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
