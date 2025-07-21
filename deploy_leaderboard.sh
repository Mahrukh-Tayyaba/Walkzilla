#!/bin/bash

echo "🚀 Deploying Leaderboard System..."

# Step 1: Deploy Cloud Functions
echo "📦 Deploying Cloud Functions..."
cd functions
npm install
firebase deploy --only functions

# Step 2: Deploy Firestore Rules
echo "🔒 Deploying Firestore Rules..."
cd ..
firebase deploy --only firestore:rules

# Step 3: Update Firestore Rules with leaderboard rules
echo "📋 Updating Firestore Rules..."
cat leaderboard_rules.rules >> firestore.rules

echo "✅ Leaderboard System Deployment Complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Open your Flutter app"
echo "2. Go to Admin Panel (in drawer menu)"
echo "3. Click 'Initialize All Users'"
echo "4. Click 'Create Sample Data' (for testing)"
echo "5. Test the leaderboard functionality"
echo ""
echo "🎯 The system will now:"
echo "- Aggregate steps daily at 11:59 PM"
echo "- Distribute weekly rewards every Monday at 12:01 AM"
echo "- Distribute monthly rewards on the 1st at 12:01 AM" 