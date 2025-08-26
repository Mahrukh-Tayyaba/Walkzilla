import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'coin_service.dart';
import 'character_data_service.dart';
import 'character_animation_service.dart';

class ShopItem {
  final String id;
  final String name;
  final String description;
  final int price;
  final String imagePath;
  final String glbFilePath;
  final bool isOwned;
  final bool isWorn;

  ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imagePath,
    required this.glbFilePath,
    required this.isOwned,
    required this.isWorn,
  });

  ShopItem copyWith({
    String? id,
    String? name,
    String? description,
    int? price,
    String? imagePath,
    String? glbFilePath,
    bool? isOwned,
    bool? isWorn,
  }) {
    return ShopItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imagePath: imagePath ?? this.imagePath,
      glbFilePath: glbFilePath ?? this.glbFilePath,
      isOwned: isOwned ?? this.isOwned,
      isWorn: isWorn ?? this.isWorn,
    );
  }
}

class ShopService {
  static final ShopService _instance = ShopService._internal();
  factory ShopService() => _instance;
  ShopService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CoinService _coinService = CoinService();
  final CharacterDataService _characterDataService = CharacterDataService();
  final CharacterAnimationService _animationService =
      CharacterAnimationService();

  // Default shop items
  static const List<Map<String, dynamic>> defaultShopItems = [
    {
      'id': 'MyCharacter',
      'name': 'My Character',
      'description':
          'Your personal character with unique features and benefits.',
      'price': 0,
      'imagePath': 'assets/images/shop_items/MyCharacter.webp',
      'glbFilePath': 'assets/web/home/MyCharacter_home.glb',
    },
    {
      'id': 'blossom',
      'name': 'Blossom',
      'description': 'Beautiful blossom with premium quality and design.',
      'price': 50,
      'imagePath': 'assets/images/shop_items/blossom.webp',
      'glbFilePath': 'assets/web/home/blossom_home.glb',
    },
    {
      'id': 'sun',
      'name': 'Sun',
      'description': 'Bright sun with advanced capabilities.',
      'price': 50,
      'imagePath': 'assets/images/shop_items/sun.webp',
      'glbFilePath': 'assets/web/home/sun_home.glb',
    },
    {
      'id': 'cloud',
      'name': 'Cloud',
      'description': 'Fluffy cloud with exclusive features.',
      'price': 50,
      'imagePath': 'assets/images/shop_items/cloud.webp',
      'glbFilePath': 'assets/web/home/cloud_home.glb',
    },
    {
      'id': 'cool',
      'name': 'Cool',
      'description': 'Cool character with superior performance.',
      'price': 50,
      'imagePath': 'assets/images/shop_items/cool.webp',
      'glbFilePath': 'assets/web/home/cool_home.glb',
    },
    {
      'id': 'cow',
      'name': 'Cow',
      'description': 'Friendly cow with innovative technology.',
      'price': 50,
      'imagePath': 'assets/images/shop_items/cow.webp',
      'glbFilePath': 'assets/web/home/cow_home.glb',
    },
    {
      'id': 'monster',
      'name': 'Monster',
      'description': 'Scary monster with premium materials.',
      'price': 50,
      'imagePath': 'assets/images/shop_items/monster.webp',
      'glbFilePath': 'assets/web/home/monster_home.glb',
    },
    {
      'id': 'blueStar',
      'name': 'Blue Star',
      'description': 'Shining blue star with luxury design.',
      'price': 50,
      'imagePath': 'assets/images/shop_items/blueStar.webp',
      'glbFilePath': 'assets/web/home/blueStar_home.glb',
    },
    {
      'id': 'yellowStar',
      'name': 'Yellow Star',
      'description': 'Bright yellow star with ultimate features.',
      'price': 50,
      'imagePath': 'assets/images/shop_items/yellowStar.webp',
      'glbFilePath': 'assets/web/home/yellowstar_home.glb',
    },
  ];

  /// Initialize user's shop data (called when user first registers)
  Future<void> initializeUserShopData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // Create new user document with default shop data
        await _firestore.collection('users').doc(user.uid).set({
          'owned_items': ['MyCharacter'], // Default item
          'currentCharacter': 'MyCharacter', // Default worn item
          'homeGlbPath':
              _characterDataService.getHomeGlbPathForCharacter('MyCharacter'),
          'spriteSheets':
              _characterDataService.getSpriteSheetsForCharacter('MyCharacter'),
          'coins': 100, // Starting coins
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ Initialized shop data for new user: ${user.uid}');
      } else {
        // Check if user has shop data, if not initialize it
        final userData = userDoc.data()!;
        if (!userData.containsKey('owned_items')) {
          await _firestore.collection('users').doc(user.uid).update({
            'owned_items': ['MyCharacter'], // Default item
            'currentCharacter': 'MyCharacter', // Default worn item
            'homeGlbPath':
                _characterDataService.getHomeGlbPathForCharacter('MyCharacter'),
            'spriteSheets': _characterDataService
                .getSpriteSheetsForCharacter('MyCharacter'),
          });
          print('✅ Initialized shop data for existing user: ${user.uid}');
        }
      }
    } catch (e) {
      print('❌ Error initializing user shop data: $e');
    }
  }

  /// Get all shop items with ownership status for current user
  Future<List<ShopItem>> getShopItems() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return _getDefaultShopItems();

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await initializeUserShopData();
        return _getDefaultShopItems();
      }

      final userData = userDoc.data()!;
      final ownedItems =
          List<String>.from(userData['owned_items'] ?? ['MyCharacter']);
      final currentCharacter = userData['currentCharacter'] ?? 'MyCharacter';

      return defaultShopItems.map((itemData) {
        final itemId = itemData['id'] as String;
        final isOwned = ownedItems.contains(itemId);
        final isWorn = currentCharacter == itemId;

        return ShopItem(
          id: itemId,
          name: itemData['name'] as String,
          description: itemData['description'] as String,
          price: itemData['price'] as int,
          imagePath: itemData['imagePath'] as String,
          glbFilePath: itemData['glbFilePath'] as String,
          isOwned: isOwned,
          isWorn: isWorn,
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting shop items: $e');
      return _getDefaultShopItems();
    }
  }

  /// Get default shop items (fallback)
  List<ShopItem> _getDefaultShopItems() {
    return defaultShopItems.map((itemData) {
      final itemId = itemData['id'] as String;
      return ShopItem(
        id: itemId,
        name: itemData['name'] as String,
        description: itemData['description'] as String,
        price: itemData['price'] as int,
        imagePath: itemData['imagePath'] as String,
        glbFilePath: itemData['glbFilePath'] as String,
        isOwned:
            itemId == 'MyCharacter', // Only MyCharacter is owned by default
        isWorn: itemId == 'MyCharacter', // Only MyCharacter is worn by default
      );
    }).toList();
  }

  /// Buy an item
  Future<bool> buyItem(String itemId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Get item details
      final itemData = defaultShopItems.firstWhere(
        (item) => item['id'] == itemId,
        orElse: () => throw Exception('Item not found'),
      );

      final price = itemData['price'] as int;

      // Check if user has enough coins
      final hasEnoughCoins = await _coinService.hasEnoughCoins(price);
      if (!hasEnoughCoins) {
        print('❌ Insufficient coins to buy $itemId');
        return false;
      }

      // Deduct coins
      final coinsDeducted = await _coinService.deductCoins(price);
      if (!coinsDeducted) {
        print('❌ Failed to deduct coins for $itemId');
        return false;
      }

      // Add item to owned items
      await _firestore.collection('users').doc(user.uid).update({
        'owned_items': FieldValue.arrayUnion([itemId]),
      });

      print('✅ Successfully bought $itemId for $price coins');
      return true;
    } catch (e) {
      print('❌ Error buying item $itemId: $e');
      return false;
    }
  }

  /// Wear an item (set as active character)
  Future<bool> wearItem(String itemId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check if user owns the item
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final ownedItems =
          List<String>.from(userData['owned_items'] ?? ['MyCharacter']);

      if (!ownedItems.contains(itemId)) {
        print('❌ User does not own $itemId');
        return false;
      }

      // Set as current character and update related fields
      await _firestore.collection('users').doc(user.uid).update({
        'currentCharacter': itemId,
        'homeGlbPath': _characterDataService.getHomeGlbPathForCharacter(itemId),
        'spriteSheets':
            _characterDataService.getSpriteSheetsForCharacter(itemId),
      });

      // Trigger animation reload for the new character
      await _animationService.onCharacterChanged(itemId);

      print('✅ Successfully wearing $itemId');
      return true;
    } catch (e) {
      print('❌ Error wearing item $itemId: $e');
      return false;
    }
  }

  /// Get current worn item
  Future<String> getCurrentWornItem() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'MyCharacter';

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return 'MyCharacter';

      final userData = userDoc.data()!;
      return userData['currentCharacter'] ?? 'MyCharacter';
    } catch (e) {
      print('❌ Error getting current worn item: $e');
      return 'MyCharacter';
    }
  }

  /// Get owned items for current user
  Future<List<String>> getOwnedItems() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return ['MyCharacter'];

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return ['MyCharacter'];

      final userData = userDoc.data()!;
      return List<String>.from(userData['owned_items'] ?? ['MyCharacter']);
    } catch (e) {
      print('❌ Error getting owned items: $e');
      return ['MyCharacter'];
    }
  }

  /// Stream to listen to shop data changes
  Stream<Map<String, dynamic>> getShopDataStream() {
    final user = _auth.currentUser;
    if (user == null)
      return Stream.value({
        'owned_items': ['MyCharacter'],
        'currentCharacter': 'MyCharacter',
      });

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) {
        return {
          'owned_items': ['MyCharacter'],
          'currentCharacter': 'MyCharacter',
        };
      }

      final data = doc.data()!;
      return {
        'owned_items':
            List<String>.from(data['owned_items'] ?? ['MyCharacter']),
        'currentCharacter': data['currentCharacter'] ?? 'MyCharacter',
      };
    });
  }

  /// Get shop item by ID
  ShopItem? getShopItemById(String itemId) {
    try {
      final itemData = defaultShopItems.firstWhere(
        (item) => item['id'] == itemId,
      );

      return ShopItem(
        id: itemData['id'] as String,
        name: itemData['name'] as String,
        description: itemData['description'] as String,
        price: itemData['price'] as int,
        imagePath: itemData['imagePath'] as String,
        glbFilePath: itemData['glbFilePath'] as String,
        isOwned: false, // This will be updated by getShopItems()
        isWorn: false, // This will be updated by getShopItems()
      );
    } catch (e) {
      print('❌ Shop item not found: $itemId');
      return null;
    }
  }

  /// Check if user owns an item
  Future<bool> userOwnsItem(String itemId) async {
    final ownedItems = await getOwnedItems();
    return ownedItems.contains(itemId);
  }

  /// Check if user is wearing an item
  Future<bool> userIsWearingItem(String itemId) async {
    final wornItem = await getCurrentWornItem();
    return wornItem == itemId;
  }
}
