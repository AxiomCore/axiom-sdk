Pod::Spec.new do |s|
  s.name             = 'axiom_flutter'
  s.version          = '0.147.4'
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
  runtime_version = '0.148.5' # Independent, verified AxiomRuntime release pin.
  url = "https://github.com/AxiomCore/AxiomCore/releases/download/v#{runtime_version}/#{zip_name}"

  runtime_sha256 = 'caa3e80dcb9374d633ffeb4fed3fe3797e832056154daab1f157bbfe13dbb1a5'
  # Download and verify on every preparation so a stale framework cannot
  # bypass the release pin. Failed downloads/checks leave the existing one intact.
  s.prepare_command = <<-CMD
    set -eu
    stage=$(mktemp -d "${TMPDIR:-/tmp}/axiom-runtime.XXXXXX")
    trap 'rm -rf "$stage"' EXIT HUP INT TERM
    curl --fail --location --proto '=https' --tlsv1.2 --output "$stage/runtime.zip" "#{url}"
    actual=$(shasum -a 256 "$stage/runtime.zip" | awk '{print $1}')
    if [ "$actual" != "#{runtime_sha256}" ]; then
      echo "AxiomRuntime checksum mismatch" >&2
      exit 1
    fi
    unzip -q "$stage/runtime.zip" -d "$stage/unpacked"
    test -f "$stage/unpacked/#{framework_name}/Info.plist"
    backup="#{framework_name}.previous.$$"
    if [ -e "#{framework_name}" ]; then mv "#{framework_name}" "$backup"; fi
    if mv "$stage/unpacked/#{framework_name}" "#{framework_name}"; then
      rm -rf "$backup"
    else
      if [ -e "$backup" ]; then mv "$backup" "#{framework_name}"; fi
      exit 1
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
