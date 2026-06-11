// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lop_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$lopDetailControllerHash() =>
    r'6820b1c6668e4ff04cfdd2f804bcfccc885b9253';

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
  late final Lop initialLop;

  FutureOr<LopDetailState> build(Lop initialLop);
}

/// See also [LopDetailController].
@ProviderFor(LopDetailController)
const lopDetailControllerProvider = LopDetailControllerFamily();

/// See also [LopDetailController].
class LopDetailControllerFamily extends Family<AsyncValue<LopDetailState>> {
  /// See also [LopDetailController].
  const LopDetailControllerFamily();

  /// See also [LopDetailController].
  LopDetailControllerProvider call(Lop initialLop) {
    return LopDetailControllerProvider(initialLop);
  }

  @override
  LopDetailControllerProvider getProviderOverride(
    covariant LopDetailControllerProvider provider,
  ) {
    return call(provider.initialLop);
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
  LopDetailControllerProvider(Lop initialLop)
    : this._internal(
        () => LopDetailController()..initialLop = initialLop,
        from: lopDetailControllerProvider,
        name: r'lopDetailControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$lopDetailControllerHash,
        dependencies: LopDetailControllerFamily._dependencies,
        allTransitiveDependencies:
            LopDetailControllerFamily._allTransitiveDependencies,
        initialLop: initialLop,
      );

  LopDetailControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.initialLop,
  }) : super.internal();

  final Lop initialLop;

  @override
  FutureOr<LopDetailState> runNotifierBuild(
    covariant LopDetailController notifier,
  ) {
    return notifier.build(initialLop);
  }

  @override
  Override overrideWith(LopDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: LopDetailControllerProvider._internal(
        () => create()..initialLop = initialLop,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        initialLop: initialLop,
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
    return other is LopDetailControllerProvider &&
        other.initialLop == initialLop;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, initialLop.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LopDetailControllerRef
    on AutoDisposeAsyncNotifierProviderRef<LopDetailState> {
  /// The parameter `initialLop` of this provider.
  Lop get initialLop;
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
  Lop get initialLop => (origin as LopDetailControllerProvider).initialLop;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
