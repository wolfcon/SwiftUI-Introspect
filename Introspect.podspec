Pod::Spec.new do |spec|
  spec.name = 'Introspect'
  spec.version = '0.0.3'
  spec.license = { type: 'MIT' }
  spec.homepage = 'https://github.com/timbersoftware/SwiftUI-Introspect.git'
  spec.authors = { 'Lois Di Qual' => 'lois@timber.so' }
  spec.summary = 'Introspect the underlying UIKit element of a SwiftUI view.'
  spec.source = {
    git: 'https://github.com/timbersoftware/SwiftUI-Introspect.git',
    tag: spec.version
  }
  spec.source_files = 'Introspect/**/*.swift'
  spec.platform = :ios, '13.0'
  spec.swift_version = '5.1'
end