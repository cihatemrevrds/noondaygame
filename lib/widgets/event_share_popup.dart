import 'package:flutter/material.dart';
import 'dart:async';
import '../config/message_config.dart';

class EventSharePopup extends StatefulWidget {
  final String eventDescription;
  final String playerName;
  final String? playerRole;
  final bool isDeath;
  final VoidCallback onComplete;
  final List<String> events; // Add events list for determining type

  const EventSharePopup({
    super.key,
    required this.eventDescription,
    required this.playerName,
    this.playerRole,
    this.isDeath = false,
    required this.onComplete,
    this.events = const [], // Default empty list
  });

  @override
  State<EventSharePopup> createState() => _EventSharePopupState();
}

class _EventSharePopupState extends State<EventSharePopup>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoCloseTimer;
  int _currentEventIndex = 0; // Track the current event index

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Create animations
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // Start animations
    _startAnimations();

    // Auto-close after 5 seconds
    _autoCloseTimer = Timer(const Duration(seconds: 10), () {
      _closePopup();
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    _fadeController.forward();
    _scaleController.forward();
  }

  void _closePopup() {
    _autoCloseTimer?.cancel();
    widget.onComplete();
  }

  void _nextEvent() {
    setState(() {
      if (_currentEventIndex < widget.events.length - 1) {
        _currentEventIndex++;
      } else {
        _closePopup(); // Close popup if it's the last event
      }
    });
  }

  void _previousEvent() {
    setState(() {
      if (_currentEventIndex > 0) {
        _currentEventIndex--;
      }
    });
  }

  Color _getEventColor() {
    if (widget.isDeath) {
      return const Color(0xFFF44336); // Red for death events
    }
    return const Color(0xFF2196F3); // Blue for other events
  }

  @override
  Widget build(BuildContext context) {
    final eventColor = _getEventColor();
    final currentEvent = widget.events[_currentEventIndex];

    return PopScope(
      canPop: false, // Prevent back button dismissal
      child: Material(
        color: Colors.black54,
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2B1810), Color(0xFF1A0F08)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.8),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Event Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: eventColor.withOpacity(0.2),
                            border: Border.all(color: eventColor, width: 2),
                          ),
                          child: Icon(
                            widget.isDeath ? Icons.dangerous : Icons.info,
                            color: eventColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Event Title
                        Text(
                          currentEvent, // Display the current event
                          style: const TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Event Description
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.events[_currentEventIndex], // Dynamically fetch the event description
                            style: const TextStyle(
                              fontFamily: 'Rye',
                              fontSize: 16,
                              color: Colors.white,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),                        // Navigation Buttons
                        Row(
                          mainAxisAlignment: _currentEventIndex > 0 
                              ? MainAxisAlignment.spaceBetween 
                              : MainAxisAlignment.center,
                          children: [
                            if (_currentEventIndex > 0)
                              ElevatedButton(
                                onPressed: _previousEvent,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B4513),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Previous',
                                  style: TextStyle(
                                    fontFamily: 'Rye',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ElevatedButton(
                              onPressed: _nextEvent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B4513),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _currentEventIndex < widget.events.length - 1
                                    ? 'Next'
                                    : 'Continue',
                                style: const TextStyle(
                                  fontFamily: 'Rye',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
