// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_snapshot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanSnapshotAdapter extends TypeAdapter<ScanSnapshot> {
  @override
  final typeId = 0;

  @override
  ScanSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanSnapshot(
      subnet: fields[0] as String,
      hosts: (fields[1] as List).cast<String>(),
      timestamp: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ScanSnapshot obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.subnet)
      ..writeByte(1)
      ..write(obj.hosts)
      ..writeByte(2)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanSnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
