const {onSchedule} = require("firebase-functions/v2/scheduler");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

// Initialize Firebase Admin if not already initialized
if (!require("firebase-admin/app").getApps().length) {
  initializeApp();
}

// Function to send automatic notifications
exports.sendAutomaticNotifications = onSchedule({
  schedule: '0 20 * * *', // Run at 8:00 PM daily (Asia/Karachi)
  timeZone: 'Asia/Karachi',
}, async (event) => {
  try {
    console.log('Automatic notification function triggered');
    
    const now = new Date();
    // Convert current time to Asia/Karachi timezone for accurate hour detection
    const nowInKarachi = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Karachi' }));
    const hour = nowInKarachi.getHours();

    // Only send the final (8 PM) notification
    if (hour !== 20) {
      console.log('Outside 8 PM notification hour (Asia/Karachi):', hour);
      return null;
    }

    // Get all users from Firestore
    const db = getFirestore();
    const usersSnapshot = await db
      .collection('users')
      .get();

    if (usersSnapshot.empty) {
      console.log('No users found');
      return null;
    }

    const batch = db.batch();
    let notificationCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      // Check if user has FCM token
      if (!userData.fcmToken) {
        console.log(`No FCM token for user ${userId}`);
        continue;
      }

      // Resolve effective goal: monthlyGoals[YYYY-MM].goalSteps -> default 10000
      const monthKey = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Asia/Karachi',
        year: 'numeric',
        month: '2-digit',
      }).format(now);
      const monthlyGoals = userData.monthlyGoals || {};
      const monthlyGoalObj = monthlyGoals[monthKey] || {};
      const effectiveGoal = Number(
        typeof monthlyGoalObj.goalSteps !== 'undefined'
          ? monthlyGoalObj.goalSteps
          : 10000
      );

      // Only send if goal not met at 8 PM
      {
        // Determine today's date key in Asia/Karachi timezone (YYYY-MM-DD)
        const todayKey = new Intl.DateTimeFormat('en-CA', {
          timeZone: 'Asia/Karachi',
          year: 'numeric',
          month: '2-digit',
          day: '2-digit',
        }).format(now);

        const dailyStepsMap = userData.daily_steps || {};
        const todaySteps = Number(dailyStepsMap[todayKey] || 0);

        if (todaySteps >= effectiveGoal) {
          console.log(`Skipping final notification for ${userId}: goal met (${todaySteps}/${effectiveGoal})`);
          continue;
        }
      }

      // Create notification message
      const title = '⏰ Streak in Danger!';
      const body = "You're running out of time to reach today's goal.";

      // Prepare notification payload
      const message = {
        token: userData.fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: 'final',
          goal: effectiveGoal.toString(),
          timestamp: Date.now().toString(),
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
        // Send notification
        const response = await getMessaging().send(message);
        console.log(`Notification sent to user ${userId}:`, response);
        notificationCount++;
      } catch (error) {
        console.error(`Failed to send notification to user ${userId}:`, error);
        
        // If FCM token is invalid, remove it from user document
        if (error.code === 'messaging/invalid-registration-token' || 
            error.code === 'messaging/registration-token-not-registered') {
          batch.update(userDoc.ref, { fcmToken: null });
        }
      }
    }

    // Commit batch updates
    await batch.commit();
    
    console.log(`Automatic notifications completed. Sent ${notificationCount} notifications.`);
    return { success: true, notificationsSent: notificationCount };
    
  } catch (error) {
    console.error('Error in automatic notification function:', error);
    return { success: false, error: error.message };
  }
});

// Daily Fact data (walking/health only, with user-provided messages, no emojis)
const FACT_CATEGORIES = {
  walking: [
    'Just 10 minutes of walking can boost your mood for hours. Ready to test it?',
    'The average person walks ~7,500 steps a day. Let’s beat that today.',
    'Walking 1 mile burns about 100 calories. Time to earn that snack.',
    'Regular walking lowers heart disease risk by 30%. Let’s go protect that ticker.',
    'The longest recorded walk was 19,019 miles! We’ll settle for a few hundred today.',
    'Walking boosts creativity by up to 60%. Maybe your next big idea is a few steps away.',
    'A brisk walk can add years to your life. Start investing now.',
    'Walking 20 minutes a day can cut fatigue by 65%. Energy upgrade, incoming.',
    'Your bones love walking, it keeps them strong and healthy.',
    'People who walk more smile more. Coincidence? Let’s find out.',
    'Walking just 30 minutes a day can improve your memory and brain function.',
    'Walking after meals helps control blood sugar levels.',
    'Walking outdoors can boost vitamin D and improve your mood.',
    'People who walk regularly sleep better at night.',
    'Walking improves posture and reduces back pain.',
    'Walking daily can help lower stress hormones by up to 15%.',
    'Walking is a weight-bearing exercise that strengthens muscles and bones.',
    'Brisk walking burns more fat than jogging at the same distance.',
    'Walking can reduce the risk of stroke by up to 27%.',
  ],
};

// Helper to get Asia/Karachi local date parts
function getKarachiNow() {
  const now = new Date();
  return new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Karachi' }));
}

// Inactivity reminder copy variations (light and friendly)
const INACTIVITY_TITLES = [
  '🕒 Time to Move',
  "Stretch Those Legs",
  "Beat the Couch",
  "Don't be a potato",
  "Your Steps Miss You",
  "Quick Walk Break?",
  "Don't Let the Day Sit Still",
];

const INACTIVITY_BODIES = [
  'Your shoes miss you. Take them out for a walk 🥿🚶',
  'Those steps won’t count themselves… unless you’re on a moving bus. 😉',
  'Your couch is winning. Time to fight back 💪',
  'Warning: Sitting too long may cause excessive scrolling 🤳. Walk a bit instead!',
  'Your step counter is bored. Make it happy!',
  'Imagine how proud your future self will be if you walk now 🏆',
  'Stand up, stretch, and take 100 steps. Your streak will thank you!',
  'Your leaderboard rivals hope you stay seated… Don’t give them that satisfaction 😏',
  'Even a short walk counts. Let’s go!',
  'This is your gentle reminder to stop being a potato 🥔',
];

function pickRandom(list) {
  return list[Math.floor(Math.random() * list.length)];
}

// Function to send one Daily Fact per user per day
exports.sendDailyFacts = onSchedule({
  schedule: '0 17 * * *', // 5:00 PM daily (Asia/Karachi)
  timeZone: 'Asia/Karachi',
}, async () => {
  try {
    const nowInKarachi = getKarachiNow();
    const db = getFirestore();

    // Determine today key and pick a fact deterministically
    const todayKey = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Karachi',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(nowInKarachi);

    const categories = Object.keys(FACT_CATEGORIES);
    const category = categories[(nowInKarachi.getDate() - 1) % categories.length];
    const list = FACT_CATEGORIES[category];
    const startOfYear = new Date(nowInKarachi.getFullYear(), 0, 1);
    const dayOfYear = Math.floor((nowInKarachi - startOfYear) / (1000 * 60 * 60 * 24)) + 1;
    const fact = list[dayOfYear % list.length];

    const usersSnapshot = await db.collection('users').get();
    if (usersSnapshot.empty) return null;

    const batch = db.batch();
    let sent = 0;

    for (const userDoc of usersSnapshot.docs) {
      const data = userDoc.data();
      const userId = userDoc.id;
      const token = data.fcmToken;
      if (!token) continue;

      const lastDate = data.lastDailyFactDate;
      if (lastDate === todayKey) continue; // already sent today

      const title = 'Did you know';

      const message = {
        token,
        notification: {
          title,
          body: fact,
        },
        data: {
          type: 'daily_fact',
          category,
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
        batch.update(userDoc.ref, {
          lastDailyFactDate: todayKey,
          lastDailyFactCategory: category,
        });
        sent++;
      } catch (error) {
        if (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') {
          batch.update(userDoc.ref, { fcmToken: null });
        }
      }
    }

    await batch.commit();
    console.log(`Daily facts sent: ${sent}`);
    return { success: true, sent };
  } catch (e) {
    console.error('Error sending daily facts', e);
    return { success: false, error: e.message };
  }
});

 
// Inactivity reminders: every 2 hours, notify if < 300 steps since last check
exports.sendInactivityReminders = onSchedule({
  schedule: '0 */2 * * *', // Every 2 hours
  timeZone: 'Asia/Karachi',
}, async () => {
  try {
    const nowInKarachi = getKarachiNow();
    const currentHour = nowInKarachi.getHours();
    // Quiet hours: skip 12:00 AM - 11:59 AM (Asia/Karachi)
    if (currentHour < 12) {
      console.log(`Skipping inactivity reminders during quiet hours (00:00-12:00), currentHour=${currentHour}`);
      return null;
    }
    const db = getFirestore();
    const todayKey = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Karachi',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(nowInKarachi);

    const usersSnapshot = await db.collection('users').get();
    if (usersSnapshot.empty) return null;

    const batch = db.batch();
    let sent = 0;

    for (const userDoc of usersSnapshot.docs) {
      const data = userDoc.data();
      const token = data.fcmToken;
      if (!token) continue;

      const dailyStepsMap = data.daily_steps || {};
      const todaySteps = Number(dailyStepsMap[todayKey] || 0);

      // Reset baseline if new day
      const lastDate = data.lastInactivityDate;
      if (lastDate !== todayKey) {
        batch.update(userDoc.ref, {
          lastInactivityDate: todayKey,
          lastInactivitySteps: todaySteps,
          lastInactivityTs: nowInKarachi.getTime(),
        });
        continue;
      }

      const lastSteps = Number(data.lastInactivitySteps || 0);
      const lastTs = Number(data.lastInactivityTs || 0);
      const elapsedMs = nowInKarachi.getTime() - lastTs;

      // Only evaluate if at least ~2 hours passed
      if (elapsedMs >= 2 * 60 * 60 * 1000) {
        const delta = todaySteps - lastSteps;
        if (delta < 300) {
          const title = pickRandom(INACTIVITY_TITLES);
          const body = pickRandom(INACTIVITY_BODIES);
          const message = {
            token,
            notification: {
              title,
              body,
            },
            data: {
              type: 'inactivity',
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
            sent++;
          } catch (error) {
            if (error.code === 'messaging/invalid-registration-token' ||
                error.code === 'messaging/registration-token-not-registered') {
              batch.update(userDoc.ref, { fcmToken: null });
            }
          }
        }

        // Update baseline regardless to measure next window
        batch.update(userDoc.ref, {
          lastInactivitySteps: todaySteps,
          lastInactivityTs: nowInKarachi.getTime(),
          lastInactivityDate: todayKey,
        });
      }
    }

    await batch.commit();
    console.log(`Inactivity reminders sent: ${sent}`);
    return { success: true, sent };
  } catch (e) {
    console.error('Error sending inactivity reminders', e);
    return { success: false, error: e.message };
  }
});
