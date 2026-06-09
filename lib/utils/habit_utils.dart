enum HabitType { pray, coldShower, shukrani, chakula, savings, workout, simple }

HabitType habitTypeFor(String name) {
  switch (name) {
    case 'Pray 2x':
      return HabitType.pray;
    case 'Cold Shower':
      return HabitType.coldShower;
    case 'Post Shukrani':
    case 'Tweet Shukrani':
    case 'Reddit Shukrani':
    case 'Post on Uncles':
      return HabitType.shukrani;
    case 'Work on Chakula':
      return HabitType.chakula;
    case 'Save Any Amount':
      return HabitType.savings;
    default:
      if (name.startsWith('Workout')) return HabitType.workout;
      return HabitType.simple;
  }
}

bool habitNeedsSheet(HabitType type) =>
    type != HabitType.pray && type != HabitType.simple;

String q5For(String habitName) {
  if (habitName == 'Pray 2x') {
    return "What does your relationship with God look like right now, honestly?";
  }
  if (habitName == 'Cold Shower') {
    return "What specifically are you trying to prove to yourself and why haven't you proved it yet?";
  }
  if (habitName == 'Work on Chakula') {
    return "What does Chakula look like in 12 months if you show up every day? And what does it look like if you don't?";
  }
  if (habitName == 'Post on Uncles') {
    return "Who specifically are you trying to reach and why does reaching them matter beyond followers?";
  }
  if (habitName == 'Post Shukrani' ||
      habitName == 'Tweet Shukrani' ||
      habitName == 'Reddit Shukrani') {
    return "You have roughly 100 users. What does consistent posting do for that number in 90 days?";
  }
  if (habitName == 'Save Any Amount') {
    return "What specific thing or security does this money represent? Name it.";
  }
  if (habitName.startsWith('Workout')) {
    return "What physical version of yourself are you trying to become and why haven't you started seriously before now?";
  }
  return "Why is this habit important to you long-term?";
}
