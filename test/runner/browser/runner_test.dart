// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/src/util/io.dart';
import 'package:test/test.dart';

import '../../io.dart';

String _sandbox;

final _success = """
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {});
}
""";

final _failure = """
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("failure", () => throw new TestFailure("oh no"));
}
""";

void main() {
  setUp(() {
    _sandbox = createTempDir();
  });

  tearDown(() {
    new Directory(_sandbox).deleteSync(recursive: true);
  });

  group("fails gracefully if", () {
    test("a test file fails to compile", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("invalid Dart file");
      var result = _runUnittest(["-p", "chrome", "test.dart"]);

      expect(result.stdout,
          contains("Expected a declaration, but got 'invalid'"));
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": dart2js '
                'failed.')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a test file throws", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void main() => throw 'oh no';");

      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": oh no')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a test file doesn't have a main defined", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void foo() {}");

      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": No '
                'top-level main() function defined.')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a test file has a non-function main", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("int main;");

      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": '
                'Top-level main getter is not a function.\n')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a test file has a main with arguments", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void main(arg) {}");

      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": '
                'Top-level main() function takes arguments.\n')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a custom HTML file has no script tag", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void main(arg) {}");

      new File(p.join(_sandbox, "test.html")).writeAsStringSync("""
<html>
<head>
  <link rel="x-dart-test" href="test.dart">
</head>
</html>
""");

      var relativePath = p.relative(testPath, from: _sandbox);
      var result = _runUnittest(["-p", "dartium", "test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "$relativePath": '
                '"${p.withoutExtension(relativePath)}.html" must contain '
                '<script src="packages/test/dart.js"></script>.\n')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a custom HTML file has no link", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void main(arg) {}");

      new File(p.join(_sandbox, "test.html")).writeAsStringSync("""
<html>
<head>
  <script src="packages/test/dart.js"></script>
</head>
</html>
""");

      var result = _runUnittest(["-p", "dartium", "test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": '
                'Expected exactly 1 <link rel="x-dart-test"> in test.html, '
                'found 0.\n')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a custom HTML file has too many links", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void main(arg) {}");

      new File(p.join(_sandbox, "test.html")).writeAsStringSync("""
<html>
<head>
  <link rel='x-dart-test' href='test.dart'>
  <link rel='x-dart-test' href='test.dart'>
  <script src="packages/test/dart.js"></script>
</head>
</html>
""");

      var result = _runUnittest(["-p", "dartium", "test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": '
                'Expected exactly 1 <link rel="x-dart-test"> in test.html, '
                'found 2.\n')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a custom HTML file has no href in the link", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void main(arg) {}");

      new File(p.join(_sandbox, "test.html")).writeAsStringSync("""
<html>
<head>
  <link rel='x-dart-test'>
  <script src="packages/test/dart.js"></script>
</head>
</html>
""");

      var result = _runUnittest(["-p", "dartium", "test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": '
                'Expected <link rel="x-dart-test"> in test.html to have an '
                '"href" attribute.\n')
      ]));
      expect(result.exitCode, equals(1));
    });

    test("a custom HTML file has an invalid test URL", () {
      var testPath = p.join(_sandbox, "test.dart");
      new File(testPath).writeAsStringSync("void main(arg) {}");

      new File(p.join(_sandbox, "test.html")).writeAsStringSync("""
<html>
<head>
  <link rel='x-dart-test' href='wrong.dart'>
  <script src="packages/test/dart.js"></script>
</head>
</html>
""");

      var result = _runUnittest(["-p", "dartium", "test.dart"]);
      expect(result.stdout, allOf([
        contains('-1: load error'),
        contains(
            'Failed to load "${p.relative(testPath, from: _sandbox)}": '
                'Failed to load script at ')
      ]));
      expect(result.exitCode, equals(1));
    });

    // TODO(nweiz): test what happens when a test file is unreadable once issue
    // 15078 is fixed.
  });

  group("runs successful tests", () {
    test("on Chrome", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.exitCode, equals(0));
    });

    test("on PhantomJS", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "phantomjs", "test.dart"]);
      expect(result.exitCode, equals(0));
    });

    test("on Firefox", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "firefox", "test.dart"]);
      expect(result.exitCode, equals(0));
    });

    test("on Safari", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "safari", "test.dart"]);
      expect(result.exitCode, equals(0));
    }, testOn: "mac-os");

    test("on Dartium", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "dartium", "test.dart"]);
      expect(result.stdout, isNot(contains("Compiling")));
      expect(result.exitCode, equals(0));
    });

    test("on content shell", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "content-shell", "test.dart"]);
      expect(result.stdout, isNot(contains("Compiling")));
      expect(result.exitCode, equals(0));
    });

    test("on multiple browsers", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "firefox", "-p", "chrome", "test.dart"]);
      expect("Compiling".allMatches(result.stdout), hasLength(1));
      expect(result.exitCode, equals(0));
    });

    test("on a JS and non-JS browser", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(
          ["-p", "content-shell", "-p", "chrome", "test.dart"]);
      expect("Compiling".allMatches(result.stdout), hasLength(1));
      expect(result.exitCode, equals(0));
    });

    test("on the browser and the VM", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_success);
      var result = _runUnittest(["-p", "chrome", "-p", "vm", "test.dart"]);
      expect(result.exitCode, equals(0));
    });

    // Regression test; this broke in 0.12.0-beta.9.
    test("on a file in a subdirectory", () {
      new Directory(p.join(_sandbox, "dir")).createSync();
      new File(p.join(_sandbox, "dir", "test.dart"))
          .writeAsStringSync(_success);
      var result = _runUnittest(["-p", "chrome", "dir/test.dart"]);
      expect(result.exitCode, equals(0));
    });

    group("with a custom HTML file", () {
      setUp(() {
        new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:html';

import 'package:test/test.dart';

void main() {
  test("success", () {
    expect(document.query('#foo'), isNotNull);
  });
}
""");

        new File(p.join(_sandbox, "test.html")).writeAsStringSync("""
<html>
<head>
  <link rel='x-dart-test' href='test.dart'>
  <script src="packages/test/dart.js"></script>
</head>
<body>
  <div id="foo"></div>
</body>
</html>
""");
      });

      test("on content shell", () {
        var result = _runUnittest(["-p", "content-shell", "test.dart"]);
        expect(result.exitCode, equals(0));
      });

      test("on Chrome", () {
        var result = _runUnittest(["-p", "chrome", "test.dart"]);
        expect(result.exitCode, equals(0));
      });

      // Regression test for https://github.com/dart-lang/test/issues/82.
      test("ignores irrelevant link tags", () {
        new File(p.join(_sandbox, "test.html")).writeAsStringSync("""
<html>
<head>
  <link rel='x-dart-test-not'>
  <link rel='other' href='test.dart'>
  <link rel='x-dart-test' href='test.dart'>
  <script src="packages/test/dart.js"></script>
</head>
<body>
  <div id="foo"></div>
</body>
</html>
""");

        var result = _runUnittest(["-p", "content-shell", "test.dart"]);
        expect(result.exitCode, equals(0));
      });
    });
  });

  group("runs failing tests", () {
    test("on Chrome", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("on PhantomJS", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runUnittest(["-p", "phantomjs", "test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("on Firefox", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runUnittest(["-p", "firefox", "test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("on Safari", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runUnittest(["-p", "safari", "test.dart"]);
      expect(result.exitCode, equals(1));
    }, testOn: "mac-os");

    test("on Dartium", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runUnittest(["-p", "dartium", "test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("on content-shell", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync(_failure);
      var result = _runUnittest(["-p", "content-shell", "test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("that fail only on the browser", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test("test", () {
    if (p.style == p.Style.url) throw new TestFailure("oh no");
  });
}
""");
      var result = _runUnittest(["-p", "chrome", "-p", "vm", "test.dart"]);
      expect(result.exitCode, equals(1));
    });

    test("that fail only on the VM", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test("test", () {
    if (p.style != p.Style.url) throw new TestFailure("oh no");
  });
}
""");
      var result = _runUnittest(["-p", "chrome", "-p", "vm", "test.dart"]);
      expect(result.exitCode, equals(1));
    });


    group("with a custom HTML file", () {
      setUp(() {
        new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:html';

import 'package:test/test.dart';

void main() {
  test("failure", () {
    expect(document.query('#foo'), isNull);
  });
}
""");

        new File(p.join(_sandbox, "test.html")).writeAsStringSync("""
<html>
<head>
  <link rel='x-dart-test' href='test.dart'>
  <script src="packages/test/dart.js"></script>
</head>
<body>
  <div id="foo"></div>
</body>
</html>
""");
      });

      test("on content shell", () {
        var result = _runUnittest(["-p", "content-shell", "test.dart"]);
        expect(result.exitCode, equals(1));
      });

      test("on Chrome", () {
        var result = _runUnittest(["-p", "chrome", "test.dart"]);
        expect(result.exitCode, equals(1));
      });
    });
  });

  test("forwards prints from the browser test", () {
    new File(p.join(_sandbox, "test.dart")).writeAsStringSync("""
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("test", () {
    print("Hello,");
    return new Future(() => print("world!"));
  });
}
""");

    var result = _runUnittest(["-p", "chrome", "test.dart"]);
    expect(result.stdout, contains("Hello,\nworld!\n"));
    expect(result.exitCode, equals(0));
  });

  test("respects top-level @Timeout declarations", () {
    new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
@Timeout(const Duration(seconds: 0))

import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("timeout", () {});
}
''');

    var result = _runUnittest(["-p", "chrome", "test.dart"]);
    expect(result.stdout, contains("Test timed out after 0 seconds."));
    expect(result.stdout, contains("-1: Some tests failed."));
  });

  group("in onPlatform", () {
    test("respects matching Skips", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no', onPlatform: {"chrome": new Skip()});
}
''');

      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.stdout, contains("+0 ~1: All tests skipped."));
    });

    test("ignores non-matching Skips", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {}, onPlatform: {"vm": new Skip()});
}
''');

      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.stdout, contains("+1: All tests passed!"));
    });

    test("respects matching Timeouts", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("fail", () => throw 'oh no', onPlatform: {
    "chrome": new Timeout(new Duration(seconds: 0))
  });
}
''');

      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.stdout, contains("Test timed out after 0 seconds."));
      expect(result.stdout, contains("-1: Some tests failed."));
    });

    test("ignores non-matching Timeouts", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {}, onPlatform: {
    "vm": new Timeout(new Duration(seconds: 0))
  });
}
''');

      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.stdout, contains("+1: All tests passed!"));
    });

    test("applies matching platforms in order", () {
      new File(p.join(_sandbox, "test.dart")).writeAsStringSync('''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test("success", () {}, onPlatform: {
    "chrome": new Skip("first"),
    "chrome || windows": new Skip("second"),
    "chrome || linux": new Skip("third"),
    "chrome || mac-os": new Skip("fourth"),
    "chrome || android": new Skip("fifth")
  });
}
''');

      var result = _runUnittest(["-p", "chrome", "test.dart"]);
      expect(result.stdout, contains("Skip: fifth"));
      expect(result.stdout, isNot(anyOf([
        contains("Skip: first"),
        contains("Skip: second"),
        contains("Skip: third"),
        contains("Skip: fourth")
      ])));
    });
  });
}

ProcessResult _runUnittest(List<String> args) =>
    runUnittest(args, workingDirectory: _sandbox);
