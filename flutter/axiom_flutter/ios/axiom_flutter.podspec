Pod::Spec.new do |s|
  s.name             = 'axiom_flutter'
  s.version          = '0.73.0' # Make sure this matches your GitHub release version!
  s.summary          = 'Axiom Runtime'
  s.homepage         = 'https://axiomcore.dev'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Axiom' => 'contact@yashmakan.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :ios, '13.0'
  s.dependency       'Flutter'

  s.frameworks       = 'SystemConfiguration', 'Security'
  s.libraries        = 'bz2', 'z'

  # 👇 THE MAGIC DOWNLOAD SCRIPT 👇
  framework_name = 'AxiomRuntime.xcframework'
  zip_name = "#{framework_name}.zip"
  url = "https://github.com/AxiomCore/AxiomCore/releases/download/v#{s.version}/#{zip_name}"

  s.prepare_command = <<-CMD
    if [ ! -d "#{framework_name}" ]; then
      echo "Downloading AxiomRuntime binary v#{s.version}..."
      curl -L -o #{zip_name} #{url}
      unzip -q -o #{zip_name}
      rm #{zip_name}
    fi
  CMD

  s.vendored_frameworks = framework_name
  # 👆 END MAGIC SCRIPT 👆

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
