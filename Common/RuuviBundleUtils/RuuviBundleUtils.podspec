Pod::Spec.new do |s|
  s.name             = 'RuuviBundleUtils'
  s.version          = '0.0.1'
  s.summary          = 'Ruuvi BundleUtils'
  s.homepage         = 'https://ruuvi.com'
  s.author           = { 'Rinat Enikeev' => 'rinat@ruuvi.com' }
  s.license          = { :type => 'BSD 3-Clause', :file => '../../LICENSE' }
  s.platform         = :ios, '10.0'
  s.source           = { git: 'https://github.com/ruuvi/com.ruuvi.station.ios' }
  s.frameworks       = 'Foundation'
  s.requires_arc     = true
  s.ios.deployment_target = '10.0'
  s.swift_version    = '5.0'

  s.default_subspecs = 'RuuviBundleUtils'

  s.subspec 'RuuviBundleUtils' do |ss|
    ss.source_files = 'Sources/RuuviBundleUtils/**/*.{h,m,swift}', 'Sources/RuuviBundleUtils/*.{h,m,swift}'
    ss.resource_bundles = {
        'RuuviBundleUtils' => ['Sources/**/Resources/**/*']
    }
    ss.dependency 'Localize-Swift'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end




