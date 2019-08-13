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
  static const _baseUrl = 'https://hacker-news.firebaseio.com/v0/';

  final _isLoadingSubject = BehaviorSubject<bool>(seedValue: false);

  final _articlesSubject = BehaviorSubject<UnmodifiableListView<Article>>();

  var _articles = <Article>[];

  final _storiesTypeController = StreamController<StoriesType>();

  HackerNewsBloc() {
    _initializeArticles();

    _storiesTypeController.stream.listen((storiesType) async {
      _getArticlesAndUpdate(await _getIds(storiesType));
    });
  }

  Stream<UnmodifiableListView<Article>> get articles => _articlesSubject.stream;

  Stream<bool> get isLoading => _isLoadingSubject.stream;

  Sink<StoriesType> get storiesType => _storiesTypeController.sink;

  void close() {
    _storiesTypeController.close();
  }

  Future<Article> _getArticle(int id) async {
    final storyUrl = '${_baseUrl}item/$id.json';
    final storyRes = await http.get(storyUrl);
    if (storyRes.statusCode == 200) {
      return parseArticle(storyRes.body);
    }
    throw HackerNewsApiError("Article $id couldn't be fetched.");
  }

  _getArticlesAndUpdate(List<int> ids) async {
    _isLoadingSubject.add(true);
    await _updateArticles(ids);
    _articlesSubject.add(UnmodifiableListView(_articles));
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

  Future<void> _initializeArticles() async {
    _getArticlesAndUpdate(await _getIds(StoriesType.topStories));
  }

  Future<Null> _updateArticles(List<int> articleIds) async {
    final futureArticles = articleIds.map((id) => _getArticle(id));
    final articles = await Future.wait(futureArticles);
    _articles = articles;
  }
}

enum StoriesType {
  topStories,
  newStories,
}
