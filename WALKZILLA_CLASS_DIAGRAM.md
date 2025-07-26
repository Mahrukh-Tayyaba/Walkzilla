# Walkzilla - UML Class Diagram

## 4.6 CLASS DIAGRAM

This UML Class Diagram illustrates the structure of the Walkzilla fitness app, showing classes, their attributes, and relationships between them.

## Classes and Their Attributes

### <<Entity>> User
**Core user entity representing app users**
- `_id` (String) - Unique user identifier
- `username` (String) - Unique username
- `displayName` (String) - User's display name
- `email` (String) - User's email address
- `password` (String) - Encrypted password
- `profileImage` (String) - Profile picture URL
- `level` (Number) - Current user level
- `currentStreak` (Number) - Current streak count
- `coins` (Number) - Virtual currency balance
- `isOnline` (Boolean) - Online status
- `lastActive` (Date) - Last activity timestamp
- `fcmToken` (String) - Push notification token
- `hasHealthPermissions` (Boolean) - Health data access
- `createdAt` (Date) - Account creation date
- `lastLogin` (Date) - Last login timestamp

### <<Entity>> Username
**Username reservation entity**
- `_id` (String) - Username string as ID
- `userId` (String) - Owner's user ID
- `reservedAt` (Date) - Reservation timestamp

### <<Entity>> FriendRequest
**Friend request management entity**
- `_id` (String) - Unique request identifier
- `fromUserId` (String) - Sender's user ID
- `toUserId` (String) - Recipient's user ID
- `status` (StringEnum) - "pending", "accepted", "declined"
- `createdAt` (Date) - Request creation time
- `acceptedAt` (Date) - Acceptance timestamp
- `declinedAt` (Date) - Decline timestamp

### <<Entity>> Friendship
**Friend relationship entity**
- `_id` (String) - Unique friendship identifier
- `users` (String[]) - Array of two user IDs
- `createdAt` (Date) - Friendship creation time

### <<Entity>> Chat
**Chat conversation entity**
- `_id` (String) - Unique chat identifier
- `participants` (String[]) - Array of participant user IDs
- `createdAt` (Date) - Chat creation time
- `lastMessage` (String) - Last message text
- `lastMessageTime` (Date) - Last message timestamp
- `unreadCount` (Map<String, Number>) - Unread count per user

### <<Entity>> Message
**Individual chat message entity**
- `_id` (String) - Unique message identifier
- `chatId` (String) - Parent chat ID
- `senderId` (String) - Sender's user ID
- `text` (String) - Message content
- `timestamp` (Date) - Message timestamp
- `isRead` (Boolean) - Read status

### <<Entity>> DuoChallenge
**Duo challenge invitation entity**
- `_id` (String) - Unique invite identifier
- `fromUserId` (String) - Inviter's user ID
- `toUserId` (String) - Invitee's user ID
- `status` (StringEnum) - "pending", "accepted", "declined"
- `challengeType` (String) - "duo"
- `createdAt` (Date) - Invite creation time
- `expiresAt` (Date) - Invite expiration time
- `acceptedAt` (Date) - Acceptance timestamp
- `declinedAt` (Date) - Decline timestamp
- `senderNotified` (Boolean) - Notification status
- `gameStarted` (Boolean) - Game status
- `gameStartTime` (Date) - Game start timestamp

### <<Entity>> Leaderboard
**Leaderboard competition entity**
- `_id` (String) - Unique history identifier
- `type` (StringEnum) - "daily" or "weekly"
- `date` (String) - Competition date (YYYY-MM-DD)
- `createdAt` (Date) - History creation time
- `winners` (Winner[]) - Array of winner data

### <<Value Object>> Winner
**Winner data value object**
- `userId` (String) - Winner's user ID
- `name` (String) - Winner's name
- `steps` (Number) - Step count
- `rank` (Number) - Position rank
- `reward` (Number) - Reward amount

### <<Value Object>> CharacterSpriteSheets
**Character animation value object**
- `idle` (String) - Idle animation path
- `walking` (String) - Walking animation path

### <<Value Object>> DailySteps
**Daily step tracking value object**
- `date` (String) - Date in YYYY-MM-DD format
- `stepCount` (Number) - Steps for that date

### <<Value Object>> ShownReward
**Reward notification tracking value object**
- `shownAt` (Date) - When notification was shown
- `rank` (Number) - User's rank
- `steps` (Number) - User's step count
- `reward` (Number) - Reward amount
- `date` (String) - Reward date

### <<Entity>> GameSession
**Active game session entity**
- `_id` (String) - Unique session identifier
- `challengeId` (String) - Associated challenge ID
- `players` (String[]) - Array of player user IDs
- `startTime` (Date) - Session start time
- `endTime` (Date) - Session end time
- `gameData` (GameData) - Current game state
- `isActive` (Boolean) - Session status

### <<Value Object>> GameData
**Game state value object**
- `lobbyPresence` (Map<String, Boolean>) - Player presence
- `positions` (Map<String, Number>) - Player positions
- `steps` (Map<String, Number>) - Player step counts
- `scores` (Map<String, Number>) - Player scores

## Relationships and Cardinality

### Primary Relationships

1. **User** owns **Username** (1:1)
   - One user can have one username
   - One username belongs to one user

2. **User** sends **FriendRequest** (1:*)
   - One user can send many friend requests
   - Each friend request has one sender

3. **User** receives **FriendRequest** (1:*)
   - One user can receive many friend requests
   - Each friend request has one recipient

4. **User** participates in **Friendship** (*:*)
   - Users connect through friendships
   - Each friendship involves exactly two users

5. **User** joins **Chat** (*:*)
   - Users participate in multiple chats
   - Each chat has multiple participants

6. **Chat** contains **Message** (1:*)
   - Each chat contains multiple messages
   - Each message belongs to one chat

7. **User** sends **Message** (1:*)
   - One user can send many messages
   - Each message has one sender

8. **User** creates **DuoChallenge** (1:*)
   - One user can create many challenges
   - Each challenge has one creator

9. **User** receives **DuoChallenge** (1:*)
   - One user can receive many challenges
   - Each challenge has one recipient

10. **DuoChallenge** creates **GameSession** (1:1)
    - Each accepted challenge creates one game session
    - Each game session belongs to one challenge

11. **User** participates in **Leaderboard** (*:*)
    - Users participate in multiple competitions
    - Each leaderboard includes multiple users

12. **User** has **CharacterSpriteSheets** (1:1)
    - Each user has one set of character animations
    - Each character set belongs to one user

13. **User** tracks **DailySteps** (1:*)
    - One user can have multiple daily step records
    - Each daily step record belongs to one user

14. **User** records **ShownReward** (1:*)
    - One user can have multiple shown rewards
    - Each shown reward belongs to one user

## Business Rules

- Usernames must be unique across all users
- Friend requests cannot be duplicated between the same users
- Only chat participants can send messages to that chat
- Challenge invites have expiration times (24 hours)
- Leaderboard rewards are distributed automatically via cloud functions
- Game sessions are created only when challenges are accepted
- Character sprite sheets are initialized with default values for new users
- Daily steps are tracked with date-based keys for efficient querying

## Data Flow Summary

1. **User Registration**: User → Username (reservation)
2. **Social Connection**: User → FriendRequest → Friendship
3. **Communication**: User → Chat → Message
4. **Gaming**: User → DuoChallenge → GameSession
5. **Competition**: User → DailySteps → Leaderboard → ShownReward
6. **Progression**: User → CharacterSpriteSheets (customization)

This class diagram represents the complete object-oriented structure of the Walkzilla fitness app, showing all major classes, their attributes, and relationships in a UML-compliant format suitable for academic documentation. 