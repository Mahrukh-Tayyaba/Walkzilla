import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:model_viewer_plus/model_viewer_plus.dart';

class ShopItem {
  final String id;
  final String name;
  final String description;
  final int price;
  final String imagePath;
  final String glbFilePath;
  final bool isOwned;

  ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imagePath,
    required this.glbFilePath,
    required this.isOwned,
  });
}

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  ShopItem? selectedItem;
  ShopItem? buyPreviewItem;
  int userCoins = 15000;
  PageController? _pageController;
  int _currentPage = 0;
  bool showOwnedItems = false; // Toggle between Buy and Owned

  final List<ShopItem> shopItems = [
    ShopItem(
      id: '1',
      name: 'My Character',
      description: 'Your personal character with unique features and benefits.',
      price: 1500,
      imagePath: 'assets/images/shop_items/MyCharacter.png',
      glbFilePath: 'assets/web/shop/MyCharacter_shop.glb',
      isOwned: true,
    ),
    ShopItem(
      id: '2',
      name: 'Blossom',
      description: 'Beautiful blossom with premium quality and design.',
      price: 2500,
      imagePath: 'assets/images/shop_items/blossom.png',
      glbFilePath: 'assets/web/shop/blossom_shop.glb',
      isOwned: true,
    ),
    ShopItem(
      id: '3',
      name: 'Sun',
      description: 'Bright sun with advanced capabilities.',
      price: 3500,
      imagePath: 'assets/images/shop_items/sun.png',
      glbFilePath: 'assets/web/shop/sun_shop.glb',
      isOwned: false,
    ),
    ShopItem(
      id: '4',
      name: 'Cloud',
      description: 'Fluffy cloud with exclusive features.',
      price: 4500,
      imagePath: 'assets/images/shop_items/cloud.png',
      glbFilePath: 'assets/web/shop/cloud_shop.glb',
      isOwned: false,
    ),
    ShopItem(
      id: '5',
      name: 'Cool',
      description: 'Cool character with superior performance.',
      price: 5500,
      imagePath: 'assets/images/shop_items/cool.png',
      glbFilePath: 'assets/web/shop/cool_shop.glb',
      isOwned: false,
    ),
    ShopItem(
      id: '6',
      name: 'Cow',
      description: 'Friendly cow with innovative technology.',
      price: 6500,
      imagePath: 'assets/images/shop_items/cow.png',
      glbFilePath: 'assets/web/shop/cow_shop.glb',
      isOwned: false,
    ),
    ShopItem(
      id: '7',
      name: 'Monster',
      description: 'Scary monster with premium materials.',
      price: 7500,
      imagePath: 'assets/images/shop_items/monster.png',
      glbFilePath: 'assets/web/shop/monster_shop.glb',
      isOwned: false,
    ),
    ShopItem(
      id: '8',
      name: 'Blue Star',
      description: 'Shining blue star with luxury design.',
      price: 8500,
      imagePath: 'assets/images/shop_items/blueStar.png',
      glbFilePath: 'assets/web/shop/blueStar_shop.glb',
      isOwned: false,
    ),
    ShopItem(
      id: '9',
      name: 'Yellow Star',
      description: 'Bright yellow star with ultimate features.',
      price: 9500,
      imagePath: 'assets/images/shop_items/yellowStar.png',
      glbFilePath: 'assets/web/shop/yellowstar_shop.glb',
      isOwned: false,
    ),
  ];

  void handleItemSelect(ShopItem item) {
    setState(() {
      selectedItem = item;
    });
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
        initialPage: 1000); // Start in the middle for infinite scrolling
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void handleBuyClick(ShopItem item) {
    setState(() {
      buyPreviewItem = item;
      selectedItem = item;
    });
  }

  void closeBuyPreview() {
    setState(() {
      buyPreviewItem = null;
    });
  }

  List<ShopItem> getFilteredItems() {
    return shopItems.where((item) => item.isOwned == showOwnedItems).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayItem = buyPreviewItem ?? selectedItem;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Shop',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on,
                    size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  userCoins.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top 55% - Item Preview Display
          Expanded(
            flex: 55,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: displayItem != null
                    ? _buildItemPreview(displayItem)
                    : _buildDefaultPreview(),
              ),
            ),
          ),

          // Bottom 45% - Shop Items Carousel or Buy Preview
          Expanded(
            flex: 45,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: buyPreviewItem == null
                  ? _buildShopSection()
                  : _buildBuyPreview(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.shopping_bag,
          size: 80,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 16),
        Text(
          'Select an item to preview',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildItemPreview(ShopItem item) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: RepaintBoundary(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: AbsorbPointer(
              child: ModelViewer(
                key: ValueKey('preview_${item.id}'),
                src: item.glbFilePath,
                alt: "A 3D model of ${item.name}",
                autoRotate: false,
                cameraControls: false,
                backgroundColor: Colors.transparent,
                cameraOrbit: "0deg 75deg 100%",
                minCameraOrbit: "0deg 75deg 100%",
                maxCameraOrbit: "0deg 75deg 100%",
                interactionPrompt: InteractionPrompt.none,
                disableTap: true,
                autoPlay: true,
                disableZoom: true,
                disablePan: true,
                minFieldOfView: "45deg",
                maxFieldOfView: "45deg",
                fieldOfView: "45deg",
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShopSection() {
    final filteredItems = getFilteredItems();

    return Column(
      children: [
        // Toggle Switch - 15% of the 45% section
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                // Buy Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        showOwnedItems = false;
                        selectedItem = null;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            !showOwnedItems ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: !showOwnedItems
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Buy',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: !showOwnedItems
                                ? Colors.black
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Owned Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        showOwnedItems = true;
                        selectedItem = null;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            showOwnedItems ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: showOwnedItems
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Owned',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: showOwnedItems
                                ? Colors.black
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Shop Items Carousel - 85% of the 45% section
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        showOwnedItems ? Icons.inventory : Icons.shopping_bag,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        showOwnedItems
                            ? 'No owned items yet'
                            : 'No items available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildShopItemsCarousel(filteredItems),
        ),
      ],
    );
  }

  Widget _buildShopItemsCarousel(List<ShopItem> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selectedItem?.id == item.id;

          return Container(
            width: 160,
            height: 120, // Reduced height to fit in remaining space
            margin: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => handleItemSelect(item),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange[50] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.orange : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Item Image
                    Expanded(
                      flex: 3,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              item.imagePath,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Item Info
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(8), // Reduced padding
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 11, // Reduced font size
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4), // Reduced spacing
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.monetization_on,
                                        size: 10,
                                        color:
                                            Colors.amber), // Reduced icon size
                                    const SizedBox(width: 2),
                                    Text(
                                      item.price.toString(),
                                      style: const TextStyle(
                                        fontSize: 10, // Reduced font size
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                if (!showOwnedItems) // Only show Buy button for purchasable items
                                  GestureDetector(
                                    onTap: () => handleBuyClick(item),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2), // Reduced padding
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Buy',
                                        style: TextStyle(
                                          fontSize: 8, // Reduced font size
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBuyPreview() {
    if (buyPreviewItem == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Close Button
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: closeBuyPreview,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14),
              ),
            ),
          ),

          // Item Preview
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    buyPreviewItem!.imagePath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // Item Details
          Text(
            buyPreviewItem!.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 16),

          // Buy Button
          SizedBox(
            width: double.infinity,
            child: buyPreviewItem!.isOwned
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.check, color: Colors.white, size: 20),
                        SizedBox(height: 4),
                        Text(
                          'Owned',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: userCoins >= buyPreviewItem!.price
                          ? Colors.black
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          userCoins >= buyPreviewItem!.price
                              ? 'Buy'
                              : 'Not enough coins',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: userCoins >= buyPreviewItem!.price
                                ? Colors.white
                                : Colors.grey[500],
                          ),
                        ),
                        if (userCoins >= buyPreviewItem!.price)
                          Row(
                            children: [
                              const Icon(Icons.monetization_on,
                                  size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '${buyPreviewItem!.price}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
