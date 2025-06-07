import 'package:flutter/material.dart';

class ProfilePictureSelector extends StatefulWidget {
  final String currentImage;
  final Function(String) onImageSelected;

  const ProfilePictureSelector({
    super.key,
    required this.currentImage,
    required this.onImageSelected,
  });

  @override
  State<ProfilePictureSelector> createState() => _ProfilePictureSelectorState();
}

class _ProfilePictureSelectorState extends State<ProfilePictureSelector> {
  // List of available role images (must match the files in the assets folder)
  final List<String> availablePictures = [
    'normal_man.png',
    'normal_woman.png',
    'bad_man.png',
    'attractive_woman.png',
    'revolvers_crossing.png',
    'bad_ninja.png',
    'graggussy_happy.png',
    'graggussy_normal.png',
    'happy_man.png',
    'old_man.png',
    'cool_bad_man.png',
    'plague_doctor.png',
    'tf_gambler.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: const Color(0xFF8B4513), // Saddle brown
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFD2691E), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFD2691E), // Chocolate
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SELECT PROFILE PICTURE',
                    style: TextStyle(
                      fontFamily: 'Rye',
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // Picture grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: availablePictures.length,
                  itemBuilder: (context, index) {
                    final image = availablePictures[index];
                    final isSelected = widget.currentImage == image;
                    
                    return GestureDetector(
                      onTap: () {
                        widget.onImageSelected(image);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? Colors.yellow : Colors.brown,
                            width: isSelected ? 3 : 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/profilePictures/$image',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
