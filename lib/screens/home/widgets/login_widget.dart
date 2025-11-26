import 'package:flutter/material.dart';
import 'dart:ui';
// Removed import of HomeScreen; navigation will return to the first route instead
import 'package:video_player/video_player.dart'; // Importa el widget VideoPlayer
import 'package:kaelenlegacy/widgets/custom_input_field.dart';
import 'package:kaelenlegacy/constants/assets.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(Assets.videoIntro);
    _initLoginVideo();
  }

  Future<void> _initLoginVideo() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _controller.setLooping(true);
        _controller.play();
      });
    } catch (e, st) {
      debugPrint('Error inicializando Login video: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _isInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          if (_isInitialized)
            SizedBox.expand(child: VideoPlayer(_controller))
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Cargando...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          // Botón "X" en la esquina superior izquierda
          Positioned(
            top: 24,
            left: 24,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              tooltip: 'Cerrar',
            ),
          ),
          Align(
            alignment: Alignment(-0.7, 0.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: MediaQuery.of(context).size.width * 0.37,
              height: MediaQuery.of(context).size.height,
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(0, 0, 0, 0.7),
                      borderRadius: BorderRadius.zero,
                    ),
                    padding: const EdgeInsets.all(32),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                        top: 32,
                        left: 32,
                        right: 32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Iniciar Sesión',
                            style: const TextStyle(
                              fontFamily: 'Cinzel',
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          CustomInputField(
                            hintText: 'Usuario',
                            obscureText: false,
                          ),
                          const SizedBox(height: 16),
                          CustomInputField(
                            hintText: 'Contraseña',
                            obscureText: true,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Cinzel',
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            onPressed: () {
                              // Acción de login
                            },
                            child: const Text(
                              'Entrar',
                              style: TextStyle(
                                fontFamily: 'Cinzel',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
