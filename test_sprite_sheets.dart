import 'package:flame/flame.dart';
import 'dart:convert';

void main() async {
  // Test sprite sheet paths
  final testPaths = [
    'images/sprite_sheets/MyCharacter_idle.json',
    'images/sprite_sheets/MyCharacter_walking.json',
    'images/sprite_sheets/blossom_idle.json',
    'images/sprite_sheets/blossom_walking.json',
  ];

  print('Testing sprite sheet paths...');

  for (final path in testPaths) {
    try {
      print('Testing path: $path');
      final jsonStr = await Flame.assets.readFile(path);
      final data = json.decode(jsonStr);
      final imageName = data['meta']['image'];
      final frames = data['frames'];

      print('✅ Success: $path');
      print('   Image: $imageName');
      print('   Frames: ${frames.length}');

      // Try to load the image
      try {
        final image = await Flame.images.load(imageName);
        print('   Image loaded: ${image.width}x${image.height}');
      } catch (e) {
        print('   ❌ Image load failed: $e');
      }
    } catch (e) {
      print('❌ Failed: $path - $e');
    }
    print('');
  }
}
