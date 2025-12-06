Pod::Spec.new do |s|
  s.name         = 'axiom_flutter'
  s.version      = '0.1.0'
  s.summary      = 'Axiom Runtime bridge for Flutter'
  s.description  = 'Native Swift bridge for the Axiom Runtime.'
  s.homepage     = 'https://axiom.dev'
  s.license      = { :type => 'MIT' }
  s.author       = { 'Axiom' => 'dev@axiom.dev' }

  s.source       = { :path => '.' }

  s.dependency 'Flutter'
  s.source_files = 'Classes/**/*'

  # Do NOT bundle XCFramework in the plugin
  # It will be placed into the app project by axiom pull.
  s.vendored_frameworks = 'AxiomRuntime.xcframework'

  s.ios.deployment_target = '12.0'
  s.swift_version = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
