// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart2js.kernel.backend_strategy;

import 'package:kernel/ast.dart' as ir;

import '../backend_strategy.dart';
import '../common.dart';
import '../common/codegen.dart' show CodegenRegistry, CodegenWorkItem;
import '../common/tasks.dart';
import '../compiler.dart';
import '../elements/entities.dart';
import '../elements/entity_utils.dart' as utils;
import '../enqueue.dart';
import '../io/source_information.dart';
import '../js_backend/backend.dart';
import '../js_emitter/sorter.dart';
import '../js_model/js_strategy.dart';
import '../js_model/locals.dart';
import '../kernel/element_map.dart';
import '../native/behavior.dart';
import '../options.dart';
import '../ssa/builder_kernel.dart';
import '../ssa/nodes.dart';
import '../ssa/ssa.dart';
import '../ssa/types.dart';
import '../types/types.dart';
import '../universe/selector.dart';
import '../universe/world_impact.dart';
import '../world.dart';

/// A backend strategy based on Kernel IR nodes.
abstract class KernelBackendStrategy implements BackendStrategy {
  KernelToElementMapForBuilding get elementMap;
  GlobalLocalsMap get globalLocalsMapForTesting;

  factory KernelBackendStrategy(Compiler compiler) {
    return new JsBackendStrategy(compiler);
  }
}

class KernelCodegenWorkItemBuilder implements WorkItemBuilder {
  final JavaScriptBackend _backend;
  final ClosedWorld _closedWorld;

  KernelCodegenWorkItemBuilder(this._backend, this._closedWorld);

  CompilerOptions get _options => _backend.compiler.options;

  @override
  CodegenWorkItem createWorkItem(MemberEntity entity) {
    if (entity.isAbstract) return null;

    // Codegen inlines field initializers. It only needs to generate
    // code for checked setters.
    if (entity.isField && entity.isInstanceMember) {
      if (!_options.enableTypeAssertions || entity.enclosingClass.isClosure) {
        return null;
      }
    }

    return new KernelCodegenWorkItem(_backend, _closedWorld, entity);
  }
}

class KernelCodegenWorkItem extends CodegenWorkItem {
  final JavaScriptBackend _backend;
  final ClosedWorld _closedWorld;
  final MemberEntity element;
  final CodegenRegistry registry;

  KernelCodegenWorkItem(this._backend, this._closedWorld, this.element)
      : registry =
            new CodegenRegistry(_closedWorld.elementEnvironment, element);

  @override
  WorldImpact run() {
    return _backend.codegen(this, _closedWorld);
  }
}

/// Task for building SSA from kernel IR loaded from .dill.
class KernelSsaBuilder implements SsaBuilder {
  final CompilerTask task;
  final Compiler _compiler;
  final KernelToElementMapForBuilding _elementMap;
  final GlobalLocalsMap _globalLocalsMap;

  KernelSsaBuilder(
      this.task, this._compiler, this._elementMap, this._globalLocalsMap);

  @override
  HGraph build(CodegenWorkItem work, ClosedWorld closedWorld) {
    KernelToLocalsMap localsMap = _globalLocalsMap.getLocalsMap(work.element);
    KernelSsaGraphBuilder builder = new KernelSsaGraphBuilder(
        work.element,
        work.element.enclosingClass,
        _compiler,
        _elementMap,
        new KernelToTypeInferenceMapImpl(closedWorld),
        localsMap,
        closedWorld,
        _compiler.codegenWorldBuilder,
        work.registry,
        _compiler.backendStrategy.closureDataLookup,
        _compiler.backend.emitter.nativeEmitter,
        // TODO(redemption): Support these:
        const SourceInformationBuilder(),
        null); // Function node used as capture scope id.
    return builder.build();
  }
}

class KernelToTypeInferenceMapImpl implements KernelToTypeInferenceMap {
  final ClosedWorld _closedWorld;

  KernelToTypeInferenceMapImpl(this._closedWorld);

  @override
  TypeMask typeFromNativeBehavior(
      NativeBehavior nativeBehavior, ClosedWorld closedWorld) {
    return TypeMaskFactory.fromNativeBehavior(nativeBehavior, closedWorld);
  }

  @override
  TypeMask selectorTypeOf(Selector selector, TypeMask mask) {
    return _closedWorld.commonMasks.dynamicType;
  }

  @override
  TypeMask getInferredTypeOf(MemberEntity member) {
    return _closedWorld.commonMasks.dynamicType;
  }

  @override
  TypeMask getInferredTypeOfParameter(Local parameter) {
    return _closedWorld.commonMasks.dynamicType;
  }

  @override
  TypeMask inferredIndexType(ir.ForInStatement forInStatement) {
    return _closedWorld.commonMasks.dynamicType;
  }

  @override
  bool isJsIndexableIterator(
      ir.ForInStatement forInStatement, ClosedWorld closedWorld) {
    return false;
  }

  @override
  bool isFixedLength(TypeMask mask, ClosedWorld closedWorld) {
    return false;
  }

  @override
  TypeMask typeOfIteratorMoveNext(ir.ForInStatement forInStatement) {
    return _closedWorld.commonMasks.dynamicType;
  }

  @override
  TypeMask typeOfIteratorCurrent(ir.ForInStatement forInStatement) {
    return _closedWorld.commonMasks.dynamicType;
  }

  @override
  TypeMask typeOfIterator(ir.ForInStatement forInStatement) {
    return _closedWorld.commonMasks.dynamicType;
  }

  @override
  TypeMask typeOfListLiteral(
      MemberEntity owner, ir.ListLiteral listLiteral, ClosedWorld closedWorld) {
    return _closedWorld.commonMasks.dynamicType;
  }

  @override
  TypeMask typeOfSet(ir.PropertySet write, ClosedWorld closedWorld) {
    return _closedWorld.commonMasks.dynamicType;
  }

  @override
  TypeMask typeOfGet(ir.PropertyGet read) {
    return _closedWorld.commonMasks.dynamicType;
  }

  @override
  TypeMask typeOfInvocation(
      ir.MethodInvocation invocation, ClosedWorld closedWorld) {
    return _closedWorld.commonMasks.dynamicType;
  }

  @override
  TypeMask getReturnTypeOf(FunctionEntity function) {
    return _closedWorld.commonMasks.dynamicType;
  }
}

class KernelSorter implements Sorter {
  final KernelToElementMapForBuilding elementMap;

  KernelSorter(this.elementMap);

  int _compareLibraries(LibraryEntity a, LibraryEntity b) {
    return utils.compareLibrariesUris(a.canonicalUri, b.canonicalUri);
  }

  int _compareSourceSpans(Entity entity1, SourceSpan sourceSpan1,
      Entity entity2, SourceSpan sourceSpan2) {
    int r = utils.compareSourceUris(sourceSpan1.uri, sourceSpan2.uri);
    if (r != 0) return r;
    return utils.compareEntities(
        entity1, sourceSpan1.begin, null, entity2, sourceSpan2.begin, null);
  }

  @override
  Iterable<LibraryEntity> sortLibraries(Iterable<LibraryEntity> libraries) {
    return libraries.toList()..sort(_compareLibraries);
  }

  @override
  Iterable<MemberEntity> sortMembers(Iterable<MemberEntity> members) {
    return members.toList()
      ..sort((MemberEntity member1, MemberEntity member2) {
        int r = _compareLibraries(member1.library, member2.library);
        if (r != 0) return r;
        MemberDefinition definition1 = elementMap.getMemberDefinition(member1);
        MemberDefinition definition2 = elementMap.getMemberDefinition(member2);
        return _compareSourceSpans(
            member1, definition1.location, member2, definition2.location);
      });
  }

  @override
  Iterable<ClassEntity> sortClasses(Iterable<ClassEntity> classes) {
    int compareClasses(ClassEntity cls1, ClassEntity cls2) {
      int r = _compareLibraries(cls1.library, cls2.library);
      if (r != 0) return r;
      ClassDefinition definition1 = elementMap.getClassDefinition(cls1);
      ClassDefinition definition2 = elementMap.getClassDefinition(cls2);
      return _compareSourceSpans(
          cls1, definition1.location, cls2, definition2.location);
    }

    List<ClassEntity> regularClasses = <ClassEntity>[];
    List<ClassEntity> unnamedMixins = <ClassEntity>[];
    for (ClassEntity cls in classes) {
      if (elementMap.elementEnvironment.isUnnamedMixinApplication(cls)) {
        unnamedMixins.add(cls);
      } else {
        regularClasses.add(cls);
      }
    }
    List<ClassEntity> sorted = <ClassEntity>[];
    regularClasses.sort(compareClasses);
    sorted.addAll(regularClasses);
    unnamedMixins.sort((a, b) {
      int result = _compareLibraries(a.library, b.library);
      if (result != 0) return result;
      result = a.name.compareTo(b.name);
      assert(result != 0,
          failedAt(a, "Multiple mixins named ${a.name}: $a vs $b."));
      return result;
    });
    sorted.addAll(unnamedMixins);
    return sorted;
  }

  @override
  Iterable<TypedefEntity> sortTypedefs(Iterable<TypedefEntity> typedefs) {
    // TODO(redemption): Support this.
    assert(typedefs.isEmpty);
    return typedefs;
  }
}
