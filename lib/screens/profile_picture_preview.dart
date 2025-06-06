import 'package:flutter/material.dart';

class ProfilePicturePreview extends StatelessWidget {
  const ProfilePicturePreview({super.key});

  // List of available role images (must match the files in the assets folder)
  final List<String> availablePictures = const [
    'sheriff.jpg',
    'peeper.jpg',
    'jester.jpg',
    'gunslinger.jpg',
    'gunman.jpg',
    'escort.jpg',
    'doctor.jpg',
    'chieftain.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E2C0B),
        title: const Text(
          'AVAILABLE PROFILE PICTURES',
          style: TextStyle(
            fontFamily: 'Rye',
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/backgrounds/saloon_bg.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: availablePictures.length,
          itemBuilder: (context, index) {
            final image = availablePictures[index];
            
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/roles/$image',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Text(
                    image.split('.').first,
                    style: const TextStyle(
                      fontFamily: 'Rye',
                      fontSize: 16,
                      color: Colors.brown,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
