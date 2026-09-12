class Truong {
  int? id;
  String ten;

  Truong({this.id, required this.ten});

  Map<String, dynamic> toMap() {
    return {'id': id, 'ten': ten};
  }

  factory Truong.fromMap(Map<String, dynamic> map) {
    return Truong(id: map['id'] as int?, ten: map['ten'] as String);
  }

  Truong copyWith({int? id}) {
    return Truong(id: id ?? this.id, ten: ten);
  }
}
