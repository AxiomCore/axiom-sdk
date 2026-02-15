Pod::Spec.new do |s|
  s.name             = 'axiom_flutter'
  s.version          = '0.0.2'
  s.summary          = 'Axiom Runtime'
  s.homepage         = 'https://axiomcore.dev'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Axiom' => 'contact@yashmakan.com' }

  s.source           = { :http => 'https://binary.axiomcore.dev/ios/AxiomRuntime.xcframework.zip' }

  s.source_files     = 'Classes/**/*'
  s.dependency       'Flutter'
  s.platform         = :ios, '13.0'

  s.frameworks       = 'SystemConfiguration', 'Security'
  s.libraries        = 'bz2', 'z'

  s.vendored_frameworks = 'AxiomRuntime.xcframework'

  # Settings for the Plugin itself
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES',
    'STRIP_STYLE' => 'non-global',
    'DEAD_CODE_STRIPPING' => 'NO',
    'OTHER_LDFLAGS' => '-all_load'
  }

  # --- AUTOMATION STEP ---
  # These settings propagate to the developer's "Runner" target automatically
  s.user_target_xcconfig = { 
    'STRIP_STYLE' => 'non-global',
    'DEAD_CODE_STRIPPING' => 'NO'
  }

  s.swift_version = '5.0'
end
