import 'package:flutter/material.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
          0xFFD9D9D9), // Set the background color for the whole screen
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(50), // Increases AppBar height
        child: AppBar(
          backgroundColor: const Color(0xFFD9D9D9), // Updated background color
          automaticallyImplyLeading: false, // Removes the back arrow
          leading: Padding(
            padding: const EdgeInsets.only(
                top: 10.0), // Adds space above the menu icon
            child: IconButton(
              icon: Icon(
                Icons.menu,
                color: Colors.black,
                size: 40, // Increased the size of the menu icon
              ),
              onPressed: () {
                // Handle menu tap
              },
            ),
          ),
          elevation: 0, // Removes the shadow below the AppBar
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
              height: 80, // Height of the rectangle
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Center(
                child: Text(
                  'Steps',
                  style: TextStyle(
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
                // Daily Challenge
                GestureDetector(
                  onTap: () {
                    // Handle Daily Challenge tap
                    print("Daily Challenge tapped!");
                  },
                  child: Column(
                    children: [
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

                // Events
                GestureDetector(
                  onTap: () {
                    // Handle Events tap
                    print("Events tapped!");
                  },
                  child: Column(
                    children: [
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
          SizedBox(height: 60),
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
                  child: Center(
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

          // Spacer for pushing the icons to the bottom
          Spacer(),

          // Bottom row with Solo Mode, Health Tracker, and Challenge Friends
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Solo Mode
                GestureDetector(
                  onTap: () {
                    // Handle Solo Mode tap
                    print("Solo Mode tapped!");
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10.0), // Adjust here
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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

                // Health Tracker (moved slightly right)
                GestureDetector(
                  onTap: () {
                    // Handle Health Tracker tap
                    print("Health Tracker tapped!");
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20.0), // Adjust here
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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

                // Challenge Friends
                GestureDetector(
                  onTap: () {
                    // Handle Challenge Friends tap
                    print("Challenge Friends tapped!");
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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

          // Adds space below the icons to position them at the bottom
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
