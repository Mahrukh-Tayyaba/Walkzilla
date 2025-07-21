# Walkzilla App Test Cases

## Test Case 1: App Launch and Onboarding

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC01 |
| **Prerequisites** | Walkzilla app is installed on the device |
| **Test Environment** | Android device with internet connection |
| **Test Case Summary** | Verify that the app launches correctly, displays splash screen, shows onboarding screens, and transitions to authentication |
| **Actual Results** | [To be filled during testing] |
| **Related Requirements** | UC01 – Launch App |
| **Expected Results** | App should launch, show splash screen for 3 seconds, display 3 onboarding screens, and transition to authentication screen |
| **Test Steps** | 1. Tap the Walkzilla app icon on device 2. Observe splash screen with logo appears<br>3. Wait for splash screen to complete (3 seconds)<br>4. Verify first onboarding screen appears<br>5. Swipe through onboarding screens 2 and 3<br>6. Verify authentication screen appears after onboarding |
| **Test Status** | [Pass/Fail/Blocked/Not Run] |

## Test Case 2: User Login Functionality

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC02 |
| **Prerequisites** | User has a registered account, app is launched and authentication screen is displayed |
| **Test Environment** | Android device with internet connection, Firebase backend active |
| **Test Case Summary** | Verify that users can successfully log in using valid email and password credentials |
| **Actual Results** | [To be filled during testing] |
| **Related Requirements** | UC02 – User Login |
| **Expected Results** | User should be successfully logged in and redirected to home screen |
| **Test Steps** | 1. Navigate to login screen<br>2. Enter valid email address<br>3. Enter valid password<br>4. Tap login button<br>5. Verify Firebase authentication processes credentials<br>6. Confirm user is redirected to home screen |
| **Test Status** | [Pass/Fail/Blocked/Not Run] |

## Test Case 3: New User Registration

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC03 |
| **Prerequisites** | App is launched, user does not have existing account |
| **Test Environment** | Android device with internet connection, Firebase backend active |
| **Test Case Summary** | Verify that new users can successfully create accounts with email, password, and username |
| **Actual Results** | [To be filled during testing] |
| **Related Requirements** | UC03 – User Signup |
| **Expected Results** | New account should be created in Firebase and user redirected to home screen |
| **Test Steps** | 1. Navigate to signup screen<br>2. Enter unique email address<br>3. Enter secure password<br>4. Enter unique username<br>5. Tap signup button<br>6. Verify Firebase creates new account<br>7. Confirm user is redirected to home screen |
| **Test Status** | [Pass/Fail/Blocked/Not Run] |

## Test Case 4: Password Reset Functionality

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC04 |
| **Prerequisites** | User has registered account, app is launched |
| **Test Environment** | Android device with internet connection, Firebase backend active |
| **Test Case Summary** | Verify that users can request password reset and receive email with reset instructions |
| **Actual Results** | [To be filled during testing] |
| **Related Requirements** | UC04 – Forgot Password |
| **Expected Results** | Password reset link should be sent to user's email address |
| **Test Steps** | 1. Navigate to forgot password screen<br>2. Enter registered email address<br>3. Tap reset password button<br>4. Verify Firebase sends reset email<br>5. Check user's email for reset link |
| **Test Status** | [Pass/Fail/Blocked/Not Run] |

## Test Case 5: Health Connect Permissions

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC05 |
| **Prerequisites** | App is installed, Health Connect is available on device, user is logged in |
| **Test Environment** | Android device with Health Connect API, internet connection |
| **Test Case Summary** | Verify that users can grant Health Connect permissions for steps, heart rate, and calories tracking |
| **Actual Results** | [To be filled during testing] |
| **Related Requirements** | UC05 – Request Health Permissions |
| **Expected Results** | Health Connect permissions should be granted and health tracking activated |
| **Test Steps** | 1. Navigate to health permissions screen<br>2. Tap request permissions button<br>3. Verify Health Connect permission dialog appears<br>4. Grant permissions for steps, heart rate, and calories<br>5. Confirm health tracking is activated in app |
| **Test Status** | [Pass/Fail/Blocked/Not Run] |

## Test Case 6: Real-time Step Tracking

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC06 |
| **Prerequisites** | Health Connect permissions are granted, user is logged in |
| **Test Environment** | Android device with Health Connect API, internet connection |
| **Test Case Summary** | Verify that the app displays real-time step data from Health Connect API on home screen |
| **Actual Results** | [To be filled during testing] |
| **Related Requirements** | UC06 – Track Steps |
| **Expected Results** | Step data should be retrieved from Health Connect and displayed on home screen |
| **Test Steps** | 1. Ensure Health Connect permissions are granted<br>2. Navigate to home screen<br>3. Verify app connects to Health Connect API<br>4. Take several steps with device<br>5. Confirm step data updates in real-time on home screen |
| **Test Status** | [Pass/Fail/Blocked/Not Run] |

## Test Case 7: Streak Achievement and Coin Rewards

| Field | Description |
|-------|-------------|
| **Test Case Id** | TC07 |
| **Prerequisites** | User is logged in, step tracking is active, daily step goal is set |
| **Test Environment** | Android device with internet connection, Firebase backend active |
| **Test Case Summary** | Verify that when daily step goal is reached, streak is marked and coins are awarded |
| **Actual Results** | [To be filled during testing] |
| **Related Requirements** | UC07 – Mark Streak & Award Coins |
| **Expected Results** | Streak counter should increment and coins should be awarded with achievement notification |
| **Test Steps** | 1. Set daily step goal<br>2. Walk to reach the daily step goal<br>3. Verify system detects goal achievement<br>4. Confirm streak counter increments<br>5. Verify coins are awarded to user account<br>6. Check achievement notification appears |
| **Test Status** | [Pass/Fail/Blocked/Not Run] | 