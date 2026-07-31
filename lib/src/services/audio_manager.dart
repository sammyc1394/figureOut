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

  bool isSoundEnabled = true; // Always true for now as requested
  bool isBgmEnabled = true;   // Always true for now as requested

  bool _isBgmPlaying = false;
  bool get isBgmPlaying => _isBgmPlaying;

  /// Initialize Audio Manager and pool of SFX players
  Future<void> init() async {
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(0.85);

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
  String _currentBgmTrack = 'bgm_cute.mp3';

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
  Future<void> playPentagonHold() => playPopSound('pop_pentagon_hold.mp3');
  Future<void> playPentagonBurst() => playPopSound('pop_pentagon_burst.mp3');
  Future<void> playPentagonPop() => playPentagonBurst();
  Future<void> playHexagonPop() => playPopSound('pop_hexagon.mp3');

  /// Switch background music sample track:
  /// 1: 8비트 오락실 레트로 BGM (Arcade 8-Bit)
  /// 2: 코지 레트로 신스웨이브 (Cozy Synthwave)
  /// 3: 따뜻하고 잔잔한 로파이 (Lo-Fi Chill)
  /// 4: 아늑한 픽셀 오르골 (Pixel Orgel)
  /// 5: 마림바 팝 BGM (Cute Marimba)
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
        _currentBgmTrack = 'bgm_cute.mp3';
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
