import 'dart:io';

import 'package:flutter_app_packager/src/makers/exe/inno_setup/inno_setup_script.dart';
import 'package:path/path.dart' as p;
import 'package:shell_executor/shell_executor.dart';

class InnoSetupCompiler {
  /// Extra environment variables passed from the caller (e.g. from
  /// distribute_options.yaml). Stored so a future compile() implementation can
  /// honor `INNO_SETUP_PATH`; the current compile() does not yet read it.
  static final Map<String, String> _extraEnv = {};

  /// Set extra environment variables to be consulted when resolving ISCC.exe.
  static void setExtraEnv(Map<String, String> env) {
    _extraEnv
      ..clear()
      ..addAll(env);
  }

  Future<bool> compile(InnoSetupScript script) async {
    Directory innoSetupDirectory =
        Directory('C:\\Program Files (x86)\\Inno Setup 6');

    if (!innoSetupDirectory.existsSync()) {
      throw Exception('`Inno Setup 6` was not installed.');
    }

    File file = await script.createFile();

    ProcessResult processResult = await $(
      p.join(innoSetupDirectory.path, 'ISCC.exe'),
      [file.path],
    );

    if (processResult.exitCode != 0) {
      return false;
    }

    file.deleteSync(recursive: true);
    return true;
  }
}
