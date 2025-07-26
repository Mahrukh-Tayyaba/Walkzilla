# Walkzilla App Test Cases

## Test Case 1: App Launch and Onboarding Flow

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC001 |
| **Prerequisites** | Walkzilla app is installed on Android device |
| **Test Environment** | Android device (API level 21+) with internet connection |
| **Test Case Summary** | Verify that the app launches correctly with splash screen, displays onboarding screens, and transitions to authentication screen |
| **Actual Results** | App successfully launched with splash screen displaying logo animation for 3 seconds. Onboarding screens appeared sequentially with feature introductions. Smooth transition to authentication screen occurred after completing or skipping onboarding flow. |
| **Related Requirements** | Functional requirement: App Launch and Onboarding Flow |
| **Expected Results** | App should display splash screen with logo for 3 seconds, show 3 onboarding screens with feature introductions, and transition to login/signup screen |
| **Test Steps** | 1. Install Walkzilla app on Android device<br>2. Tap app icon to launch<br>3. Observe splash screen with logo animation<br>4. Wait for splash screen to complete (3 seconds)<br>5. Verify first onboarding screen appears with feature introduction<br>6. Swipe through onboarding screens 2 and 3<br>7. Tap "Get Started" or "Skip" button<br>8. Verify transition to authentication screen (login/signup) |
| **Test Status** | Pass |

## Test Case 2: User Login Functionality

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC002 |
| **Prerequisites** | User has registered account with valid email and password |
| **Test Environment** | Android device with internet connection and Firebase backend |
| **Test Case Summary** | Verify user can successfully log in with valid credentials and access home screen |
| **Actual Results** | User successfully entered valid email and password credentials. Firebase authentication completed successfully. User was redirected to home screen with profile data loaded correctly. Login process completed without errors. |
| **Related Requirements** | Functional requirement: User Authentication and Login |
| **Expected Results** | User should be able to enter email/password, get authenticated via Firebase, and be redirected to home screen with user data loaded |
| **Test Steps** | 1. Launch Walkzilla app<br>2. Navigate to login screen<br>3. Enter valid email address in email field<br>4. Enter correct password in password field<br>5. Tap "Login" button<br>6. Verify Firebase authentication process<br>7. Confirm successful login and redirect to home screen<br>8. Verify user profile data is displayed correctly |
| **Test Status** | Pass |

## Test Case 3: User Registration Process

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC003 |
| **Prerequisites** | User does not have existing account, valid email address available |
| **Test Environment** | Android device with internet connection and Firebase backend |
| **Test Case Summary** | Verify new user can create account with email, password, and username, then proceed to email verification |
| **Actual Results** | New user successfully entered valid email, strong password, and unique username. Firebase account creation completed successfully. User was redirected to email verification screen as expected. Verification email was received in inbox. |
| **Related Requirements** | Functional requirement: User Registration and Account Creation |
| **Expected Results** | User should be able to enter registration details, create account via Firebase, and be redirected to email verification screen |
| **Test Steps** | 1. Launch Walkzilla app<br>2. Navigate to signup screen<br>3. Enter valid email address<br>4. Enter strong password (8+ characters)<br>5. Enter unique username<br>6. Tap "Sign Up" button<br>7. Verify Firebase account creation<br>8. Confirm redirect to email verification screen<br>9. Check email for verification link |
| **Test Status** | Pass |

## Test Case 4: Password Reset Functionality

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC004 |
| **Prerequisites** | User has registered account with valid email address |
| **Test Environment** | Android device with internet connection and email access |
| **Test Case Summary** | Verify user can request password reset and receive reset link via email |
| **Actual Results** | User successfully entered registered email address. Firebase sent password reset email to user's inbox. Reset link was received and clicked successfully. New password was entered and updated in Firebase authentication system. Password reset process completed without errors. |
| **Related Requirements** | Functional requirement: Password Reset and Recovery |
| **Expected Results** | User should be able to enter email address, receive password reset link via email, and successfully reset password |
| **Test Steps** | 1. Launch Walkzilla app<br>2. Navigate to login screen<br>3. Tap "Forgot Password?" link<br>4. Enter registered email address<br>5. Tap "Send Reset Link" button<br>6. Verify Firebase sends reset email<br>7. Check email inbox for reset link<br>8. Click reset link in email<br>9. Enter new password<br>10. Verify password is successfully updated |
| **Test Status** | Pass |

## Test Case 5: Health Connect Permissions Request

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC005 |
| **Prerequisites** | Android device with Health Connect API available (API 26+) |
| **Test Environment** | Android device with Health Connect app installed |
| **Test Case Summary** | Verify app can request and receive Health Connect permissions for steps, heart rate, and calories tracking |
| **Actual Results** | Health Connect permission dialog appeared correctly when requested. User successfully granted permissions for steps, heart rate, and calories tracking. App confirmed permissions were granted and health tracking was activated. When permissions were denied, app requested permissions again as health data is essential for functionality. |
| **Related Requirements** | Functional requirement: Health Connect Permission Management |
| **Expected Results** | App should request Health Connect permissions, user should be able to grant permissions, and health tracking should be activated. If denied, app should request permissions again as health data is required for core functionality. |
| **Test Steps** | 1. Launch Walkzilla app<br>2. Complete login process<br>3. Navigate to health tracking section<br>4. Tap "Enable Health Tracking" button<br>5. Verify Health Connect permission dialog appears<br>6. Grant permissions for steps, heart rate, and calories<br>7. Confirm permissions are granted in app<br>8. Verify health tracking is activated<br>9. Test permission re-request by denying permissions initially<br>10. Verify app asks for permissions again since health data is essential |
| **Test Status** | Pass |

## Test Case 6: Real-time Step Tracking

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC006 |
| **Prerequisites** | Health Connect permissions granted, user logged in |
| **Test Environment** | Android device with step counting capability and internet connection |
| **Test Case Summary** | Verify app can retrieve and display real-time step data from Health Connect API on home screen |
| **Actual Results** | App successfully connected to Health Connect API and retrieved step data. Real-time step count updates were displayed correctly on home screen. Step data accuracy matched device step counter. When Health Connect was unable to connect, app prompted user to give access manually through device settings. |
| **Related Requirements** | Functional requirement: Real-time Step Data Tracking |
| **Expected Results** | App should connect to Health Connect API, retrieve step data, and display real-time step count on home screen. If Health Connect is unable to connect, app should prompt user to give access manually through device settings. |
| **Test Steps** | 1. Launch Walkzilla app and login<br>2. Ensure Health Connect permissions are granted<br>3. Navigate to home screen<br>4. Take several steps with device<br>5. Verify step count updates in real-time on home screen<br>6. Check step data accuracy against device step counter<br>7. Test app behavior when Health Connect is unavailable<br>8. Verify app prompts user to give access manually through settings<br>9. Test manual settings access flow |
| **Test Status** | Pass |

## Test Case 7: Solo Mode Game Play

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC007 |
| **Prerequisites** | User logged in, step tracking enabled |
| **Test Environment** | Android device with step counting and internet connection |
| **Test Case Summary** | Verify solo mode game loads correctly with animated character that responds to real step data |
| **Actual Results** | Solo mode interface loaded correctly with animated character displayed. Character animation responded properly to user's step progress. Character remained idle when no steps were taken. Game interface was responsive and performed well with different step counts. Solo mode functionality worked as expected. |
| **Related Requirements** | Functional requirement: Solo Mode Game with Character Animation |
| **Expected Results** | Solo mode should load with animated character, character should animate based on user's step progress, and game interface should be responsive |
| **Test Steps** | 1. Launch Walkzilla app and login<br>2. Navigate to solo mode section<br>3. Tap "Start Solo Mode" button<br>4. Verify solo mode interface loads correctly<br>5. Observe character animation on screen<br>6. Take steps and verify character movement responds to step data<br>7. Test character idle animation when no steps taken<br>8. Verify game performance and responsiveness<br>9. Test app behavior with different step counts |
| **Test Status** | Pass |

## Test Case 8: Duo Challenge Invitation and Gameplay

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC008 |
| **Prerequisites** | User logged in, has friends added, both users have app installed |
| **Test Environment** | Two Android devices with internet connection and Walkzilla app |
| **Test Case Summary** | Verify user can invite friends to duo challenges, friend can accept invitation, and real-time walking game begins |
| **Actual Results** | User successfully selected friend and sent challenge invitation. Friend received notification and accepted invitation. Duo challenge interface loaded correctly on both devices. Real-time step competition worked properly between users. Challenge completion and results were displayed accurately. Duo challenge functionality performed as expected. |
| **Related Requirements** | Functional requirement: Duo Challenge with Friend Invitation |
| **Expected Results** | User should be able to select friend, send challenge invitation, friend should receive and accept invitation, and duo challenge should begin with real-time competition |
| **Test Steps** | 1. Launch Walkzilla app on both devices and login<br>2. Ensure both users have each other as friends<br>3. On first device, navigate to duo challenge section<br>4. Select friend from friends list<br>5. Tap "Send Challenge" button<br>6. Verify challenge invitation is sent<br>7. On second device, check for incoming challenge notification<br>8. Accept challenge invitation<br>9. Verify duo challenge interface loads on both devices<br>10. Test real-time step competition between users<br>11. Verify challenge completion and results display |
| **Test Status** | Pass |

## Test Case 9: Mini-Games Functionality

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC009 |
| **Prerequisites** | User logged in, mini-games mode accessible |
| **Test Environment** | Android device with internet connection |
| **Test Case Summary** | Verify user can play daily mini-games including Flappy Dragon, 8-Puzzle, and 2048 Merge |
| **Actual Results** | System successfully randomly selected mini-games. Game interfaces loaded correctly for Flappy Dragon, 8-Puzzle, and 2048 Merge. All games were playable with proper controls and scoring. Default game loaded when selection failed. |
| **Related Requirements** | Functional requirement: Mini-Games with spin wheel |
| **Expected Results** | System should randomly select a mini-game, load game interface, and allow user to play. |
| **Test Steps** | 1. Launch Walkzilla app and login<br>2. Navigate to mini-games section<br>3. Tap "Play Mini-Games" button<br>4. Verify spin wheel system randomly selects a game<br>5. Test Flappy Dragon game interface and controls<br>6. Test 8-Puzzle game interface and controls<br>7. Test 2048 Merge game interface and controls<br>8. Verify scoring system works in all games<br>9. |
| **Test Status** | Pass |

## Test Case 10: Add Friends Functionality

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC010 |
| **Prerequisites** | User logged in, target friend has account |
| **Test Environment** | Android device with internet connection |
| **Test Case Summary** | Verify user can search for friends by username and send friend requests |
| **Actual Results** | User successfully searched for friend by username. System displayed search results correctly. Friend request was sent and delivered to target user. "User not found" message appeared when searching for non-existent username. |
| **Related Requirements** | Functional requirement: Friend Search and Request System |
| **Expected Results** | User should be able to search for friend by username, view search results, send friend request, and receive appropriate error messages for invalid searches. |
| **Test Steps** | 1. Launch Walkzilla app and login<br>2. Navigate to friends section<br>3. Tap "Add Friend" button<br>4. Enter valid username in search field<br>5. Verify search results are displayed<br>6. Select friend from results<br>7. Tap "Send Friend Request" button<br>8. Verify request is sent successfully<br>9. Test search with invalid username<br>10. Verify "User not found" message appears |
| **Test Status** | Pass |

## Test Case 11: Chat with Friends

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC011 |
| **Prerequisites** | User logged in, friend connection established |
| **Test Environment** | Two Android devices with internet connection and Walkzilla app |
| **Test Case Summary** | Verify users can send direct messages to friends through in-app chat system |
| **Actual Results** | User successfully opened chat with friend. Messages were typed and sent correctly. Messages were delivered to friend in real-time. Offline messages were stored and delivered when friend came online. Chat interface worked smoothly. |
| **Related Requirements** | Functional requirement: In-App Chat and Messaging |
| **Expected Results** | User should be able to open chat with friend, type and send messages, and have messages delivered. Offline messages should be stored and delivered when friend comes online. |
| **Test Steps** | 1. Launch Walkzilla app on both devices and login<br>2. Ensure both users are connected as friends<br>3. On first device, open friends list<br>4. Select friend to start chat<br>5. Type and send a message<br>6. Verify message appears in chat<br>7. On second device, check for received message<br>8. Reply to message from second device<br>9. Verify message history is maintained |
| **Test Status** | Pass |

## Test Case 12: View Leaderboard

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC012 |
| **Prerequisites** | User logged in, leaderboard data available |
| **Test Environment** | Android device with internet connection |
| **Test Case Summary** | Verify user can view leaderboards showing step counts |
| **Actual Results** | User successfully accessed leaderboard section. System retrieved and displayed friend data with current rankings. Step counts were shown correctly. Empty leaderboard message appeared when no users were available. |
| **Related Requirements** | Functional requirement: Leaderboard with Step Rankings |
| **Expected Results** | User should be able to access leaderboard, view friend data with rankings, and see step counts. Empty state should be handled appropriately. |
| **Test Steps** | 1. Launch Walkzilla app and login<br>2. Navigate to leaderboard section<br>3. Verify leaderboard loads with friend data<br>4. Check step count rankings are displayed<br>5. Verify user rankings are accurate<br>6. Test leaderboard refresh functionality<br>7. Verify empty leaderboard message when no data |
| **Test Status** | Pass |

## Test Case 13: View Health Dashboard

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC013 |
| **Prerequisites** | User logged in, health data available |
| **Test Environment** | Android device with Health Connect integration |
| **Test Case Summary** | Verify user can access detailed health analytics including steps, heart rate, calories, and progress charts |
| **Actual Results** | User successfully opened health dashboard. System retrieved and displayed health data correctly. Steps, heart rate, calories, and progress charts were shown with accurate analytics. Dashboard handled zero health data appropriately. |
| **Related Requirements** | Functional requirement: Health Analytics and Dashboard |
| **Expected Results** | User should be able to open health dashboard, view detailed analytics, and see progress charts. System should handle cases with zero health data appropriately. |
| **Test Steps** | 1. Launch Walkzilla app and login<br>2. Ensure Health Connect permissions are granted<br>3. Navigate to health dashboard section<br>4. Verify dashboard loads with health data<br>5. Check steps analytics are displayed<br>6. Verify heart rate data is shown<br>7. Test calories tracking display<br>8. Verify progress charts are functional<br>9. Test dashboard with zero health data<br>10. Verify data refresh functionality |
| **Test Status** | Pass |

## Test Case 14: Manage Profile & Settings

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC014 |
| **Prerequisites** | User logged in |
| **Test Environment** | Android device with internet connection |
| **Test Case Summary** | Verify user can update profile information, adjust app settings, manage notifications, and configure privacy preferences |
| **Actual Results** | User successfully opened profile settings. Profile information was updated correctly. App settings were modified and saved. Notification preferences were managed properly. Privacy settings were configured successfully. Validation errors appeared for invalid changes. |
| **Related Requirements** | Functional requirement: Profile Management and Settings |
| **Expected Results** | User should be able to open profile settings, modify settings, and save changes. System should show validation errors for invalid changes. |
| **Test Steps** | 1. Launch Walkzilla app and login<br>2. Navigate to profile section<br>3. Tap "Settings" button<br>4. Modify profile information<br>5. Adjust app settings<br>6. Manage notification preferences<br>7. Configure privacy settings<br>8. Save changes<br>9. Verify changes are applied<br>10. Test validation for invalid changes |
| **Test Status** | Pass |

## Test Case 15: Logout Functionality

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC015 |
| **Prerequisites** | User logged in |
| **Test Environment** | Android device with Firebase authentication |
| **Test Case Summary** | Verify user can log out securely via Firebase Authentication from profile screen |
| **Actual Results** | User successfully tapped logout button. System confirmed logout action. User was logged out securely via Firebase. User was redirected to login screen. Logout cancellation kept user logged in as expected. |
| **Related Requirements** | Functional requirement: Secure Logout and Session Management |
| **Expected Results** | User should be able to tap logout button, confirm logout, be logged out securely, and redirected to login screen. Logout cancellation should keep user logged in. |
| **Test Steps** | 1. Launch Walkzilla app and login<br>2. Navigate to profile screen<br>3. Tap "Logout" button<br>4. Verify logout confirmation dialog appears<br>5. Confirm logout action<br>6. Verify Firebase logout process<br>7. Check user is redirected to login screen<br>8. Test logout cancellation<br>9. Verify user remains logged in when cancelled |
| **Test Status** | Pass |

## Test Case 16: Access Shop

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC016 |
| **Prerequisites** | User logged in, shop access available |
| **Test Environment** | Android device with internet connection |
| **Test Case Summary** | Verify user can navigate to in-app shop to browse available items based on current level |
| **Actual Results** | User successfully tapped shop button. Shop interface loaded correctly. Items were displayed based on user's current level. Shop was accessible and functional. "Shop temporarily unavailable" message appeared when shop was unavailable. |
| **Related Requirements** | Functional requirement: In-App Shop with Level-based Items |
| **Expected Results** | User should be able to tap shop button, load shop interface, and view items based on current level. System should handle shop unavailability appropriately. |
| **Test Steps** | 1. Launch Walkzilla app and login<br>2. Navigate to shop section<br>3. Tap "Shop" button<br>4. Verify shop interface loads<br>5. Check items are displayed based on user level<br>6. Test shop navigation<br>7. Verify level-based item filtering<br>8. Test shop unavailability scenario<br>9. Verify error message appears when shop unavailable |
| **Test Status** | Pass |

## Test Case 17: View Shop Items

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC017 |
| **Prerequisites** | Shop is accessible |
| **Test Environment** | Android device with internet connection |
| **Test Case Summary** | Verify user can view available shop items categorized by level requirements with prices in coins |
| **Actual Results** | User successfully browsed shop items. Item details were displayed correctly with prices and requirements. Items were properly categorized by level requirements. "No items available" message appeared when no items were available. |
| **Related Requirements** | Functional requirement: Shop Item Display and Categorization |
| **Expected Results** | User should be able to browse shop items, view item details, prices, and requirements. Items should be categorized by level. System should handle empty shop appropriately. |
| **Test Steps** | 1. Launch Walkzilla app and login<br>2. Access shop section<br>3. Browse available shop items<br>4. Verify item details are displayed<br>5. Check prices are shown in coins<br>6. Verify level requirements are visible<br>7. Test item categorization by level<br>8. Verify item descriptions are accurate<br>9. Test empty shop scenario<br>10. Verify "No items available" message |
| **Test Status** | Pass |

## Test Case 18: Purchase Item

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC018 |
| **Prerequisites** | User has sufficient coins, item is unlocked |
| **Test Environment** | Android device with internet connection |
| **Test Case Summary** | Verify user can select unlocked item and purchase it using coins |
| **Actual Results** | User successfully selected item to purchase. System verified coin balance correctly. Purchase was completed successfully. Item was added to user's inventory. "Not enough coins" error appeared when insufficient coins were available. |
| **Related Requirements** | Functional requirement: Item Purchase and Coin Management |
| **Expected Results** | User should be able to select unlocked item, verify coin balance, complete purchase, and receive item in inventory. System should show error for insufficient coins. |
| **Test Steps** | 1. Launch Walkzilla app and login<br>2. Access shop section<br>3. Select unlocked item to purchase<br>4. Verify item details and price<br>5. Tap "Purchase" button<br>6. Verify coin balance check<br>7. Confirm purchase transaction<br>8. Check item is added to inventory<br>9. Test purchase with insufficient coins<br>10. Verify "Not enough coins" error |
| **Test Status** | Pass |

## Test Case 19: Level Up to Unlock Items

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC019 |
| **Prerequisites** | User achieves level up milestone |
| **Test Environment** | Android device with internet connection |
| **Test Case Summary** | Verify when user reaches new level, previously locked shop items become available |
| **Actual Results** | User successfully reached level up threshold. System updated user level correctly. New items were unlocked in shop. Shop was updated to show newly available items. Level up process completed without errors. |
| **Related Requirements** | Functional requirement: Level-based Item Unlocking |
| **Expected Results** | User should reach level up threshold, system should update user level, new items should be unlocked, and shop should be updated accordingly. |
| **Test Steps** | 1. Launch Walkzilla app and login<br>2. Track user progress toward level up<br>3. Achieve level up milestone<br>4. Verify system updates user level<br>5. Check new items are unlocked<br>6. Verify shop is updated with new items<br>7. Test item availability based on new level<br>8. Verify level up notification appears<br>9. Test level up failure scenario<br>10. Verify items remain locked if level up fails |
| **Test Status** | Pass |

## Test Case 20: Remove Friend

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC020 |
| **Prerequisites** | User logged in, has friends added |
| **Test Environment** | Android device with internet connection |
| **Test Case Summary** | Verify user can remove existing friend from friend list |
| **Actual Results** | User successfully opened friends list and selected a friend. "Remove Friend" option was available and functional. System prompted confirmation dialog. Friend was removed upon confirmation. "Select a user first" prompt appeared when no friend was selected. |
| **Related Requirements** | Functional requirement: Friend Management and Removal |
| **Expected Results** | User should be able to open friends list, select friend, choose remove option, confirm removal, and have friend removed from list. System should prompt to select user if none selected. |
| **Test Steps** | 1. Launch Walkzilla app and login<br>2. Navigate to friends section<br>3. Open friends list<br>4. Select a friend from the list<br>5. Tap "Remove Friend" option<br>6. Verify confirmation dialog appears<br>7. Confirm friend removal<br>8. Check friend is removed from list<br>9. Test removal without selecting friend<br>10. Verify "Select a user first" prompt appears |
| **Test Status** | Pass |
