# 🎯 Hybrid Leveling System - One Level at a Time

## Overview
The Walkzilla app features a hybrid leveling system that combines **Total Lifetime Steps** and **Streak Milestones**, but ensures users can only increase **one level at a time** for better progression control and engagement.

## 🏆 Level Progression Rules

### **Core Principle: One Level at a Time**
- Users can only gain **one level per trigger**
- Multiple achievements don't stack for instant level jumps
- Each level increase is meaningful and celebrated

### **Level Triggers**

#### 1. **Step Progression Level Up**
- **Trigger**: Reaching next step milestone (15k, 30k, 45k, etc.)
- **Increase**: +1 level
- **Example**: User at 14,500 steps reaches 15,000 steps → Level 1 → Level 2

#### 2. **Streak Milestone Level Up**
- **Trigger**: Reaching streak milestones (7-day, 14-day, 30-day) for the **first time**
- **Increase**: +1 level
- **Example**: User reaches 7-day streak for the first time → Current Level + 1
- **Note**: Once achieved, these milestones won't trigger level ups again

#### 3. **Monthly Streak Level Up**
- **Trigger**: Completing a full month (30 days) of consistent streak
- **Increase**: +1 level
- **Example**: User completes 30-day streak → Current Level + 1

### **Level Requirements**

#### Base Level from Total Lifetime Steps
```
Level 1: 0 steps (starting)
Level 2: 15,000 steps
Level 3: 30,000 steps
Level 4: 45,000 steps
Level 5: 60,000 steps
Level 6: 75,000 steps
Level 7: 90,000 steps
Level 8: 105,000 steps
Level 9: 120,000 steps
Level 10: 135,000 steps
Level 11+: Every 20,000 steps after 135,000
```

#### Streak Milestones & Monthly Progression
```
Streak Milestone Level Ups (First-time only):
- 7-day streak: +1 level (first time only)
- 14-day streak: +1 level (first time only)
- 30-day streak: +1 level (first time only)

Monthly Level Progression:
- Every 30 days of consistent streak = +1 level
- 60-day streak = +2 levels (one at a time)
- 90-day streak = +3 levels (one at a time)
- 120-day streak = +4 levels (one at a time)
```

## 🔄 Level Up Process

### **Step Progression Level Up**
```dart
// When user takes steps
final result = await LevelingService.updateUserLevel(userId, stepIncrease);

if (result['leveledUp']) {
  // Show level up notification
  // User gains +1 level
  // User gets coin reward
}
```

### **Streak Level Up (Milestones + Monthly)**
```dart
// When user's streak updates
final result = await LevelingService.checkStreakLevelUp(userId, newStreak);

if (result['leveledUp']) {
  // Show level up notification
  // User gains +1 level
  // User gets coin reward
}
```

## 📊 Example Progression Scenarios

### **Scenario 1: Step Progression**
- User has 14,500 steps (Level 1)
- User walks 500 more steps → 15,000 total
- **Result**: Level 1 → Level 2 (+1 level)

### **Scenario 2: Streak Milestone (First-time)**
- User has 6-day streak (Level 5)
- User completes 7th day → 7-day streak (first time)
- **Result**: Level 5 → Level 6 (+1 level for reaching 7-day milestone)
- **Note**: If user later breaks streak and reaches 7-day again, no level up

### **Scenario 3: Monthly Streak**
- User has 29-day streak (Level 6)
- User completes 30th day → 30-day streak
- **Result**: Level 6 → Level 7 (+1 level for completing a month)

### **Scenario 4: Multiple Achievements (Sequential)**
- User has 14,500 steps and 6-day streak (Level 3)
- User walks 500 steps AND completes 7-day streak
- **Result**: 
  1. First trigger: Level 3 → Level 4 (step progression)
  2. Second trigger: Level 4 → Level 5 (streak milestone)
  - **Total**: +2 levels, but achieved one at a time

### **Scenario 5: Long-term Streak Achievement**
- User has 89-day streak (Level 10)
- User reaches 90-day streak
- **Result**: Level 10 → Level 11 (+1 level for completing 3rd month)
- **Note**: Each month (30 days) of consistent streak = +1 level

## 🎁 Rewards System

### **Coin Rewards per Level**
- **Levels 1-10**: 50 coins
- **Levels 11-25**: 75 coins
- **Levels 26-50**: 100 coins
- **Levels 51-100**: 150 coins
- **Levels 101+**: 200 coins



## 🗄️ Database Structure

### **User Document Fields**
```json
{
  "level": 5,
  "totalLifetimeSteps": 75000,
  "currentStreak": 7,
  "achievedMilestones": [7, 14],
  "levelUpHistory": [
    {
      "timestamp": "2024-01-15T10:30:00Z",
      "oldLevel": 4,
      "newLevel": 5,
      "reward": 50,
      "trigger": "step_progression",
      "stepIncrease": 15000
    }
  ],
  "lastLevelUpdate": "timestamp",
  "coins": 250
}
```

### **Level Up History Entry**
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "oldLevel": 4,
  "newLevel": 5,
  "reward": 50,
  "trigger": "step_progression|streak_milestone",
  "stepIncrease": 15000,
  "milestone": 7
}
```

## 🔧 Implementation Files

### **Core Services**
- `lib/services/leveling_service.dart` - Main leveling logic
- `lib/services/leveling_migration_service.dart` - Data migration
- `lib/widgets/level_display_widget.dart` - Level display UI
- `lib/widgets/level_up_notification.dart` - Level up notifications

### **Key Methods**
```dart
// Step progression level up
LevelingService.updateUserLevel(userId, stepIncrease)

// Streak level up (milestones + monthly)
LevelingService.checkStreakLevelUp(userId, newStreak)

// Get level information
LevelingService.getUserLevelInfo(userId)
```

## 📱 UI Components

### **Level Display Widget**
- Shows current level with progress
- Displays next milestone information
- Shows streak bonus potential

### **Level Up Notification**
- Animated celebration for each level up
- Shows reward earned
- Different messages for step vs streak triggers

## 🎯 Benefits of One-Level-at-a-Time System

### **1. Controlled Progression**
- Prevents overwhelming users with multiple level jumps
- Each level feels meaningful and earned
- Maintains long-term engagement

### **2. Clear Achievement Recognition**
- Users understand exactly what triggered their level up
- Celebration feels more personal and significant
- Reduces confusion about level progression

### **3. Balanced Rewards**
- Coin distribution is more predictable
- Prevents users from getting too many coins at once
- Maintains game economy balance

### **4. Social Engagement**
- Each level up is a shareable moment
- Friends can celebrate individual achievements
- Creates more frequent social interactions

## 🔮 Future Enhancements

### **Planned Features**
- **Level Up Animations**: Different animations for step vs streak level ups
- **Achievement Badges**: Special badges for milestone achievements
- **Social Sharing**: Share level up moments with friends
- **Level Challenges**: Special challenges for high-level users

### **Analytics Integration**
- **Level Distribution**: Track user level demographics
- **Trigger Analysis**: Analyze which triggers are most effective
- **Engagement Metrics**: Measure leveling impact on retention
- **Reward Optimization**: Fine-tune coin distribution

## 🛠️ Maintenance

### **Regular Tasks**
- **Data Validation**: Ensure level calculations are accurate
- **Performance Monitoring**: Track leveling system performance
- **User Feedback**: Collect feedback on leveling experience
- **Balance Adjustments**: Fine-tune level requirements and rewards

### **Troubleshooting**
- **Level Calculation Errors**: Verify step counting accuracy
- **Streak Synchronization**: Ensure streak data consistency
- **Reward Distribution**: Monitor coin reward delivery
- **Migration Issues**: Handle edge cases in user data migration

## 📋 Testing Checklist

### **Level Calculation**
- [ ] Base level calculation from total steps
- [ ] Step progression level up (one level only)
- [ ] Streak milestone level up (one level only)
- [ ] Progress percentage calculation

### **Data Migration**
- [ ] Existing user data initialization
- [ ] New user setup
- [ ] Data consistency validation
- [ ] Error handling

### **UI Components**
- [ ] Level display widget
- [ ] Level up notifications
- [ ] Progress bar accuracy
- [ ] Responsive design

### **Integration**
- [ ] Step tracking integration
- [ ] Streak system integration
- [ ] Coin reward system
- [ ] Database updates

This one-level-at-a-time system ensures that every level up is meaningful and celebrated, creating a more engaging and sustainable user experience while maintaining the hybrid approach of combining step progression and streak milestones. 