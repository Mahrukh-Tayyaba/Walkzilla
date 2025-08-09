const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

// Import leaderboard functions
const leaderboardFunctions = require('./leaderboard_functions');

// Import automatic notification functions
const automaticNotifications = require('./automatic_notifications');

// Initialize Firebase Admin if not already initialized
if (!require("firebase-admin/app").getApps().length) {
  initializeApp();
}

exports.sendDuoChallengeInvite = onDocumentCreated(
  "duo_challenge_invites/{inviteId}",
  async (event) => {
    const snap = event.data;
    const invite = snap.data();
    const toUserId = invite.toUserId;
    const fromUserId = invite.fromUserId;
    const inviteId = event.params.inviteId;

    const db = getFirestore();
    const userDoc = await db.collection("users").doc(toUserId).get();
    const inviterDoc = await db.collection("users").doc(fromUserId).get();

    const fcmToken = userDoc.get("fcmToken");
    const inviterUsername = inviterDoc.get("username") || "Someone";

    if (fcmToken) {
      const message = {
        token: fcmToken,
        notification: {
          title: "Duo Challenge Invite",
          body: `${inviterUsername} is inviting you to a Duo Challenge!`,
        },
        data: {
          type: "duo_challenge_invite",
          inviterUsername,
          inviteId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'streak_notifications',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
      };
      await getMessaging().send(message);
    }

    return;
  }
);

// Export leaderboard functions
exports.distributeDailyRewards = leaderboardFunctions.distributeDailyRewards;
exports.distributeWeeklyRewards = leaderboardFunctions.distributeWeeklyRewards;
exports.getLeaderboardData = leaderboardFunctions.getLeaderboardData;
exports.initializeUserLeaderboardData = leaderboardFunctions.initializeUserLeaderboardData;

// Export automatic notification functions
exports.sendAutomaticNotifications = automaticNotifications.sendAutomaticNotifications;
exports.sendDailyFacts = automaticNotifications.sendDailyFacts;
exports.sendInactivityReminders = automaticNotifications.sendInactivityReminders;

// Notify when a user completes their daily goal (crosses the threshold)
exports.notifyDailyGoalCompleted = onDocumentUpdated("users/{userId}", async (event) => {
  try {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after) return null;

    const { getFirestore } = require('firebase-admin/firestore');
    const db = getFirestore();
    const userId = event.params.userId;

    const fcmToken = after.fcmToken;
    if (!fcmToken) return null;

    // Asia/Karachi today key
    const now = new Date();
    const todayKey = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Karachi',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(now);

    // Resolve effective goal from monthlyGoals[YYYY-MM].goalSteps → default 10000
    const monthKey = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Karachi',
      year: 'numeric',
      month: '2-digit',
    }).format(now);
    const monthlyGoals = after.monthlyGoals || {};
    const monthlyGoalObj = monthlyGoals[monthKey] || {};
    const goal = Number(typeof monthlyGoalObj.goalSteps !== 'undefined' ? monthlyGoalObj.goalSteps : 10000);

    const beforeStepsMap = (before && before.daily_steps) || {};
    const afterStepsMap = after.daily_steps || {};
    const beforeToday = Number(beforeStepsMap[todayKey] || 0);
    const afterToday = Number(afterStepsMap[todayKey] || 0);

    // Avoid duplicates with stored date flag
    if (after.dailyGoalCompletedDate === todayKey) return null;

    // Trigger when crossing the threshold
    if (beforeToday < goal && afterToday >= goal) {
      const { getMessaging } = require('firebase-admin/messaging');

      const message = {
        token: fcmToken,
        notification: {
          title: 'Daily Challenge Completed',
          body: `You've completed your daily step goal of ${goal} steps!`,
        },
        data: {
          type: 'daily_goal_completed',
          goal: goal.toString(),
          date: todayKey,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'streak_notifications',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
      };

      try {
        await getMessaging().send(message);
        await db.collection('users').doc(userId).update({ dailyGoalCompletedDate: todayKey });
      } catch (err) {
        // If token invalid, clear it
        if (err.code === 'messaging/invalid-registration-token' || err.code === 'messaging/registration-token-not-registered') {
          await db.collection('users').doc(userId).update({ fcmToken: null });
        }
      }
    }

    return null;
  } catch (e) {
    console.error('notifyDailyGoalCompleted error', e);
    return null;
  }
});
// One-time migration to remove dailyStepGoal field from all users
exports.migrateRemoveDailyStepGoal = require('firebase-functions/v2/https').onRequest(async (req, res) => {
  try {
    const { getFirestore } = require('firebase-admin/firestore');
    const db = getFirestore();
    const usersSnap = await db.collection('users').get();
    let updated = 0;
    const batch = db.batch();
    usersSnap.forEach((doc) => {
      batch.update(doc.ref, { dailyStepGoal: require('firebase-admin/firestore').FieldValue.delete() });
      updated++;
    });
    await batch.commit();
    res.status(200).send(`Removed dailyStepGoal from ${updated} user documents.`);
  } catch (e) {
    res.status(500).send(`Migration failed: ${e}`);
  }
});
