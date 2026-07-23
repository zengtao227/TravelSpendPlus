class Participant {
  final String id;
  final String name;

  const Participant({required this.id, required this.name});

  @override
  bool operator ==(Object other) => other is Participant && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
