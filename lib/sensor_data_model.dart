class SensorData {
  String? x;
  String? y;
  String? z;
  String? dateTime;

  SensorData({this.x, this.y, this.z, this.dateTime});

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'x': x,
      'y': y,
      'z': z,
      'dateTime': dateTime,
    };
    return map;
  }

  SensorData.fromMap(Map<String, dynamic> map) {
    x = map['x'];
    y = map['y'];
    z = map['z'];
    dateTime = map['dateTime'];
  }
}