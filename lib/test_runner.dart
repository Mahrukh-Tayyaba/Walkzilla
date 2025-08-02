import 'package:flutter/material.dart';
import 'test_dynamic_glb.dart';
import 'test_shop_wear.dart';

/// Simple test runner for DynamicGlbTest
class TestRunner extends StatelessWidget {
  const TestRunner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dynamic GLB Test Runner'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () async {
                print('🧪 Running Current User GLB Path Test...');
                await DynamicGlbTest.testCurrentUserGlbPath();
              },
              child: const Text('Test Current User GLB Path'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                print('🧪 Running GLB Path Update Test...');
                await DynamicGlbTest.testGlbPathUpdate();
              },
              child: const Text('Test GLB Path Update'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                print('🧪 Running Real-time Listener Test...');
                await DynamicGlbTest.testRealTimeListener();
              },
              child: const Text('Test Real-time Listener'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                print('🧪 Running All GLB Tests...');
                await DynamicGlbTest.runAllTests();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Run All GLB Tests'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                print('🧪 Testing Wear BlueStar...');
                await ShopWearTest.testWearBlueStar();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test Wear BlueStar'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                print('🧪 Running All Shop Wear Tests...');
                await ShopWearTest.runAllTests();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Run All Shop Wear Tests'),
            ),
          ],
        ),
      ),
    );
  }
} 