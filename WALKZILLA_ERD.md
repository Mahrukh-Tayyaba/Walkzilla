# Walkzilla - Entity Relationship Diagram (ERD)

## Overview
This document presents the simplified Entity Relationship Diagram for Walkzilla, a fitness walking app with social features and gamification.

## Core Entities

### 1. **User** (Primary Entity)
**Key Attributes:**
- `userId` (PK) - Unique identifier
- `username` - Unique username
- `displayName` - User's display name
- `email` - User's email
- `level` - Current level
- `coins` - Virtual currency
- `daily_steps` - Daily step counts
- `weekly_steps` - Weekly step total

### 2. **Username** (Username Reservation)
**Key Attributes:**
- `username` (PK) - Reserved username
- `userId` (FK) - Owner's user ID

### 3. **Friend Request** (Friend Management)
**Key Attributes:**
- `requestId` (PK) - Unique request ID
- `fromUserId` (FK) - Sender's user ID
- `toUserId` (FK) - Recipient's user ID
- `status` - "pending", "accepted", "declined"

### 4. **Friendship** (Friend Relationships)
**Key Attributes:**
- `friendshipId` (PK) - Unique friendship ID
- `users` - Array of two user IDs

### 5. **Chat** (Messaging)
**Key Attributes:**
- `chatId` (PK) - Unique chat ID
- `participants` - Array of user IDs
- `lastMessage` - Last message text

### 6. **Message** (Chat Messages)
**Key Attributes:**
- `messageId` (PK) - Unique message ID
- `chatId` (FK) - Parent chat ID
- `senderId` (FK) - Sender's user ID
- `text` - Message content

### 7. **Duo Challenge** (Gaming)
**Key Attributes:**
- `inviteId` (PK) - Unique invite ID
- `fromUserId` (FK) - Inviter's user ID
- `toUserId` (FK) - Invitee's user ID
- `status` - "pending", "accepted", "declined"
- `gameData` - Game state information

### 8. **Leaderboard** (Competition)
**Key Attributes:**
- `historyId` (PK) - Unique history ID
- `type` - "daily" or "weekly"
- `date` - Competition date
- `winners` - Array of winner data

## Entity Relationships

### Core Relationships

1. **User ↔ Username** (1:1)
   - Each user has one unique username

2. **User ↔ Friend Request** (1:Many)
   - Users can send/receive multiple friend requests

3. **User ↔ Friendship** (Many:Many)
   - Users connect through friendships

4. **User ↔ Chat** (Many:Many)
   - Users participate in multiple chats

5. **Chat ↔ Message** (1:Many)
   - Each chat contains multiple messages

6. **User ↔ Duo Challenge** (1:Many)
   - Users can send/receive multiple challenges

7. **User ↔ Leaderboard** (Many:Many)
   - Users participate in competitions

### Key Business Rules

- Usernames must be unique across all users
- Friend requests cannot be duplicated
- Only chat participants can send messages
- Challenge invites have expiration times
- Leaderboard rewards are distributed automatically

## Data Flow Summary

1. **Fitness Tracking**: User steps → Daily/Weekly totals → Leaderboard
2. **Social Features**: Friend requests → Friendships → Chat access
3. **Gaming**: Challenge invites → Game sessions → Results
4. **Rewards**: Leaderboard results → Coin distribution → User balance

This simplified ERD shows the core data architecture of Walkzilla, focusing on the main entities and their relationships for the fitness app's key features. 