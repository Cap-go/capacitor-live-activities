require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name = 'CapgoCapacitorLiveActivities'
  s.version = package['version']
  s.summary = package['description']
  s.license = package['license']
  s.homepage = package['repository']['url']
  s.author = package['author']
  s.source = { :git => package['repository']['url'], :tag => s.version.to_s }
  s.ios.deployment_target = '16.1'
  s.swift_version = '5.1'
  s.default_subspec = 'Plugin'

  s.subspec 'Plugin' do |plugin|
    plugin.source_files = 'ios/Sources/CapgoLiveActivitiesPlugin/**/*.{swift,h,m,c,cc,mm,cpp}'
    plugin.dependency 'CapgoLiveActivitiesShared'
    plugin.dependency 'Capacitor'
  end
end
