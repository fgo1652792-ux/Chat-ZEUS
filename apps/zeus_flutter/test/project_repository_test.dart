import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zeus_chat/chat/chat_repository.dart';
import 'package:zeus_chat/data/local_store.dart';
import 'package:zeus_chat/projects/project_repository.dart';

void main() {
  sqfliteFfiInit();

  test(
    'memory is scoped by project and disappears from context after removal',
    () async {
      final store = await LocalStore.open(
        factory: databaseFactoryFfi,
        name: inMemoryDatabasePath,
      );
      addTearDown(store.close);
      final projects = ProjectRepository(store);
      final chats = ChatRepository(store);
      await projects.create('Writing project', 'Keep the tone clear.');
      final project = (await projects.list()).single;
      final thread = await chats.create('Draft');
      final outside = await chats.create('Outside');
      await chats.moveToProject(thread.id, project.id);
      await projects.addMemory(project.id, 'Use Arabic technical terms.');
      expect(
        await projects.instructionsForThread(thread.id),
        contains('Use Arabic technical terms.'),
      );
      expect(await projects.instructionsForThread(outside.id), isEmpty);
      await projects.removeMemory((await projects.memories(project.id)).single);
      expect(
        await projects.instructionsForThread(thread.id),
        'Keep the tone clear.',
      );
      await projects.delete(project);
      expect(await projects.instructionsForThread(thread.id), isEmpty);
      expect(await chats.get(thread.id), isNotNull);
    },
  );
}
