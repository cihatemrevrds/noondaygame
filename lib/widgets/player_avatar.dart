import 'package:flutter/material.dart';

class PlayerAvatar extends StatelessWidget {
  final String name;
  final bool isLeader;
  final bool isDead;

  const PlayerAvatar({
    super.key, 
    required this.name, 
    this.isLeader = false,
    this.isDead = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDead ? Colors.black54 : Colors.white,
                  border: Border.all(
                    color: isLeader ? Colors.yellow[700]! : Colors.brown[700]!, 
                    width: isLeader ? 3 : 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'P',
                    style: TextStyle(
                      color: isDead ? Colors.white70 : Colors.brown[800],
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      decoration: isDead ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ),
              if (isLeader)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.yellow[700],
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              if (isDead)
                Positioned.fill(
                  child: Center(
                    child: Icon(
                      Icons.close,
                      color: Colors.red[700],
                      size: 40,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontFamily: 'Rye',
              fontSize: 14,
              color: isDead ? Colors.grey : Colors.white,
              fontWeight: FontWeight.bold,
              decoration: isDead ? TextDecoration.lineThrough : null,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          if (isLeader) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.yellow[700],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'HOST',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
