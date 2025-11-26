import 'package:flutter/material.dart';

class MenuCarousel extends StatefulWidget {
  final bool vertical;
  final ValueChanged<String>? onOptionChanged;
  final int selectedIndex;
  final ValueChanged<int>? onPageChanged;

  const MenuCarousel({
    super.key,
    this.vertical = false,
    this.onOptionChanged,
    this.selectedIndex = 0,
    this.onPageChanged,
  });

  @override
  State<MenuCarousel> createState() => _MenuCarouselState();
}

class _MenuCarouselState extends State<MenuCarousel> {
  final List<String> options = ['New\nGame', 'Store', 'Settings', 'Quit'];
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _pageController = PageController(
      initialPage: _currentIndex,
      viewportFraction: widget.vertical
          ? 0.35
          : 0.5, // Ajusta para vertical y horizontal
    );
  }

  @override
  void didUpdateWidget(covariant MenuCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Elimina la animación automática al cambiar selectedIndex
    // Ahora solo se actualiza el índice interno
    if (widget.selectedIndex != _currentIndex) {
      setState(() {
        _currentIndex = widget.selectedIndex;
      });
    }
  }

  void _onTap(int index) {
    debugPrint('Tap en opción: ${options[index]}');
    widget.onOptionChanged?.call(
      options[index],
    ); // Solo aquí se activa la acción
    if (_currentIndex != index) {
      _pageController.animateToPage(
        index,
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 0.0),
      child: SizedBox(
        height: widget.vertical ? 320 : 160,
        width: widget.vertical ? null : 520,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: widget.vertical ? Axis.vertical : Axis.horizontal,
          itemCount: options.length,
          // Elimina la acción automática al cambiar página
          onPageChanged: (int index) {
            // Solo actualiza el índice interno, NO llama a onOptionChanged ni ejecuta acción
            setState(() {
              _currentIndex = index;
            });
            widget.onPageChanged?.call(
              index,
            ); // Si necesitas solo notificar el cambio visual
          },
          itemBuilder: (context, index) {
            double selected = widget.selectedIndex.toDouble();
            double distance = (selected - index).abs();
            double scale = 1 - (distance * 0.3).clamp(0.0, 0.7);
            double opacity = 1 - (distance * 0.5).clamp(0.0, 0.7);

            return Align(
              alignment: widget.vertical
                  ? (index == widget.selectedIndex
                        ? Alignment.centerRight
                        : Alignment.center)
                  : Alignment.center,
              child: GestureDetector(
                onTap: () => _onTap(index),
                child: Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: widget.vertical
                        ? Offset(
                            0,
                            index < widget.selectedIndex
                                ? -40
                                : (index > widget.selectedIndex ? 40 : 0),
                          )
                        : Offset(0, 0),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: widget.vertical
                            ? null
                            : (index == widget.selectedIndex ? 320 : 140),
                        alignment: index == widget.selectedIndex
                            ? Alignment.centerRight
                            : Alignment.centerRight,
                        padding: EdgeInsets.only(
                          right: options[index] == 'Settings' ? 5.0 : 25.0,
                          left: index == widget.selectedIndex ? 0.0 : 0.0,
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: Duration(milliseconds: 200),
                          style: TextStyle(
                            fontFamily: 'Spectral',
                            fontStyle: FontStyle.italic,
                            fontSize: index == widget.selectedIndex ? 36 : 28,
                            color: index == widget.selectedIndex
                                ? Color(0xFFFFD700)
                                : Colors.grey.shade400,
                            fontWeight: index == widget.selectedIndex
                                ? FontWeight.bold
                                : FontWeight.normal,
                            shadows: [
                              Shadow(
                                offset: Offset(2, 2),
                                blurRadius: 8,
                                color: index == widget.selectedIndex
                                    ? Color(
                                        0xFFFFD700,
                                      ).withAlpha((0.5 * 255).toInt())
                                    : Colors.black54,
                              ),
                            ],
                          ),
                          child: Text(
                            options[index],
                            maxLines: options[index] == 'New\nGame' ? 2 : 1,
                            overflow: options[index] == 'New\nGame'
                                ? TextOverflow.visible
                                : TextOverflow.visible,
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
