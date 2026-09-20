// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diem_danh_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$diemDanhControllerHash() =>
    r'e0831f7c85630433919444709a84710c3b5aa6d5';

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

abstract class _$DiemDanhController
    extends BuildlessAutoDisposeAsyncNotifier<DiemDanhState> {
  late final int? initialLopId;
  late final DateTime? initialDate;

  FutureOr<DiemDanhState> build(int? initialLopId, DateTime? initialDate);
}

/// See also [DiemDanhController].
@ProviderFor(DiemDanhController)
const diemDanhControllerProvider = DiemDanhControllerFamily();

/// See also [DiemDanhController].
class DiemDanhControllerFamily extends Family<AsyncValue<DiemDanhState>> {
  /// See also [DiemDanhController].
  const DiemDanhControllerFamily();

  /// See also [DiemDanhController].
  DiemDanhControllerProvider call(int? initialLopId, DateTime? initialDate) {
    return DiemDanhControllerProvider(initialLopId, initialDate);
  }

  @override
  DiemDanhControllerProvider getProviderOverride(
    covariant DiemDanhControllerProvider provider,
  ) {
    return call(provider.initialLopId, provider.initialDate);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'diemDanhControllerProvider';
}

/// See also [DiemDanhController].
class DiemDanhControllerProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          DiemDanhController,
          DiemDanhState
        > {
  /// See also [DiemDanhController].
  DiemDanhControllerProvider(int? initialLopId, DateTime? initialDate)
    : this._internal(
        () => DiemDanhController()
          ..initialLopId = initialLopId
          ..initialDate = initialDate,
        from: diemDanhControllerProvider,
        name: r'diemDanhControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$diemDanhControllerHash,
        dependencies: DiemDanhControllerFamily._dependencies,
        allTransitiveDependencies:
            DiemDanhControllerFamily._allTransitiveDependencies,
        initialLopId: initialLopId,
        initialDate: initialDate,
      );

  DiemDanhControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.initialLopId,
    required this.initialDate,
  }) : super.internal();

  final int? initialLopId;
  final DateTime? initialDate;

  @override
  FutureOr<DiemDanhState> runNotifierBuild(
    covariant DiemDanhController notifier,
  ) {
    return notifier.build(initialLopId, initialDate);
  }

  @override
  Override overrideWith(DiemDanhController Function() create) {
    return ProviderOverride(
      origin: this,
      override: DiemDanhControllerProvider._internal(
        () => create()
          ..initialLopId = initialLopId
          ..initialDate = initialDate,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        initialLopId: initialLopId,
        initialDate: initialDate,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<DiemDanhController, DiemDanhState>
  createElement() {
    return _DiemDanhControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DiemDanhControllerProvider &&
        other.initialLopId == initialLopId &&
        other.initialDate == initialDate;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, initialLopId.hashCode);
    hash = _SystemHash.combine(hash, initialDate.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DiemDanhControllerRef
    on AutoDisposeAsyncNotifierProviderRef<DiemDanhState> {
  /// The parameter `initialLopId` of this provider.
  int? get initialLopId;

  /// The parameter `initialDate` of this provider.
  DateTime? get initialDate;
}

class _DiemDanhControllerProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          DiemDanhController,
          DiemDanhState
        >
    with DiemDanhControllerRef {
  _DiemDanhControllerProviderElement(super.provider);

  @override
  int? get initialLopId => (origin as DiemDanhControllerProvider).initialLopId;
  @override
  DateTime? get initialDate =>
      (origin as DiemDanhControllerProvider).initialDate;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
