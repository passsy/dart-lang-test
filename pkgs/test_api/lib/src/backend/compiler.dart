// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// All the Dart compilers supported by the test runner.
class Compiler {
  /// The production Dart to Javascript compiler (whole world, optimizing).
  static const Compiler dart2js =
      Compiler('Dart2Js', 'dart2js', isDefault: true);

  /// The standard compiler for vm tests, compiles tests to kernel before
  /// running them on the VM.
  static const Compiler kernel = Compiler('Kernel', 'kernel', isDefault: true);

  /// Experimental Dart to Wasm compiler.
  static const Compiler wasm = Compiler('WASM', 'wasm');

  /// The compilers that are supported by the test runner by default.
  static const List<Compiler> builtIn = [
    Compiler.dart2js,
    Compiler.kernel,
    Compiler.wasm,
  ];

  /// The human-friendly name of the compiler.
  final String name;

  /// The identifier used to look up the compiler.
  final String identifier;

  /// Whether this compiler is enabled by default.
  final bool isDefault;

  const Compiler(this.name, this.identifier, {this.isDefault = false});

  /// Converts a JSON-safe representation generated by [serialize] back into a
  /// [Compiler].
  factory Compiler.deserialize(String serialized) =>
      builtIn.firstWhere((compiler) => compiler.identifier == serialized);

  /// Converts [this] into a JSON-safe object that can be converted back to a
  /// [Compiler] using [Compiler.deserialize].
  Object serialize() => identifier;

  @override
  String toString() => name;
}
