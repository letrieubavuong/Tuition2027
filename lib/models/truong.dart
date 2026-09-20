class Truong {
  int? id;
  String ten;

  Truong({this.id, required this.ten});

  Map<String, dynamic> toMap() {
    return {'id': id, 'ten': ten};
  }

  factory Truong.fromMap(Map<String, dynamic> map) {
    int? parseInt(dynamic v) =>
        v == null ? null : (v is int ? v : int.tryParse(v.toString()));
    return Truong(id: parseInt(map['id']), ten: map['ten']?.toString() ?? '');
  }

  Truong copyWith({int? id}) {
    return Truong(id: id ?? this.id, ten: ten);
  }
}
