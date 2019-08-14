import 'dart:async';
import 'dart:collection';

import 'package:hacker_news/src/article.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

class HackerNewsApiError extends Error {
  final String message;

  HackerNewsApiError(this.message);
}

class HackerNewsBloc {
  Map<int, Article> _cachedArticles;
  static const _baseUrl = 'https://hacker-news.firebaseio.com/v0/';

  final _isLoadingSubject = BehaviorSubject<bool>(seedValue: false);

  final _topArticlesSubject = BehaviorSubject<UnmodifiableListView<Article>>();
  final _newArticlesSubject = BehaviorSubject<UnmodifiableListView<Article>>();

  var _articles = <Article>[];

  final _storiesTypeController = StreamController<StoriesType>();

  HackerNewsBloc() : _cachedArticles = Map() {
    _initializeArticles();

    _storiesTypeController.stream.listen((storiesType) async {
      _getArticlesAndUpdate(
          _newArticlesSubject, await _getIds(StoriesType.newStories));
      _getArticlesAndUpdate(
          _topArticlesSubject, await _getIds(StoriesType.topStories));
    });
  }

  Stream<UnmodifiableListView<Article>> get topArticles =>
      _topArticlesSubject.stream;

  Stream<UnmodifiableListView<Article>> get newArticles =>
      _newArticlesSubject.stream;

  Stream<bool> get isLoading => _isLoadingSubject.stream;

  Sink<StoriesType> get storiesType => _storiesTypeController.sink;

  Future<void> _initializeArticles() async {
    _getArticlesAndUpdate(
        _newArticlesSubject, await _getIds(StoriesType.newStories));
    _getArticlesAndUpdate(
        _topArticlesSubject, await _getIds(StoriesType.topStories));
  }

  void close() {
    _storiesTypeController.close();
    _topArticlesSubject.close();
    _newArticlesSubject.close();
  }

  Future<Article> _getArticle(int id) async {
    if (!_cachedArticles.containsKey(id)) {
      final storyUrl = '${_baseUrl}item/$id.json';
      final storyRes = await http.get(storyUrl);
      if (storyRes.statusCode == 200) {
        _cachedArticles[id] = parseArticle(storyRes.body);
      } else {
        throw HackerNewsApiError("Article $id couldn't be fetched.");
      }
    }
    return _cachedArticles[id];
  }

  _getArticlesAndUpdate(BehaviorSubject<UnmodifiableListView<Article>> subject,
      List<int> ids) async {
    _isLoadingSubject.add(true);
    await _updateArticles(ids);

    subject.add(UnmodifiableListView(_articles));
    _isLoadingSubject.add(false);
  }

  Future<List<int>> _getIds(StoriesType type) async {
    final partUrl = type == StoriesType.topStories ? 'top' : 'new';
    final url = '$_baseUrl${partUrl}stories.json';
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw HackerNewsApiError("Stories $type couldn't be fetched.");
    }
    return parseTopStories(response.body).take(10).toList();
  }

  Future<Null> _updateArticles(List<int> articleIds) async {
    final futureArticles = articleIds.map((id) => _getArticle(id));
    final all = await Future.wait(futureArticles);
    final filtered = all.where((a) => a.title != null).toList();
    _articles = filtered;
  }
}

enum StoriesType {
  topStories,
  newStories,
}
