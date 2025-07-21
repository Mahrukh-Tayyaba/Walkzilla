# User Document Cleanup Summary

## Overview
This document summarizes the changes made to remove unnecessary fields from user documents in the Walkzilla app.

## Fields Removed
The following fields have been removed from user documents and will no longer be created in future documents:

- `bestStreak`
- `bio`
- `calories`
- `distance`
- `goalMetDays`
- `monthlyGoal`
- `monthly_steps`
- `steps`
- `todaySteps`
- `today_steps`
- `weeklyGoal`

## Files Modified

### 1. User Document Creation Files
- **`lib/login_screen.dart`**: Removed unnecessary fields from new user document creation
- **`lib/signup_screen.dart`**: Removed unnecessary fields from Google signup user document creation
- **`lib/email_verification_screen.dart`**: Removed `todaySteps` field from email verification user document creation

### 2. Migration Services
- **`lib/services/leaderboard_migration_service.dart`**: 
  - Removed `monthly_steps` from leaderboard data initialization
  - Updated `_recalculateUserTotals` method to only calculate weekly totals
  - Removed monthly calculations and updates

### 3. Leaderboard Service
- **`lib/services/leaderboard_service.dart`**: 
  - Removed `removeMonthlyDataFromAllUsers` method
  - Kept only weekly leaderboard functionality

### 4. Cloud Functions
- **`functions/leaderboard_functions.js`**: 
  - Removed `monthly_steps` from daily step aggregation
  - Removed entire `distributeMonthlyRewards` function
- **`functions/index.js`**: 
  - Removed export for `distributeMonthlyRewards`

### 5. New Cleanup Service
- **`lib/services/user_document_cleanup_service.dart`**: 
  - New service to remove unnecessary fields from existing user documents
  - Methods to clean up individual users or all users
  - Check if cleanup is needed

### 6. App Initialization
- **`lib/main.dart`**: 
  - Added cleanup service initialization
  - Automatically cleans up all existing user documents on app start

## Current User Document Structure
After cleanup, user documents will only contain these essential fields:

```json
{
  "username": "string",
  "displayName": "string",
  "email": "string",
  "createdAt": "timestamp",
  "lastLogin": "timestamp",
  "hasHealthPermissions": "boolean",
  "profileImage": "string",
  "level": "number",
  "currentStreak": "number",
  "coins": "number",
  "isOnline": "boolean",
  "lastActive": "timestamp",
  "characterSpriteSheets": {
    "idle": "string",
    "walking": "string"
  },
  "daily_steps": {
    "2024-01-15": "number",
    "2024-01-16": "number"
  },
  "weekly_steps": "number",
  "total_coins": "number",
  "last_week_rewarded": "string",
  "last_month_rewarded": "string",
  "fcmToken": "string"
}
```

## Migration Process
1. **Automatic Cleanup**: The app automatically cleans up all existing user documents on startup
2. **Future Prevention**: New user documents will not include the removed fields
3. **Cloud Functions**: Updated to only work with the remaining fields

## Benefits
- **Reduced Document Size**: Smaller user documents mean faster reads/writes
- **Simplified Data Model**: Cleaner, more focused data structure
- **Better Performance**: Less data to transfer and process
- **Easier Maintenance**: Fewer fields to manage and maintain

## Testing
After deployment, verify that:
1. New user registration works correctly
2. Existing users can still log in
3. Leaderboard functionality works with weekly data only
4. No errors related to missing fields appear in logs 