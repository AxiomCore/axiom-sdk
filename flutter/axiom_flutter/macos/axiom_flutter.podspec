Pod::Spec.new do |s|
  s.name             = 'axiom_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Axiom Runtime macOS'
  s.homepage         = 'http://axiom.xyz'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Axiom' => 'contact@axiom.xyz' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '11.0'
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

  s.frameworks = 'SystemConfiguration', 'Security', 'CoreFoundation'
  s.libraries = 'bz2', 'z'

  s.vendored_frameworks = 'Frameworks/AxiomRuntime.xcframework'
  s.swift_version = '5.0'
end