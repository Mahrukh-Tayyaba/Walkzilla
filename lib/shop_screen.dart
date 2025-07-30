import 'package:flutter/material.dart';

class Outfit {
  final String id;
  final String name;
  final String description;
  final int price;
  final String image;
  final bool isOwned;
  final String brand;
  final Map<String, String> colors;

  Outfit({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.isOwned,
    required this.brand,
    required this.colors,
  });
}

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Outfit? selectedOutfit;
  Outfit? buyPreviewItem;
  int userCoins = 15000;

  final List<Outfit> outfits = [
    Outfit(
      id: '1',
      name: 'Neon Street Style',
      description:
          'Complete cyberpunk outfit with glowing hoodie, cargo pants and tech sneakers.',
      price: 5500,
      image: '/placeholder.svg',
      isOwned: false,
      brand: 'CYBER TECH',
      colors: {
        'top': '#00ffff',
        'bottom': '#8fbc8f',
        'shoes': '#ff4500',
      },
    ),
    Outfit(
      id: '2',
      name: 'Galaxy Explorer',
      description:
          'Space-themed outfit with cosmic t-shirt, dark jeans and running shoes.',
      price: 4200,
      image: '/placeholder.svg',
      isOwned: true,
      brand: 'SPACE CO',
      colors: {
        'top': '#4169e1',
        'bottom': '#4682b4',
        'shoes': '#32cd32',
      },
    ),
    Outfit(
      id: '3',
      name: 'Business Professional',
      description:
          'Elegant business outfit with blazer, formal trousers and oxford shoes.',
      price: 7500,
      image: '/placeholder.svg',
      isOwned: false,
      brand: 'VERSACE',
      colors: {
        'top': '#2c3e50',
        'bottom': '#2f4f4f',
        'shoes': '#000000',
        'accessories': '#ffd700',
      },
    ),
    Outfit(
      id: '4',
      name: 'Athletic Performance',
      description: 'Sports outfit with jersey, shorts and high-tech sneakers.',
      price: 6800,
      image: '/placeholder.svg',
      isOwned: false,
      brand: 'NIKE',
      colors: {
        'top': '#e74c3c',
        'bottom': '#ff7f50',
        'shoes': '#ff4500',
      },
    ),
    Outfit(
      id: '5',
      name: 'Casual Summer',
      description:
          'Relaxed summer outfit with t-shirt, shorts and casual sneakers.',
      price: 3500,
      image: '/placeholder.svg',
      isOwned: true,
      brand: 'UNIQLO',
      colors: {
        'top': '#4169e1',
        'bottom': '#ff7f50',
        'shoes': '#32cd32',
        'accessories': '#dc143c',
      },
    ),
    Outfit(
      id: '6',
      name: 'Urban Explorer',
      description:
          'Adventure-ready outfit with hoodie, cargo pants and durable boots.',
      price: 6200,
      image: '/placeholder.svg',
      isOwned: false,
      brand: 'CARHARTT',
      colors: {
        'top': '#00ffff',
        'bottom': '#8fbc8f',
        'shoes': '#8b4513',
      },
    ),
    Outfit(
      id: '7',
      name: 'Royal Elegance',
      description:
          'Luxurious outfit with elegant blazer, formal trousers and golden crown.',
      price: 12000,
      image: '/placeholder.svg',
      isOwned: false,
      brand: 'GUCCI',
      colors: {
        'top': '#2c3e50',
        'bottom': '#2f4f4f',
        'shoes': '#000000',
        'accessories': '#ffd700',
      },
    ),
    Outfit(
      id: '8',
      name: 'Tech Futurist',
      description:
          'High-tech outfit with smart accessories and futuristic styling.',
      price: 9500,
      image: '/placeholder.svg',
      isOwned: false,
      brand: 'TESLA',
      colors: {
        'top': '#4169e1',
        'bottom': '#2f4f4f',
        'shoes': '#708090',
        'accessories': '#708090',
      },
    ),
  ];

  void handleTryOn(Outfit outfit) {
    setState(() {
      selectedOutfit = outfit;
    });
  }

  void handleBuyClick(Outfit outfit) {
    setState(() {
      buyPreviewItem = outfit;
      selectedOutfit = outfit;
    });
  }

  void closeBuyPreview() {
    setState(() {
      buyPreviewItem = null;
    });
  }

  Color hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF${hex}', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final displayOutfit = buyPreviewItem ?? selectedOutfit;

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
          'Character Shop',
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
          // Top 55% - Avatar Display
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
                child: _buildAvatar(displayOutfit),
              ),
            ),
          ),

          // Bottom 45% - Outfit Carousel or Buy Preview
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
                  ? _buildOutfitCarousel()
                  : _buildBuyPreview(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Outfit? outfit) {
    return SizedBox(
      height: 240,
      width: 200,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Avatar Body
          Column(
            children: [
              // Head
              Container(
                width: 48,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Stack(
                  children: [
                    // Hair
                    Positioned(
                      top: -6,
                      left: 6,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF92400E),
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                    // Eyes
                    Positioned(
                      top: 18,
                      left: 9,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 18,
                      right: 9,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Mouth
                    Positioned(
                      top: 30,
                      left: 15,
                      child: Container(
                        width: 12,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF472B6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Accessories
                    if (outfit?.colors['accessories'] != null)
                      Positioned(
                        top: -9,
                        left: 12,
                        child: outfit!.name.contains('Tech')
                            ? const Icon(Icons.visibility,
                                size: 12, color: Colors.grey)
                            : Container(
                                width: 36,
                                height: 18,
                                decoration: BoxDecoration(
                                  color:
                                      hexToColor(outfit.colors['accessories']!),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                ),
                              ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Torso
              Container(
                width: 60,
                height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    // Arms
                    Positioned(
                      top: 12,
                      left: -12,
                      child: Container(
                        width: 18,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        transform: Matrix4.rotationZ(0.2),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: -12,
                      child: Container(
                        width: 18,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        transform: Matrix4.rotationZ(-0.2),
                      ),
                    ),
                    // Top Clothing
                    if (outfit != null)
                      Container(
                        decoration: BoxDecoration(
                          color: hexToColor(outfit.colors['top']!),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              outfit.name.split(' ')[0],
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Legs
              Container(
                width: 60,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  ),
                ),
                child: outfit != null
                    ? Container(
                        decoration: BoxDecoration(
                          color: hexToColor(outfit.colors['bottom']!),
                        ),
                        child: const Center(
                          child: Text(
                            'Outfit',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),

              // Feet/Shoes
              Container(
                width: 72,
                height: 24,
                decoration: BoxDecoration(
                  color: outfit != null
                      ? hexToColor(outfit.colors['shoes']!)
                      : Colors.grey,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: outfit != null
                    ? const Center(
                        child: Text(
                          'Shoes',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitCarousel() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: outfits.length,
        itemBuilder: (context, index) {
          final outfit = outfits[index];
          final isSelected = selectedOutfit?.id == outfit.id;

          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => handleTryOn(outfit),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Outfit Preview
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Container(
                              width: 24,
                              height: 54,
                              decoration: BoxDecoration(
                                color: hexToColor(outfit.colors['top']!),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 54,
                              decoration: BoxDecoration(
                                color: hexToColor(outfit.colors['bottom']!),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 36,
                              decoration: BoxDecoration(
                                color: hexToColor(outfit.colors['shoes']!),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Outfit Info
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              outfit.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.monetization_on,
                                        size: 12, color: Colors.amber),
                                    const SizedBox(width: 2),
                                    Text(
                                      outfit.price.toString(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () => handleBuyClick(outfit),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Buy',
                                      style: TextStyle(
                                        fontSize: 10,
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

          // Outfit Preview
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: 40,
                    height: 64,
                    decoration: BoxDecoration(
                      color: hexToColor(buyPreviewItem!.colors['top']!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 64,
                    decoration: BoxDecoration(
                      color: hexToColor(buyPreviewItem!.colors['bottom']!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 48,
                    decoration: BoxDecoration(
                      color: hexToColor(buyPreviewItem!.colors['shoes']!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Outfit Details
          Column(
            children: [
              Text(
                buyPreviewItem!.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Text(
                'in Premium Colors',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: userCoins >= buyPreviewItem!.price
                          ? Colors.black
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          userCoins >= buyPreviewItem!.price
                              ? 'Buy'
                              : 'Not enough coins',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: userCoins >= buyPreviewItem!.price
                                ? Colors.white
                                : Colors.grey[500],
                          ),
                        ),
                        if (userCoins >= buyPreviewItem!.price) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.monetization_on,
                                  size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '${buyPreviewItem!.price} Coins',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
