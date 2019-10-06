import 'package:hacker_news/src/notifiers/worker.dart';
import 'package:test/test.dart';

void main() {
  test("worker spins up", () async {
    final worker = Worker();
    await worker.isReady;
    // expect(worker.fetchIds("hello"), completion([1, 2, 3]));
    worker.dispose();
  });
}
