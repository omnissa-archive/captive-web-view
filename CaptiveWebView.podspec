# Copyright 2023 VMware, Inc.  
# SPDX-License-Identifier: BSD-2-Clause
#
# Be sure to run `pod lib lint CaptiveWebView.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html

Pod::Spec.new do |s|
  s.name             = 'CaptiveWebView'
  s.version          = '1.0.0'
  s.summary          = 'The Captive Web View library facilitates use of web technologies in mobile applications.'

  s.homepage         = 'https://github.com/vmware/captive-web-view'
  s.license          = { :type => 'BSD-2', :file => 'LICENSE.txt' }
  s.author           = 'vmware'
  s.source           = { :git => 'https://github.com/vmware/captive-web-view.git', :branch => "19-detailed-fetch-errors" }

  s.ios.deployment_target = '14.0'

  s.source_files = '**/Sources/**/*'
  s.resources = "**/Sources/CaptiveWebView/Resources/*"
end
