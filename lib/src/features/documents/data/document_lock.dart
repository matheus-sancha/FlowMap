import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The lock beside an open document, and the rule that lets it go stale.
///
/// **Sharing is sequential** (#37): one writer at a time, the way a CAD or
/// Office file on a shared drive already behaves. Concurrent editing was
/// considered and rejected as a different product shape.
///
/// **The heartbeat is what makes this safe to leave alone.** A lock carries who
/// holds it, on which machine, and when it was last touched; the app refreshes
/// that stamp while the document is open. Once it stops being refreshed the
/// lock is stale and the next person simply opens the document — **nobody has
/// to understand locks or decide to break one**, which is the point for an
/// audience that cannot read a stack trace. A crash, a power cut or a dropped
/// VPN heals itself in minutes rather than leaving a file nobody dares touch.
///
/// It is a lock in the cooperative sense only. Nothing stops another program
/// writing the file, and nothing should: the document lives on a drive this app
/// does not own.
class DocumentLock {
  DocumentLock._(this.file, this.holder, this._heartbeat);

  /// The `.lock` beside the document, not inside it — a document must stay a
  /// single file that can be copied, mailed and renamed without carrying
  /// somebody's session around with it.
  final File file;
  final LockHolder holder;
  Timer? _heartbeat;

  /// How often the stamp is refreshed while a document is open.
  static const heartbeat = Duration(minutes: 1);

  /// How long a lock may go untouched before anyone may take it.
  ///
  /// **Several heartbeats, deliberately.** One missed refresh is a slow disk or
  /// a laptop lid; five minutes without one is a process that is gone. Too
  /// short and a live editor loses their document mid-sentence; too long and a
  /// crash blocks a colleague for the rest of the afternoon.
  static const staleAfter = Duration(minutes: 5);

  static String lockPathFor(String documentPath) => '$documentPath.lock';

  /// Reads whoever holds the lock on [documentPath], or null if nobody does.
  ///
  /// A lock that cannot be read counts as **absent**: a corrupt or truncated
  /// lock file must not be the thing that stops someone opening their own work.
  static LockHolder? holderOf(String documentPath, {DateTime? now}) {
    final file = File(lockPathFor(documentPath));
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final holder = LockHolder.fromJson(json);
      return holder.isStale(now: now) ? null : holder;
    } catch (_) {
      return null;
    }
  }

  /// Takes the lock unless someone else currently holds it.
  ///
  /// Returns the lock, or null when [holderOf] says the document is taken — in
  /// which case the caller offers a read-only copy rather than a way to force
  /// it.
  static Future<DocumentLock?> acquire(
    String documentPath, {
    required String user,
    required String machine,
    DateTime? now,
  }) async {
    if (holderOf(documentPath, now: now) != null) return null;

    final holder = LockHolder(
      user: user,
      machine: machine,
      touched: now ?? DateTime.now(),
    );
    final file = File(lockPathFor(documentPath));
    await file.writeAsString(jsonEncode(holder.toJson()), flush: true);

    final lock = DocumentLock._(file, holder, null);
    lock._start();
    return lock;
  }

  void _start() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeat, (_) => touch());
  }

  /// Refreshes the stamp, which is the only thing keeping the lock alive.
  Future<void> touch({DateTime? now}) async {
    try {
      await file.writeAsString(
        jsonEncode(holder.refreshed(now ?? DateTime.now()).toJson()),
        flush: true,
      );
    } catch (_) {
      // A drive that has gone away must not crash the app mid-edit. The lock
      // simply stops being refreshed, and goes stale on its own — which is the
      // same outcome as the process dying, and the right one.
    }
  }

  /// Releases the lock. Safe to call twice, and safe when the file is gone.
  Future<void> release() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    try {
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // Left behind, it goes stale in [staleAfter] and stops mattering.
    }
  }
}

/// Who holds a lock, and when they last said so.
class LockHolder {
  const LockHolder({
    required this.user,
    required this.machine,
    required this.touched,
  });

  final String user;
  final String machine;
  final DateTime touched;

  bool isStale({DateTime? now}) =>
      (now ?? DateTime.now()).difference(touched) > DocumentLock.staleAfter;

  LockHolder refreshed(DateTime now) =>
      LockHolder(user: user, machine: machine, touched: now);

  Map<String, dynamic> toJson() => {
    'user': user,
    'machine': machine,
    'touched': touched.toIso8601String(),
  };

  factory LockHolder.fromJson(Map<String, dynamic> json) => LockHolder(
    user: json['user'] as String? ?? 'someone',
    machine: json['machine'] as String? ?? 'another machine',
    touched:
        DateTime.tryParse(json['touched'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// What the second person is told. Names the machine as well as the user,
  /// because on a shared drive the same person on two PCs is the ordinary case.
  String describe() => '$user ($machine)';
}
