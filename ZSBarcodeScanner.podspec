#
# Be sure to run `pod lib lint ZSBarcodeScanner.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ZSBarcodeScanner'
  s.version          = '2.0.1'
  s.summary          = 'A simple barcode scanner ViewController.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
A simple barcode scanner with support for switching between cameras.
                       DESC

  s.homepage         = 'https://git.zsinfo.nl/Zandor300/ZSBarcodeScanner'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Zandor300' => 'info@zsinfo.nl' }
  s.source           = { :git => 'https://git.zsinfo.nl/Zandor300/ZSBarcodeScanner.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.swift_version = '5.0'
  s.ios.deployment_target = '11.0'

  s.source_files = 'ZSBarcodeScanner/Classes/**/*'
  
  # s.resource_bundles = {
  #   'ZSBarcodeScanner' => ['ZSBarcodeScanner/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit'
  s.frameworks = 'QuartzCore'
  # s.dependency 'AFNetworking', '~> 2.3'
end
