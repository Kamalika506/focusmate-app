// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionConfigAdapter extends TypeAdapter<SessionConfig> {
  @override
  final int typeId = 0;

  @override
  SessionConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionConfig(
      topic: fields[0] as String,
      durationMinutes: fields[1] as int,
      breakIntervalMinutes: fields[2] as int,
      breakDurationMinutes: fields[3] as int,
      goal: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SessionConfig obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.topic)
      ..writeByte(1)
      ..write(obj.durationMinutes)
      ..writeByte(2)
      ..write(obj.breakIntervalMinutes)
      ..writeByte(3)
      ..write(obj.breakDurationMinutes)
      ..writeByte(4)
      ..write(obj.goal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
