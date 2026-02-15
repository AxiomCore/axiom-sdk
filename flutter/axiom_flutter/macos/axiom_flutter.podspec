Pod::Spec.new do |s|
  s.name             = 'axiom_flutter'
  s.version          = '0.0.7'
  s.summary          = 'Axiom Runtime macOS'
  s.homepage         = 'https://axiomcore.dev'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Axiom' => 'contact@yashmakan.com' }

  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*'
  s.vendored_frameworks = 'Frameworks/AxiomRuntime.xcframework'

  s.platform         = :osx, '11.0'
  s.dependency       'FlutterMacOS'

  s.frameworks       = 'SystemConfiguration', 'Security', 'CoreFoundation'
  s.libraries        = 'bz2', 'z'

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES',
    'STRIP_STYLE' => 'non-global',
    'DEAD_CODE_STRIPPING' => 'NO',
    'OTHER_LDFLAGS' => '-all_load'
  }

  s.user_target_xcconfig = { 
    'STRIP_STYLE' => 'non-global',
    'DEAD_CODE_STRIPPING' => 'NO'
  }

  s.swift_version = '5.0'
end
