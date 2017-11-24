require 'tmpdir'
require 'fileutils'

module Gitlab
  module QA
    module Scenario
      module Test
        module Omnibus
          class Upgrade < Scenario::Template
            include WithTempVolumes

            def perform(image = 'CE')
              ce = Release.new(image)

              with_temporary_volumes do |volumes|
                Scenario::Test::Instance::Image
                  .perform(ce) do |scenario|
                  scenario.volumes = volumes
                end

                Scenario::Test::Instance::Image
                  .perform(Release.new('EE')) do |scenario|
                  scenario.volumes = volumes
                end
              end
            end
          end
        end
      end
    end
  end
end
