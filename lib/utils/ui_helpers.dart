import 'package:flutter/material.dart';

/// Shows a custom dialog that matches the game's western theme.
Future<T?> showWesternDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget>? actions,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.brown[100],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Rye',
                fontSize: 24,
                color: Colors.brown,
              ),
            ),
            const SizedBox(height: 16),
            content,
            const SizedBox(height: 16),
            if (actions != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
          ],
        ),
      ),
    ),
  );
}

/// Shows a custom snackbar that matches the game's western theme.
void showWesternSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Rye',
          fontSize: 16,
        ),
      ),
      backgroundColor: const Color(0xFF4E2C0B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
