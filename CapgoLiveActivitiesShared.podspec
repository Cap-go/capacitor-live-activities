require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name = 'CapgoLiveActivitiesShared'
  s.version = package['version']
  s.summary = "#{package['description']} (shared Live Activity UI helpers)"
  s.license = package['license']
  s.homepage = package['repository']['url']
  s.author = package['author']
  s.source = { :git => package['repository']['url'], :tag => s.version.to_s }
  s.ios.deployment_target = '16.1'
  s.swift_version = '5.1'
  s.source_files = 'ios/Sources/CapgoLiveActivitiesShared/**/*.{swift,h,m,c,cc,mm,cpp}'
  s.module_name = 'CapgoLiveActivitiesShared'
end
