import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/cat_meme_model.dart';

export '../../models/cat_meme_model.dart';

class CatMemeService {
  static final CatMemeService instance = CatMemeService._();
  CatMemeService._();

  static const _subreddits = ['catmemes', 'CatsAreAssholes', 'cats'];
  static const _imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];

  List<CatMeme> _cache = [];
  int _cachePointer = 0;
  DateTime? _lastFetch;

  /// Returns a single cat meme, cycling through a cached batch.
  Future<CatMeme?> getNextMeme() async {
    if (_cache.isEmpty ||
        _lastFetch == null ||
        DateTime.now().difference(_lastFetch!).inMinutes > 10) {
      await _refreshCache();
    }
    if (_cache.isEmpty) return null;
    final meme = _cache[_cachePointer % _cache.length];
    _cachePointer++;
    return meme;
  }

  Future<void> _refreshCache() async {
    final memes = <CatMeme>[];
    for (final sub in _subreddits) {
      try {
        final uri = Uri.parse(
            'https://www.reddit.com/r/$sub/hot.json?limit=25&raw_json=1');
        final response = await http
            .get(uri, headers: {'User-Agent': 'expense_tracker_flutter/1.0'})
            .timeout(const Duration(seconds: 8));

        if (response.statusCode != 200) continue;

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final posts =
            (json['data']['children'] as List).cast<Map<String, dynamic>>();

        for (final post in posts) {
          final data = post['data'] as Map<String, dynamic>;
          final url = (data['url'] as String? ?? '').toLowerCase();
          if (!_imageExts.any((ext) => url.endsWith(ext))) continue;
          if (data['over_18'] == true) continue;

          memes.add(CatMeme(
            title: data['title'] as String,
            imageUrl: data['url'] as String,
            postUrl: 'https://reddit.com${data['permalink']}',
            upvotes: data['ups'] as int? ?? 0,
          ));
        }
      } catch (_) {
        // silently skip failed subreddits
      }
    }

    if (memes.isNotEmpty) {
      memes.shuffle();
      _cache = memes;
      _cachePointer = 0;
      _lastFetch = DateTime.now();
    }
  }
}
