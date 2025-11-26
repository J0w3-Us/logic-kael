import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
// Removed unused import: SplashScreen is not exported from home_screen

class GameZoneScreen extends StatefulWidget {
  final VoidCallback? onVideoEnd;
  const GameZoneScreen({super.key, this.onVideoEnd});

  @override
  State<GameZoneScreen> createState() => _GameZoneScreenState();
}

class _GameZoneScreenState extends State<GameZoneScreen> {
  double _fadeOpacity = 0.0; // Empieza transparente
  double _zoomScale = 1.0;
  bool _isZooming = false;
  bool _isTransitioning = false;
  late VideoPlayerController _controller;
  late VoidCallback _videoListener;
  Duration duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/newgameintro.mp4');
    _videoListener = () async {
      final position = _controller.value.position;
      duration = _controller.value.duration;
      if (duration.inMilliseconds > 0) {
        // Un segundo antes de terminar: zoom y oscurecer
        if (!_isZooming &&
            duration.inMilliseconds - position.inMilliseconds <= 1000) {
          setState(() {
            _isZooming = true;
            _zoomScale = 1.0;
          });
          Future.delayed(const Duration(milliseconds: 100), () {
            setState(() {
              _zoomScale = 1.2;
              _fadeOpacity = 1.0; // Oscurece
            });
          });
        }
        // Cuando termina el video
        if (position >= duration && !_isTransitioning) {
          setState(() {
            _isTransitioning = true;
          });
          await Future.delayed(const Duration(milliseconds: 400));
          await _controller.pause();
          await _controller.dispose();
          setState(() {
            _zoomScale = 1.0;
            _fadeOpacity = 1.0; // Mantiene oscuro
          });
          // Transición: abre showmap.mp4 con fade-in
          _controller = VideoPlayerController.asset(
            'assets/videos/showmap.mp4',
          );
          await _controller.initialize();
          setState(() {
            _isZooming = false;
            _isTransitioning = false;
          });
          _controller.play();
          Future.delayed(const Duration(milliseconds: 400), () {
            setState(() {
              _fadeOpacity = 0.0;
            });
          });
        }
      }
    };
    _initControllerWithListener(_controller, _videoListener);
  }

  Future<void> _initControllerWithListener(
    VideoPlayerController controller,
    VoidCallback listener,
  ) async {
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
      controller.play();
      controller.addListener(listener);
    } catch (e, st) {
      debugPrint('Error inicializando video de GameZone: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Stack(
          children: [
            _controller.value.isInitialized
                ? AnimatedScale(
                    scale: _zoomScale,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                    child: SizedBox.expand(child: VideoPlayer(_controller)),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text(
                          'Cargando video...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
            // Overlay negro para fade-out/fade-in
            AnimatedOpacity(
              opacity: _fadeOpacity,
              duration: const Duration(milliseconds: 700),
              child: Container(
                color: Colors.black,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            // No se muestra el carrusel en esta pantalla
          ],
        ),
      ),
    );
  }
}
