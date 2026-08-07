import 'dart:async';
import 'package:flutter/material.dart';

class ToastHelper {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void showSuccess(BuildContext context, String message) {
    show(context, message, isError: false);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message, isError: false);
  }

  static void showError(BuildContext context, String message) {
    show(context, message, isError: true);
  }

  static void show(BuildContext context, String message, {bool isError = false}) {
    // Dismiss any existing toast first
    dismiss();

    final overlay = Overlay.of(context);
    
    _currentEntry = OverlayEntry(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        return Positioned(
          top: 24,
          right: isMobile ? 16 : 24,
          left: isMobile ? 16 : null,
          child: Material(
            color: Colors.transparent,
            child: _AnimatedToast(
              message: message,
              isError: isError,
              screenWidth: screenWidth,
              isMobile: isMobile,
            ),
          ),
        );
      },
    );

    overlay.insert(_currentEntry!);

    _timer = Timer(const Duration(seconds: 3), () {
      dismiss();
    });
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (_currentEntry != null) {
      try {
        _currentEntry!.remove();
      } catch (_) {}
      _currentEntry = null;
    }
  }
}

class _AnimatedToast extends StatefulWidget {
  final String message;
  final bool isError;
  final double screenWidth;
  final bool isMobile;

  const _AnimatedToast({
    required this.message,
    required this.isError,
    required this.screenWidth,
    required this.isMobile,
  });

  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: widget.isMobile ? widget.screenWidth - 32 : 400,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // Dark Slate / High Contrast
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.isError 
                      ? const Color(0xFFEF4444).withOpacity(0.15) 
                      : const Color(0xFF10B981).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isError ? Icons.close_rounded : Icons.check_rounded,
                  color: widget.isError ? const Color(0xFFF87171) : const Color(0xFF34D399),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  ToastHelper.dismiss();
                },
                icon: const Icon(Icons.close_rounded),
                iconSize: 18,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                splashRadius: 24,
                color: const Color(0xFF94A3B8), // Slate 400
              ),
            ],
          ),
        ),
      ),
    );
  }
}
