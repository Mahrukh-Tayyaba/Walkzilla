# Duo Challenge Invite Functionality

## Overview
This document describes the implementation of real-time duo challenge invite functionality that ensures invite popups appear immediately when users log in or are already using the app.

## Features Implemented

### 1. Real-time Invite Listening
- **Service**: `DuoChallengeService` in `lib/services/duo_challenge_service.dart`
- **Functionality**: Listens for new duo challenge invites in real-time using Firestore streams
- **Trigger**: Automatically starts when user logs in and navigates to home screen

### 2. Immediate Popup Display
- **Dialog**: `DuoChallengeInviteDialog` in `lib/widgets/duo_challenge_invite_dialog.dart`
- **Display**: Shows immediately when a new invite is received
- **Actions**: Accept or Decline buttons with proper Firestore updates

### 3. Login/App Launch Invite Check
- **Login Screen**: Checks for existing pending invites when user logs in
- **Signup Screen**: Checks for existing pending invites when new user signs up
- **Home Screen**: Continuously listens for new invites while app is active

## Implementation Details

### Key Components

1. **DuoChallengeService**
   - Real-time Firestore listener for pending invites
   - Handles invite dialog display
   - Checks for existing invites on login
   - Proper cleanup on dispose

2. **Integration Points**
   - `lib/home.dart`: Initializes service and starts listening
   - `lib/login_screen.dart`: Checks for existing invites on login
   - `lib/signup_screen.dart`: Checks for existing invites on signup
   - `lib/main.dart`: Global navigator key for dialog display

3. **Firestore Structure**
   ```javascript
   duo_challenge_invites/{inviteId}
   {
     fromUserId: string,
     toUserId: string,
     status: 'pending' | 'accepted' | 'declined',
     createdAt: timestamp,
     challengeType: 'duo',
     expiresAt: timestamp
   }
   ```

### Flow Diagram

```
User Logs In → Check Existing Invites → Show Dialog (if any)
     ↓
Start Real-time Listener → Listen for New Invites → Show Dialog Immediately
     ↓
User Accepts/Declines → Update Firestore → Close Dialog
```

## Usage

### For Users
1. When a friend sends a duo challenge invite, the popup appears immediately
2. If the user was offline, the popup appears when they log in
3. User can accept or decline the challenge
4. Dialog is non-dismissible to ensure user action

### For Developers
1. The service automatically handles all invite listening
2. No manual intervention required
3. Proper error handling and cleanup included
4. Uses global navigator key for dialog display

## Technical Notes

### Error Handling
- Network errors are logged but don't crash the app
- Invalid invite data is handled gracefully
- Missing user data falls back to default values

### Performance
- Real-time listener only active when user is logged in
- Proper cleanup prevents memory leaks
- Efficient Firestore queries with proper indexing

### Security
- Only authenticated users can receive invites
- Proper Firestore security rules in place
- User can only see invites sent to them

## Testing

To test the functionality:

1. **Real-time Testing**:
   - Have two users logged in
   - Send invite from one user to another
   - Verify popup appears immediately

2. **Login Testing**:
   - Send invite to offline user
   - Have user log in
   - Verify popup appears on login

3. **Edge Cases**:
   - Test with invalid invite data
   - Test network disconnection scenarios
   - Test multiple simultaneous invites

## Future Enhancements

1. **Multiple Invites**: Handle multiple pending invites
2. **Invite Expiry**: Auto-decline expired invites
3. **Push Notifications**: Enhanced FCM integration
4. **Invite History**: Track accepted/declined invites
5. **Custom Messages**: Allow custom invite messages 