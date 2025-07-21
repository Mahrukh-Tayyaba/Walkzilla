# 🏆 Leaderboard System Setup Guide

## Overview
This guide will help you set up the complete leaderboard system for Walkzilla, including data storage, cloud functions, and real-time updates.

## 📋 Prerequisites
- Firebase project with Firestore enabled
- Firebase Functions deployed
- Flutter app with Firebase dependencies

## 🗄️ Data Structure

### User Document Structure
Each user document in the `users` collection should have these fields:

```json
{
  "username": "string",
  "displayName": "string", 
  "profileImageUrl": "string",
  "daily_steps": {
    "2024-01-15": 8500,
    "2024-01-16": 9200
  },
  "weekly_steps": 45000,
  "monthly_steps": 180000,
  "coins": 1250,
  "last_week_rewarded": "2024-01-14",
  "last_month_rewarded": "2024-01-01"
}
```

### Leaderboard History Structure
```json
{
  "type": "weekly|monthly",
  "date": "2024-01-14",
  "winners": [
    {
      "userId": "user123",
      "name": "John Doe",
      "steps": 45000,
      "rank": 1,
      "reward": 500
    }
  ],
  "createdAt": "timestamp"
}
```

## 🚀 Setup Steps

### 1. Deploy Cloud Functions
```bash
cd functions
npm install
firebase deploy --only functions
```

### 2. Initialize Existing Users
Run this once to set up leaderboard data for existing users:

```dart
// In your app initialization
await LeaderboardMigrationService().initializeAllUsersLeaderboardData();
```

### 3. Create Sample Data (Optional)
For testing, create sample leaderboard data:

```dart
await LeaderboardMigrationService().createSampleLeaderboardData();
```

### 4. Update Firestore Rules
Deploy the leaderboard security rules:

```bash
firebase deploy --only firestore:rules
```

## ⏰ Cloud Function Schedule

The system uses these scheduled functions:

- **Daily Aggregation**: Runs at 11:59 PM daily
- **Weekly Rewards**: Runs every Monday at 12:01 AM
- **Monthly Rewards**: Runs on the 1st of each month at 12:01 AM

## 🎁 Reward System

### Weekly Rewards
- 1st Place: 500 coins
- 2nd Place: 250 coins  
- 3rd Place: 100 coins

### Monthly Rewards
- 1st Place: 1000 coins
- 2nd Place: 500 coins
- 3rd Place: 200 coins

## 🔄 Data Flow

1. **Step Collection**: Health service updates daily steps
2. **Aggregation**: Cloud functions aggregate daily → weekly → monthly
3. **Rewards**: Scheduled functions distribute rewards and reset counters
4. **Display**: App fetches real-time leaderboard data

## 🧪 Testing

### Debug Menu
Use the debug menu in the leaderboard page (settings icon) to:
- Refresh data
- Create sample data
- Recalculate totals

### Manual Testing
```dart
// Test step aggregation
await LeaderboardService().updateWeeklyAndMonthlySteps(userId, 5000);

// Test leaderboard fetching
final weeklyData = await LeaderboardService().getWeeklyLeaderboard();
final monthlyData = await LeaderboardService().getMonthlyLeaderboard();
```

## 🔧 Troubleshooting

### Common Issues

1. **No data showing**: 
   - Check if users have leaderboard data initialized
   - Verify Firestore rules allow reading

2. **Steps not updating**:
   - Ensure health service is calling `_updateLeaderboardData`
   - Check cloud function logs

3. **Rewards not distributed**:
   - Verify scheduled functions are deployed
   - Check function logs for errors

### Debug Commands
```bash
# View function logs
firebase functions:log

# Test function manually
firebase functions:shell
```

## 📊 Monitoring

### Key Metrics to Monitor
- Daily active users with steps
- Weekly/monthly reward distribution
- Function execution times
- Data consistency

### Logs to Watch
- `updateDailyStepAggregation`
- `distributeWeeklyRewards` 
- `distributeMonthlyRewards`

## 🔒 Security Considerations

1. **Data Access**: Users can only read leaderboard data, not personal data
2. **Reward Distribution**: Only cloud functions can distribute rewards
3. **Step Validation**: Validate step data before aggregation
4. **Rate Limiting**: Implement rate limits for manual updates

## 🚀 Production Checklist

- [ ] Cloud functions deployed
- [ ] Firestore rules updated
- [ ] Existing users migrated
- [ ] Sample data created (for testing)
- [ ] Health service integration verified
- [ ] Reward notifications tested
- [ ] Real-time updates working
- [ ] Security rules tested

## 📞 Support

If you encounter issues:
1. Check Firebase console logs
2. Verify function deployment status
3. Test with sample data
4. Review Firestore rules

---

**Note**: This system is designed to handle thousands of users efficiently. For larger scale, consider implementing pagination and caching strategies. 