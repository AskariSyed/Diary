class NoteDto {
  final int id;
  final String description;

  NoteDto({required this.id, required this.description});

  factory NoteDto.fromJson(Map<String, dynamic> json) {
    return NoteDto(id: json['id'], description: json['description']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'description': description};
  }
}
