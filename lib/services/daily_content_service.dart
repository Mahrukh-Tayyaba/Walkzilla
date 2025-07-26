class DailyContentService {
  static final DailyContentService _instance = DailyContentService._internal();
  factory DailyContentService() => _instance;
  DailyContentService._internal();

  // Daily tips for different screens
  final List<String> _stepTips = [
    'Walking 10,000 steps daily helps maintain good cardiovascular health.',
    'Taking the stairs instead of the elevator can add 500+ steps to your daily count.',
    'Walking meetings can boost creativity and step count simultaneously.',
    'Parking farther from your destination is an easy way to increase daily steps.',
    'Walking after meals helps with digestion and contributes to your step goal.',
    'Using a standing desk can encourage more movement throughout the day.',
    'Walking with friends or family makes exercise more enjoyable and motivating.',
    'Setting hourly step reminders can help you stay on track throughout the day.',
    'Walking in nature has additional mental health benefits beyond physical exercise.',
    'Tracking your steps can reveal patterns and help optimize your daily routine.',
  ];

  final List<String> _calorieTips = [
    'Walking burns approximately 100 calories per mile for an average person.',
    'The more you weigh, the more calories you burn while walking.',
    'Walking uphill burns significantly more calories than walking on flat ground.',
    'Walking at a brisk pace burns more calories than walking slowly.',
    'Morning walks can boost your metabolism for the entire day.',
    'Walking in cold weather burns more calories as your body works to stay warm.',
    'Carrying a backpack while walking increases calorie burn.',
    'Walking barefoot on sand burns more calories than walking on pavement.',
    'Interval walking (alternating fast and slow paces) maximizes calorie burn.',
    'Walking after strength training can help burn additional calories.',
  ];

  final List<String> _distanceTips = [
    'Walking 1 mile typically takes about 2,000 steps for most people.',
    'The average person walks about 3,000-4,000 steps per day naturally.',
    'Walking 5 miles daily can significantly improve cardiovascular health.',
    'Distance walking helps build endurance and stamina over time.',
    'Walking different routes can make distance goals more interesting.',
    'Tracking distance can help you discover new areas in your neighborhood.',
    'Walking in nature trails often feels shorter than walking the same distance on roads.',
    'Breaking up long distances into smaller segments makes goals more achievable.',
    'Walking with a purpose (like errands) makes distance goals feel more natural.',
    'Gradually increasing distance each week is the safest approach to building endurance.',
  ];

  // Fun facts for different screens
  final List<String> _stepFunFacts = [
    'The average person takes about 6,000-8,000 steps per day.',
    'Walking 10,000 steps is roughly equivalent to walking 5 miles.',
    'The world record for most steps in 24 hours is over 300,000 steps!',
    'Your feet contain about 25% of all the bones in your body.',
    'Walking barefoot can strengthen the muscles in your feet and ankles.',
    'The average person walks about 115,000 miles in their lifetime.',
    'Walking can help reduce stress and improve mood through endorphin release.',
    'Walking backwards burns more calories than walking forwards.',
    'The longest walk ever recorded was 14,000 miles across 14 countries.',
    'Walking can help improve memory and cognitive function.',
  ];

  final List<String> _calorieFunFacts = [
    'Walking 10,000 steps burns approximately 400-500 calories!',
    'You burn calories even while sleeping - about 50-100 calories per hour.',
    'Laughing for 10 minutes can burn up to 40 calories.',
    'Chewing gum burns about 11 calories per hour.',
    'Standing burns more calories than sitting - about 50 more calories per hour.',
    'Cold water burns more calories as your body works to warm it up.',
    'Your brain uses about 20% of your daily calorie intake.',
    'Walking uphill burns 3-5 times more calories than walking on flat ground.',
    'Muscle tissue burns more calories at rest than fat tissue.',
    'Walking in water burns more calories than walking on land due to resistance.',
  ];

  final List<String> _distanceFunFacts = [
    'Walking 10,000 steps equals about 5 miles or 8 kilometers.',
    'The average person walks about 75,000 miles in their lifetime.',
    'Walking around the Earth would take about 20,000,000 steps.',
    'The longest walkable distance on Earth is about 14,000 miles.',
    'Walking can help you explore your city - most people live within 2 miles of interesting places.',
    'Walking 1 mile burns roughly the same calories as running 1 mile, just takes longer.',
    'Walking in nature can reduce stress hormones by up to 16%.',
    'Walking can help you discover hidden gems in your neighborhood.',
    'Walking with a dog can increase your daily distance by up to 2,000 steps.',
    'Walking meetings can increase creativity by up to 8.5%.',
  ];

  // Get daily content based on current date and screen type
  String getDailyTip(String screenType) {
    final today = DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;

    List<String> tips;
    switch (screenType.toLowerCase()) {
      case 'steps':
        tips = _stepTips;
        break;
      case 'calories':
        tips = _calorieTips;
        break;
      case 'distance':
        tips = _distanceTips;
        break;
      default:
        tips = _stepTips;
    }

    return tips[dayOfYear % tips.length];
  }

  String getDailyFunFact(String screenType) {
    final today = DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;

    List<String> funFacts;
    switch (screenType.toLowerCase()) {
      case 'steps':
        funFacts = _stepFunFacts;
        break;
      case 'calories':
        funFacts = _calorieFunFacts;
        break;
      case 'distance':
        funFacts = _distanceFunFacts;
        break;
      default:
        funFacts = _stepFunFacts;
    }

    return funFacts[dayOfYear % funFacts.length];
  }

  // Get content for a specific date (useful for testing)
  String getTipForDate(String screenType, DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;

    List<String> tips;
    switch (screenType.toLowerCase()) {
      case 'steps':
        tips = _stepTips;
        break;
      case 'calories':
        tips = _calorieTips;
        break;
      case 'distance':
        tips = _distanceTips;
        break;
      default:
        tips = _stepTips;
    }

    return tips[dayOfYear % tips.length];
  }

  String getFunFactForDate(String screenType, DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;

    List<String> funFacts;
    switch (screenType.toLowerCase()) {
      case 'steps':
        funFacts = _stepFunFacts;
        break;
      case 'calories':
        funFacts = _calorieFunFacts;
        break;
      case 'distance':
        funFacts = _distanceFunFacts;
        break;
      default:
        funFacts = _stepFunFacts;
    }

    return funFacts[dayOfYear % funFacts.length];
  }
}
