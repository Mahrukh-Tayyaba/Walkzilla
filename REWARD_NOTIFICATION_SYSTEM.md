# 🏆 Reward Notification System

## Overview
The reward notification system ensures that users only see leaderboard reward notifications once, preventing duplicate notifications when they log in multiple times.

## How It Works

### 1. Reward Tracking
- Each user document has a `shown_rewards` field that tracks which rewards have been displayed
- The field structure: `shown_rewards: { 'daily_2024-01-15': { shown_at, rank, steps, reward, date }, ... }`

### 2. Notification Flow
1. **Reward Distribution**: Cloud functions distribute rewards and create leaderboard history entries
2. **Notification Check**: When user logs in, the app checks leaderboard history for new rewards
3. **Duplicate Prevention**: Before showing notification, check if reward key exists in `shown_rewards`
4. **Mark as Shown**: When notification is displayed, mark the reward as shown in user document

### 3. Reward Keys
- **Daily Rewards**: `daily_YYYY-MM-DD` (e.g., `daily_2024-01-15`)
- **Weekly Rewards**: `weekly_YYYY-MM-DD` (e.g., `weekly_2024-01-14`)

## Implementation Details

### User Document Structure
```json
{
  "username": "string",
  "coins": 1250,
  "shown_rewards": {
    "daily_2024-01-15": {
      "shown_at": "timestamp",
      "rank": 1,
      "steps": 8500,
      "reward": 100,
      "date": "2024-01-15"
    },
    "weekly_2024-01-14": {
      "shown_at": "timestamp", 
      "rank": 2,
      "steps": 45000,
      "reward": 350,
      "date": "2024-01-14"
    }
  }
}
```

### Notification Triggers
1. **Real-time Listeners**: Listen to leaderboard history collection for new entries
2. **FCM Push Notifications**: Handle push notifications from cloud functions
3. **Manual Checks**: Check for unshown rewards on app startup

### Files Modified
- `lib/home.dart`: Updated reward listeners and notification methods
- `lib/main.dart`: Updated FCM notification handlers
- `lib/services/leaderboard_service.dart`: Added reward tracking methods
- `lib/services/leaderboard_migration_service.dart`: Initialize shown_rewards field
- `lib/login_screen.dart`: Include shown_rewards in new user documents
- `lib/signup_screen.dart`: Include shown_rewards in new user documents
- `lib/email_verification_screen.dart`: Include shown_rewards in new user documents
- `lib/services/health_service.dart`: Initialize shown_rewards field

## Benefits
- ✅ No duplicate notifications on multiple logins
- ✅ Tracks reward history for each user
- ✅ Works with both real-time listeners and push notifications
- ✅ Maintains reward data integrity
- ✅ Minimal performance impact

## Testing
To test the system:
1. Win a daily/weekly reward
2. Log out and log back in
3. Verify notification only shows once
4. Check user document for `shown_rewards` field

## Future Enhancements
- Add reward history page showing all earned rewards
- Implement reward expiration/cleanup for old entries
- Add analytics for reward engagement 