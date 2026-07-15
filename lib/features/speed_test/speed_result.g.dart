// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speed_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SpeedResultAdapter extends TypeAdapter<SpeedResult> {
  @override
  final typeId = 1;

  @override
  SpeedResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SpeedResult(
      downloadMbps: (fields[0] as num).toDouble(),
      uploadMbps: (fields[1] as num).toDouble(),
      latencyMs: (fields[2] as num).toInt(),
      timestamp: fields[3] as DateTime,
      provider: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SpeedResult obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.downloadMbps)
      ..writeByte(1)
      ..write(obj.uploadMbps)
      ..writeByte(2)
      ..write(obj.latencyMs)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.provider);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeedResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
