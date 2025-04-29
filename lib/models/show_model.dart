class ShowModel {
  final String id;
  final String title;
  final String posterUrl;
  final String genre;
  final String status; // watched, ongoing, upcoming

  ShowModel({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.genre,
    required this.status,
  });

  factory ShowModel.fromMap(Map<String, dynamic> map) {
    return ShowModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      posterUrl: map['poster_url'] ?? '',
      genre: map['genre'] ?? '',
      status: map['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'poster_url': posterUrl,
      'genre': genre,
      'status': status,
    };
  }
}
