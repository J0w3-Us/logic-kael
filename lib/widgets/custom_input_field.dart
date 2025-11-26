import 'package:flutter/material.dart';

class CustomInputField extends StatefulWidget {
  final String hintText;
  final bool obscureText;
  const CustomInputField({
    super.key,
    required this.hintText,
    required this.obscureText,
  });

  @override
  State<CustomInputField> createState() => _CustomInputFieldState();
}

class _CustomInputFieldState extends State<CustomInputField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showGold = _controller.text.isNotEmpty;
    return TextField(
      controller: _controller,
      obscureText: widget.obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: showGold ? const Color(0xFFFFD700) : Colors.white24,
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
        ),
      ),
    );
  }
}
