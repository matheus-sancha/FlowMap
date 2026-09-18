import 'dart:io';

import 'package:path/path.dart' as p;

/// A file the drop ships beside the executable, or null when it is not there.
///
/// **Null in every build that is not an unzipped drop** — `flutter run`, a test,
/// a copied exe — so the controls that open these files simply do not appear
/// rather than pointing at nothing (#28). The packaging script is what puts
/// them there: `manual.html`, `example.flowmap`, `READ ME FIRST.txt`.
File? shippedFile(String name) {
  try {
    final file = File(p.join(File(Platform.resolvedExecutable).parent.path, name));
    return file.existsSync() ? file : null;
  } catch (_) {
    return null;
  }
}

/// The user guide in the zip (#28).
const manualFileName = 'manual.html';

/// The worked example in the zip — a sample plant, as a document (#28, #37).
const exampleFileName = 'example.flowmap';
