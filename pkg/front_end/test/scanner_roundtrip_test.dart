// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:front_end/src/fasta/analyzer/token_utils.dart';
import 'package:front_end/src/scanner/token.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'scanner_fasta_test.dart';
import 'scanner_test.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ScannerTest_RoundTrip);
  });
}

/// Scanner tests that use the analyzer scanner, then convert the resulting
/// token stream into a Fasta token stream, then convert back to an analyzer
/// token stream before verifying assertions.
///
/// These tests help to validate the correctness of the analyzer->Fasta token
/// stream conversion.
@reflectiveTest
class ScannerTest_RoundTrip extends ScannerTest {
  @override
  Token scanWithListener(String source, ErrorListener listener,
      {bool genericMethodComments: false,
      bool lazyAssignmentOperators: false}) {
    var analyzerToken = super.scanWithListener(source, listener,
        genericMethodComments: genericMethodComments,
        lazyAssignmentOperators: lazyAssignmentOperators);
    var fastaToken = fromAnalyzerTokenStream(analyzerToken);
    // Since [scanWithListener] reports errors to the listener, we don't
    // expect any error tokens in the Fasta token stream, so we convert using
    // ToAnalyzerTokenStreamConverter_NoErrors.
    return new ToAnalyzerTokenStreamConverter_NoErrors()
        .convertTokens(fastaToken);
  }

  @override
  @failingTest
  void test_ampersand_ampersand_eq() {
    // TODO(paulberry,ahe): Fasta scanner doesn't support lazy assignment
    // operators.
    super.test_ampersand_ampersand_eq();
  }

  @override
  @failingTest
  void test_bar_bar_eq() {
    // TODO(paulberry,ahe): Fasta scanner doesn't support lazy assignment
    // operators.
    super.test_bar_bar_eq();
  }

  @override
  @failingTest
  void test_comment_generic_method_type_assign() {
    // TODO(paulberry,ahe): Fasta scanner doesn't support generic comment
    // syntax.
    super.test_comment_generic_method_type_assign();
  }

  @override
  @failingTest
  void test_comment_generic_method_type_list() {
    // TODO(paulberry,ahe): Fasta scanner doesn't support generic comment
    // syntax.
    super.test_comment_generic_method_type_list();
  }

  @override
  @failingTest
  void test_scriptTag_withArgs() {
    // TODO(paulberry,ahe): Fasta scanner doesn't support script tag
    super.test_scriptTag_withArgs();
  }

  @override
  @failingTest
  void test_scriptTag_withoutSpace() {
    // TODO(paulberry,ahe): Fasta scanner doesn't support script tag
    super.test_scriptTag_withoutSpace();
  }

  @override
  @failingTest
  void test_scriptTag_withSpace() {
    // TODO(paulberry,ahe): Fasta scanner doesn't support script tag
    super.test_scriptTag_withSpace();
  }

  void test_pseudo_keywords() {
    var pseudoAnalyzerKeywords = new Set<Keyword>.from([
      Keyword.ABSTRACT,
      Keyword.AS,
      Keyword.COVARIANT,
      Keyword.DEFERRED,
      Keyword.DYNAMIC,
      Keyword.EXPORT,
      Keyword.EXTERNAL,
      Keyword.FACTORY,
      Keyword.GET,
      Keyword.IMPLEMENTS,
      Keyword.IMPORT,
      Keyword.LIBRARY,
      Keyword.OPERATOR,
      Keyword.PART,
      Keyword.SET,
      Keyword.STATIC,
      Keyword.TYPEDEF,
    ]);
    for (Keyword keyword in Keyword.values) {
      expect(keyword.isPseudoKeyword, pseudoAnalyzerKeywords.contains(keyword),
          reason: keyword.name);
    }
  }
}
