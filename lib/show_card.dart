import 'package:flutter/material.dart';
import '../../models/show_model.dart';

class ShowCard extends StatelessWidget {
  final ShowModel show;

  const ShowCard({Key? key, required this.show}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Image.network(show.posterUrl,
            width: 50, height: 50, fit: BoxFit.cover),
        title: Text(show.title),
        subtitle: Text('${show.genre} • ${show.status}'),
      ),
    );
  }
}
