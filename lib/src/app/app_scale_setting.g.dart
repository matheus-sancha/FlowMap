// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_scale_setting.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppScaleSetting)
final appScaleSettingProvider = AppScaleSettingProvider._();

final class AppScaleSettingProvider
    extends $NotifierProvider<AppScaleSetting, double> {
  AppScaleSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appScaleSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appScaleSettingHash();

  @$internal
  @override
  AppScaleSetting create() => AppScaleSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$appScaleSettingHash() => r'0e4572dfe6bf6a09c2e25764bc679cd6544c8001';

abstract class _$AppScaleSetting extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
