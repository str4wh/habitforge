class WorkoutData {
  final int pushups;
  final int situps;
  final int jumpingJacks;

  const WorkoutData({
    required this.pushups,
    required this.situps,
    required this.jumpingJacks,
  });

  factory WorkoutData.fromMap(Map<String, dynamic> map) => WorkoutData(
        pushups: (map['pushups'] as num?)?.toInt() ?? 0,
        situps: (map['situps'] as num?)?.toInt() ?? 0,
        jumpingJacks: (map['jumpingJacks'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'pushups': pushups,
        'situps': situps,
        'jumpingJacks': jumpingJacks,
      };

  bool get isComplete => pushups > 0 && situps > 0 && jumpingJacks > 0;
}
