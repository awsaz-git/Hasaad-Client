import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';

class LoadingOverlay extends StatefulWidget {
  final String? message;
  const LoadingOverlay({super.key, this.message});

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> with TickerProviderStateMixin {
  int _messageIndex = 0;
  Timer? _timer;
  List<String> _messages = [];
  late AnimationController _pulseController;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initMessages();
  }

  void _initMessages() {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    final newMessages = [
      widget.message ?? l10n.translate('loading_analyzing'),
      l10n.translate('loading_processing'),
      l10n.translate('loading_weather'),
      l10n.translate('loading_history'),
      l10n.translate('loading_market'),
      l10n.translate('loading_predicting'),
      l10n.translate('loading_preparing'),
      l10n.translate('loading_optimizing'),
      l10n.translate('loading_almost_there'),
    ];

    if (_messages.isEmpty) {
      setState(() {
        _messages = newMessages;
      });
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          if (_messageIndex < _messages.length - 1) {
            _messageIndex++;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = AppTheme.primary;
    const aiAccent = Color(0xFF00C897);
    final l10n = AppLocalizations.of(context)!;
    
    return Material(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: aiAccent.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.center,
                children: [
                  // Spinning outer ring
                  RotationTransition(
                    turns: _rotateController,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: aiAccent.withOpacity(0.1),
                          width: 8,
                        ),
                      ),
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(aiAccent.withOpacity(0.5)),
                      ),
                    ),
                  ),
                  // Pulsing inner core
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              primaryGreen,
                              aiAccent.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: aiAccent.withOpacity(0.4),
                              blurRadius: 10 + (10 * _pulseController.value),
                              spreadRadius: 2 + (5 * _pulseController.value),
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 40,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 48),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [primaryGreen, aiAccent],
                ).createShader(bounds),
                child: Text(
                  l10n.translate('ai_engine'),
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 70,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      _messages.isNotEmpty ? _messages[_messageIndex] : "...",
                      key: ValueKey(_messageIndex),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
