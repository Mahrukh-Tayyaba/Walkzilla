# Walkzilla - Fitness Walking App

A Flutter-based fitness walking app that tracks steps, calories, and heart rate while providing a gamified experience with friends.

## Features

### Core Features
- **Step Tracking**: Real-time step counting using device sensors
- **Health Data Integration**: Tracks calories and heart rate
- **Gamification**: Level system, streaks, and achievements
- **Social Features**: Friend system with real-time activity sharing
- **Games**: Built-in mini-games for entertainment during walks

### Friend System
- **Search Users**: Search for friends by username
- **Friend Requests**: Send and receive friend requests
- **Real-time Updates**: Live updates of friend activity
- **Friend Profiles**: View detailed friend profiles and stats
- **Chat System**: Direct messaging with friends
- **Challenges**: Compete with friends on step goals

### Friend Management
- **Add Friends**: Search by username and send friend requests
- **Accept/Decline Requests**: Manage incoming friend requests
- **View Friends**: See all your friends with their current activity
- **Cancel Requests**: Cancel pending friend requests you've sent
- **Remove Friends**: Unfriend users when needed

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Firebase project with Firestore database
- Android Studio / VS Code

### Installation
1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Configure Firebase:
   - Add `google-services.json` to `android/app/`
   - Add `GoogleService-Info.plist` to `ios/Runner/`
4. Deploy Firestore rules from `firestore.rules`
5. Run the app: `flutter run`

### Firebase Setup
The app requires the following Firestore collections:
- `users`: User profiles and data
- `usernames`: Username reservations
- `friend_requests`: Friend request management
- `friendships`: Friend relationships
- `health_data`: Health metrics storage

## Architecture

### Services
- `FriendService`: Handles all friend-related operations
- `HealthService`: Manages health data collection
- `UsernameService`: Username availability and generation

### Key Components
- Real-time data streaming with Firestore
- Debounced search functionality
- Secure friend request system
- Optimized database queries

## Usage

### Adding Friends
1. Navigate to the Friends page
2. Tap the "+" button to open the Add Friends dialog
3. Search for users by username
4. Tap "Add" to send a friend request

### Managing Friend Requests
- **Requests Tab**: View and respond to incoming requests
- **Invites Sent Tab**: Track your sent requests
- Accept/decline requests with one tap

### Viewing Friends
- **All Friends Tab**: See your current friends
- Real-time online status and activity
- Tap on friends to view profiles or start chats

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.
