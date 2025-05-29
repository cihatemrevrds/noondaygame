import 'package:flutter/material.dart';

class RoleCard extends StatelessWidget {
  final String name;
  final String imageName;
  final int count;
  final String description;  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onTap;

  const RoleCard({
    super.key,
    required this.name,
    required this.imageName,
    required this.count,
    required this.description,    this.onIncrement,
    this.onDecrement,
    this.onTap,
  });  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF4E2C0B),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Role image placeholder (in a real app, you would use an actual image)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.brown[700]!, width: 2),
            ),
            child: Center(
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Colors.brown[800],
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Role name
          Text(
            name,
            style: const TextStyle(
              fontFamily: 'Rye',
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Role counter
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [              InkWell(
                onTap: onDecrement,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.brown[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.remove, color: Colors.white, size: 20),
                ),
              ),
              Container(
                width: 36,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),              InkWell(
                onTap: onIncrement,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.brown[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
