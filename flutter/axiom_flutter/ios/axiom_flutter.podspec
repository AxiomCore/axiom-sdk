Pod::Spec.new do |s|
  s.name             = 'axiom_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Axiom Runtime'
  s.homepage         = 'http://axiom.xyz'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Axiom' => 'contact@axiom.xyz' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.vendored_frameworks = 'Frameworks/AxiomRuntime.xcframework'

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES',
    # --- ADD THIS LINE ---
    # This ensures all symbols in the static library are exported 
    # so Dart FFI can find them.
    'OTHER_LDFLAGS' => '-all_load'
  }
  s.swift_version = '5.0'
end