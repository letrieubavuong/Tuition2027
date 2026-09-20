// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lop_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$lopDetailControllerHash() =>
    r'aa17dd2a43f266dda6197b3aea408294921a3fa6';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$LopDetailController
    extends BuildlessAutoDisposeAsyncNotifier<LopDetailState> {
  late final int lopId;

  FutureOr<LopDetailState> build(int lopId);
}

/// See also [LopDetailController].
@ProviderFor(LopDetailController)
const lopDetailControllerProvider = LopDetailControllerFamily();

/// See also [LopDetailController].
class LopDetailControllerFamily extends Family<AsyncValue<LopDetailState>> {
  /// See also [LopDetailController].
  const LopDetailControllerFamily();

  /// See also [LopDetailController].
  LopDetailControllerProvider call(int lopId) {
    return LopDetailControllerProvider(lopId);
  }

  @override
  LopDetailControllerProvider getProviderOverride(
    covariant LopDetailControllerProvider provider,
  ) {
    return call(provider.lopId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'lopDetailControllerProvider';
}

/// See also [LopDetailController].
class LopDetailControllerProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          LopDetailController,
          LopDetailState
        > {
  /// See also [LopDetailController].
  LopDetailControllerProvider(int lopId)
    : this._internal(
        () => LopDetailController()..lopId = lopId,
        from: lopDetailControllerProvider,
        name: r'lopDetailControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$lopDetailControllerHash,
        dependencies: LopDetailControllerFamily._dependencies,
        allTransitiveDependencies:
            LopDetailControllerFamily._allTransitiveDependencies,
        lopId: lopId,
      );

  LopDetailControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.lopId,
  }) : super.internal();

  final int lopId;

  @override
  FutureOr<LopDetailState> runNotifierBuild(
    covariant LopDetailController notifier,
  ) {
    return notifier.build(lopId);
  }

  @override
  Override overrideWith(LopDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: LopDetailControllerProvider._internal(
        () => create()..lopId = lopId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        lopId: lopId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<LopDetailController, LopDetailState>
  createElement() {
    return _LopDetailControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LopDetailControllerProvider && other.lopId == lopId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, lopId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LopDetailControllerRef
    on AutoDisposeAsyncNotifierProviderRef<LopDetailState> {
  /// The parameter `lopId` of this provider.
  int get lopId;
}

class _LopDetailControllerProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          LopDetailController,
          LopDetailState
        >
    with LopDetailControllerRef {
  _LopDetailControllerProviderElement(super.provider);

  @override
  int get lopId => (origin as LopDetailControllerProvider).lopId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
