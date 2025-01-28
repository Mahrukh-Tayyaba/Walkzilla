import 'package:flutter/material.dart';
import 'package:health/health.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final health = Health();
  int _steps = 0; // Step count variable

  @override
  void initState() {
    super.initState();
    fetchSteps();
  }

  // Function to fetch steps
  Future<void> fetchSteps() async {
    final types = [HealthDataType.STEPS];
    final startDate =
        DateTime.now().subtract(const Duration(days: 1)); // Last 24 hours
    final endDate = DateTime.now();

    try {
      // Request permissions
      bool permissionsGranted = await health.requestAuthorization(types);

      if (permissionsGranted) {
        // Fetch step data
        List<HealthDataPoint> healthData =
            await health.getHealthAggregateDataFromTypes(
          endDate: endDate,
          startDate: startDate,
          types: types,
        );

        // Calculate total steps
        int totalSteps = healthData.fold<int>(
          0,
          (previousValue, element) => previousValue + (element.value as int),
        );

        setState(() {
          _steps = totalSteps; // Update the steps variable
        });
      } else {
        print("Permissions not granted");
      }
    } catch (e) {
      print("Error fetching health data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          backgroundColor: const Color(0xFFD9D9D9),
          automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.black, size: 40),
              onPressed: () {
                // Handle menu tap
              },
            ),
          ),
          elevation: 0,
        ),
      ),
      body: Column(
        children: [
          // Steps box
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Center(
                child: Text(
                  'Steps: $_steps', // Display the fetched step count
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Daily Challenge and Events below the Steps box
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    print("Daily Challenge tapped!");
                  },
                  child: Column(
                    children: const [
                      Icon(
                        Icons.sports_martial_arts,
                        size: 40,
                        color: Colors.black,
                      ),
                      SizedBox(height: 5),
                      Text('Daily Challenge'),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    print("Events tapped!");
                  },
                  child: Column(
                    children: const [
                      Icon(
                        Icons.calendar_today,
                        size: 40,
                        color: Colors.black,
                      ),
                      SizedBox(height: 5),
                      Text('Events'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
          // Character and steps display
          Center(
            child: Column(
              children: [
                Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey, width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person,
                      size: 100,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(
                  onTap: () {
                    print("Solo Mode tapped!");
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.gamepad,
                          size: 40,
                          color: Colors.black,
                        ),
                        SizedBox(height: 5),
                        Text('Solo Mode'),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    print("Health Tracker tapped!");
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.health_and_safety,
                          size: 40,
                          color: Colors.black,
                        ),
                        SizedBox(height: 5),
                        Text('Health Tracker'),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    print("Challenge Friends tapped!");
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.group,
                        size: 40,
                        color: Colors.black,
                      ),
                      SizedBox(height: 5),
                      Text('Challenge Friends'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
