const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Daily reward distribution
 * Runs every day at 12:00 AM to distribute daily rewards
 */
exports.distributeDailyRewards = functions.scheduler
  .onSchedule('0 0 * * *', async (event) => {
    try {
      console.log('Starting daily reward distribution...');
      
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      const yesterdayDate = yesterday.toISOString().split('T')[0]; // YYYY-MM-DD format
      
      // Get top 3 users for yesterday
      const dailySnapshot = await db.collection('users')
        .orderBy(`daily_steps.${yesterdayDate}`, 'desc')
        .limit(3)
        .get();
      
      if (dailySnapshot.empty) {
        console.log('No users found for daily rewards');
        return null;
      }
      
      const winners = [];
      const batch = db.batch();
      
      // Define daily rewards
      const rewards = [100, 75, 50]; // 1st, 2nd, 3rd place
      
      dailySnapshot.docs.forEach((doc, index) => {
        const userData = doc.data();
        const dailySteps = userData.daily_steps || {};
        const yesterdaySteps = dailySteps[yesterdayDate] || 0;
        const reward = rewards[index];
        
        winners.push({
          userId: doc.id,
          name: userData.username || userData.displayName || 'Unknown User',
          steps: yesterdaySteps,
          rank: index + 1,
          reward: reward,
        });
        
        // Add coins to user
        const currentCoins = userData.coins || 0;
        batch.update(doc.ref, {
          coins: currentCoins + reward,
        });
      });
      
      // Store daily leaderboard history
      const historyRef = db.collection('leaderboard_history').doc();
      batch.set(historyRef, {
        type: 'daily',
        date: yesterdayDate,
        winners: winners,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      
      // Send notifications to winners
      for (const winner of winners) {
        try {
          const userDoc = await db.collection('users').doc(winner.userId).get();
          const fcmToken = userDoc.data()?.fcmToken;
          
          if (fcmToken) {
            const rankText = winner.rank === 1 ? '1st' : winner.rank === 2 ? '2nd' : '3rd';
            const payload = {
              notification: {
                title: 'Daily Leaderboard Winner! 🏆',
                body: `Congratulations! You finished ${rankText} with ${winner.steps} steps and earned ${winner.reward} coins!`,
              },
              data: {
                type: 'daily_reward',
                rank: winner.rank.toString(),
                steps: winner.steps.toString(),
                coins: winner.reward.toString(),
                date: yesterdayDate,
              },
            };
            await admin.messaging().sendToDevice(fcmToken, payload);
          }
        } catch (error) {
          console.error(`Error sending notification to ${winner.userId}:`, error);
        }
      }
      
      console.log('Daily rewards distributed successfully:', winners);
      return { winners };
    } catch (error) {
      console.error('Error in daily reward distribution:', error);
      throw error;
    }
  });

/**
 * Weekly leaderboard reset and reward distribution
 * Runs every Monday at 12:01 AM
 */
exports.distributeWeeklyRewards = functions.scheduler
  .onSchedule('1 0 * * 1', async (event) => { // Monday at 12:01 AM
    try {
      console.log('Starting weekly reward distribution...');
      
      // Get top 3 users for the week
      const weeklySnapshot = await db.collection('users')
        .orderBy('weekly_steps', 'desc')
        .limit(3)
        .get();
      
      if (weeklySnapshot.empty) {
        console.log('No users found for weekly rewards');
        return null;
      }
      
      const winners = [];
      const batch = db.batch();
      const weekEndDate = new Date().toISOString().split('T')[0];
      
      // Define weekly rewards
      const rewards = [500, 350, 250]; // 1st, 2nd, 3rd place
      
      weeklySnapshot.docs.forEach((doc, index) => {
        const userData = doc.data();
        const reward = rewards[index];
        
        winners.push({
          userId: doc.id,
          name: userData.username || userData.displayName || 'Unknown User',
          steps: userData.weekly_steps || 0,
          rank: index + 1,
          reward: reward,
        });
        
        // Add coins to user
        const currentCoins = userData.coins || 0;
        batch.update(doc.ref, {
          coins: currentCoins + reward,
          last_week_rewarded: weekEndDate,
        });
      });
      
      // Store leaderboard history
      const historyRef = db.collection('leaderboard_history').doc();
      batch.set(historyRef, {
        type: 'weekly',
        date: weekEndDate,
        winners: winners,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Reset weekly steps for all users
      const allUsersSnapshot = await db.collection('users').get();
      allUsersSnapshot.docs.forEach(doc => {
        batch.update(doc.ref, {
          weekly_steps: 0,
        });
      });
      
      await batch.commit();
      
      // Send notifications to winners
      for (const winner of winners) {
        try {
          const userDoc = await db.collection('users').doc(winner.userId).get();
          const fcmToken = userDoc.data()?.fcmToken;
          
          if (fcmToken) {
            const rankText = winner.rank === 1 ? '1st' : winner.rank === 2 ? '2nd' : '3rd';
            const payload = {
              notification: {
                title: 'Weekly Leaderboard Winner! 🏆',
                body: `Congratulations! You finished ${rankText} this week with ${winner.steps} steps and earned ${winner.reward} coins!`,
              },
              data: {
                type: 'weekly_reward',
                rank: winner.rank.toString(),
                steps: winner.steps.toString(),
                coins: winner.reward.toString(),
                weekEndDate: weekEndDate,
              },
            };
            await admin.messaging().sendToDevice(fcmToken, payload);
          }
        } catch (error) {
          console.error(`Error sending notification to ${winner.userId}:`, error);
        }
      }
      
      console.log('Weekly rewards distributed successfully:', winners);
      return { winners };
    } catch (error) {
      console.error('Error in weekly reward distribution:', error);
      throw error;
    }
  });





/**
 * Get leaderboard data function
 */
exports.getLeaderboardData = functions.https.onCall(async (data, context) => {
  try {
    const type = data.type || 'daily'; // 'daily' or 'weekly'
    const limit = data.limit || 10;
    
    let query = db.collection('users');
    
    if (type === 'daily') {
      const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD format
      query = query.orderBy(`daily_steps.${today}`, 'desc');
    } else {
      query = query.orderBy('weekly_steps', 'desc');
    }
    
    const snapshot = await query.limit(limit).get();
    
    const leaderboard = snapshot.docs.map((doc, index) => {
      const userData = doc.data();
      let steps = 0;
      
      if (type === 'daily') {
        const today = new Date().toISOString().split('T')[0];
        const dailySteps = userData.daily_steps || {};
        steps = dailySteps[today] || 0;
      } else {
        steps = userData.weekly_steps || 0;
      }
      
      return {
        userId: doc.id,
        name: userData.username || userData.displayName || 'Unknown User',
        steps: steps,
        image: userData.profileImageUrl || null,
        rank: index + 1,
      };
    });
    
    return { leaderboard, type };
  } catch (error) {
    console.error('Error getting leaderboard data:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Initialize user leaderboard data (for new users)
 * Temporarily commented out due to deployment issues
 */
/*
exports.initializeUserLeaderboardData = functions.auth.user().onCreate(async (user) => {
  try {
    await db.collection('users').doc(user.uid).set({
      daily_steps: {},
      weekly_steps: 0,
      coins: 0,
      last_week_rewarded: null,
    }, { merge: true });
    
    console.log(`Initialized leaderboard data for user: ${user.uid}`);
  } catch (error) {
    console.error('Error initializing user leaderboard data:', error);
  }
});
*/ 