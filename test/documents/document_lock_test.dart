import 'dart:convert';
import 'dart:io';

import 'package:flowmap/src/features/documents/data/document_lock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The lock's easy case is *"Matheus has this open"*. Its hard case is a lock
/// left by a crash, a power cut or a dropped VPN — on a drive where nobody can
/// check whether that app is still running.
///
/// So most of what is asserted here is about the stale path, because that is
/// the one a person would otherwise have to reason about.
void main() {
  late Directory dir;
  late String doc;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('flowmap_lock');
    doc = p.join(dir.path, 'Celula-11.flowmap');
    File(doc).writeAsBytesSync([0]);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('the lock sits beside the document, not inside it', () async {
    final lock = await DocumentLock.acquire(doc, user: 'matheus', machine: 'ENG-04');
    addTearDown(() => lock!.release());

    expect(lock, isNotNull);
    expect(p.basename(lock!.file.path), 'Celula-11.flowmap.lock');
    expect(lock.file.parent.path, p.dirname(doc));
    // The document itself is untouched: it has to stay a single file that can
    // be copied, mailed and renamed without carrying a session around with it.
    expect(File(doc).lengthSync(), 1);
  });

  test('a second person is told who holds it, and is refused', () async {
    final first = await DocumentLock.acquire(doc, user: 'matheus', machine: 'ENG-04');
    addTearDown(() => first!.release());

    final second = await DocumentLock.acquire(doc, user: 'ana', machine: 'ENG-09');
    expect(second, isNull);

    final holder = DocumentLock.holderOf(doc);
    expect(holder, isNotNull);
    expect(holder!.describe(), 'matheus (ENG-04)');
  });

  test('a lock nobody has refreshed goes stale on its own', () async {
    final now = DateTime(2026, 9, 12, 14, 0);
    await DocumentLock.acquire(
      doc,
      user: 'matheus',
      machine: 'ENG-04',
      now: now,
    );

    // Just inside the window: still theirs.
    expect(
      DocumentLock.holderOf(doc, now: now.add(const Duration(minutes: 4))),
      isNotNull,
    );

    // Past it: the file is simply available. Nobody is asked to break anything,
    // which is the whole point — a crash heals itself in minutes rather than
    // leaving a document nobody dares open.
    expect(
      DocumentLock.holderOf(doc, now: now.add(const Duration(minutes: 6))),
      isNull,
    );
    final taken = await DocumentLock.acquire(
      doc,
      user: 'ana',
      machine: 'ENG-09',
      now: now.add(const Duration(minutes: 6)),
    );
    addTearDown(() => taken!.release());
    expect(taken, isNotNull);
    expect(
      DocumentLock.holderOf(doc, now: now.add(const Duration(minutes: 6)))!
          .describe(),
      'ana (ENG-09)',
    );
  });

  test('the stale window is several heartbeats, not one', () {
    // One missed refresh is a slow disk or a laptop lid. The window has to
    // tolerate that and still free a dead process quickly.
    expect(
      DocumentLock.staleAfter.inMinutes,
      greaterThanOrEqualTo(DocumentLock.heartbeat.inMinutes * 3),
    );
  });

  test('touching it keeps it', () async {
    final start = DateTime(2026, 9, 12, 14, 0);
    final lock = await DocumentLock.acquire(
      doc,
      user: 'matheus',
      machine: 'ENG-04',
      now: start,
    );
    addTearDown(() => lock!.release());

    final later = start.add(const Duration(minutes: 4));
    await lock!.touch(now: later);

    // Six minutes after the *original* stamp, but two after the refresh.
    expect(
      DocumentLock.holderOf(doc, now: start.add(const Duration(minutes: 6))),
      isNotNull,
    );
  });

  test('releasing frees it immediately', () async {
    final lock = await DocumentLock.acquire(doc, user: 'matheus', machine: 'ENG-04');
    await lock!.release();

    expect(lock.file.existsSync(), isFalse);
    expect(DocumentLock.holderOf(doc), isNull);
    final next = await DocumentLock.acquire(doc, user: 'ana', machine: 'ENG-09');
    addTearDown(() => next!.release());
    expect(next, isNotNull);
  });

  test('releasing twice, or with the file already gone, is harmless', () async {
    final lock = await DocumentLock.acquire(doc, user: 'matheus', machine: 'ENG-04');
    await lock!.release();
    lock.file.parent.createSync(recursive: true);
    await expectLater(lock.release(), completes);
  });

  test('a lock that cannot be read counts as absent', () async {
    // A corrupt or truncated lock must never be the thing that stops someone
    // opening their own work.
    File(DocumentLock.lockPathFor(doc)).writeAsStringSync('}{ not json');
    expect(DocumentLock.holderOf(doc), isNull);

    final lock = await DocumentLock.acquire(doc, user: 'ana', machine: 'ENG-09');
    addTearDown(() => lock!.release());
    expect(lock, isNotNull);
  });

  test('a lock missing its fields still names someone', () {
    File(DocumentLock.lockPathFor(doc)).writeAsStringSync(
      jsonEncode({'touched': DateTime.now().toIso8601String()}),
    );
    final holder = DocumentLock.holderOf(doc);
    expect(holder, isNotNull);
    // Vague, and still a sentence a person can act on — better than a blank.
    expect(holder!.describe(), 'someone (another machine)');
  });

  test('a lock with no timestamp at all is stale, not eternal', () {
    File(DocumentLock.lockPathFor(doc)).writeAsStringSync(
      jsonEncode({'user': 'matheus', 'machine': 'ENG-04'}),
    );
    // The dangerous failure would be the other way: a lock that can never
    // expire is a document nobody can ever open again.
    expect(DocumentLock.holderOf(doc), isNull);
  });

  test('touching a lock on a drive that has gone away does not throw', () async {
    final lock = await DocumentLock.acquire(doc, user: 'matheus', machine: 'ENG-04');
    addTearDown(() => lock!.release());
    await lock!.file.delete();
    dir.deleteSync(recursive: true);

    // The app must not die mid-edit because a share dropped. The lock stops
    // being refreshed and goes stale by itself, which is the same outcome as
    // the process dying and the right one.
    await expectLater(lock.touch(), completes);
    dir.createSync(recursive: true);
  });
}
