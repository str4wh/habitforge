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
