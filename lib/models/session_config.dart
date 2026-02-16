import 'package:hive/hive.dart';

part 'session_config.g.dart';

@HiveType(typeId: 0)
class SessionConfig {
  @HiveField(0)
  final String topic;

  @HiveField(1)
  final int durationMinutes;

  @HiveField(2)
  final int breakIntervalMinutes; // 0 means no breaks

  @HiveField(3)
  final int breakDurationMinutes;

  @HiveField(4)
  final String goal;

  const SessionConfig({
    required this.topic,
    required this.durationMinutes,
    this.breakIntervalMinutes = 0,
    this.breakDurationMinutes = 5,
    this.goal = '',
  });
}
