require 'spec_helper'
describe 'passenger', :type => :class do
  # Helper methods to set the parameters below.  Why didn't I just SET these in
  #  the params block?  Because I need to refer to them in other helper methods.
  #  If someone has a better way to do this - I'm certainly open to that!
  let(:passenger_version) { '1.2.3' }
  let(:passenger_provider) { 'gem' }

  # Helper methods to match the gem path
  let(:redhat_gem_path) { '/usr/lib/ruby/gems/1.8/gems' }
  let(:debian_gem_path) { '/var/lib/gems/1.8/gems' }
  let(:darwin_gem_path) { '/System/Library/Frameworks/Ruby.framework/Versions/Current/usr' }

  # Helper methods to match file paths
  let(:redhat_mod_passenger_location) { "#{redhat_gem_path}/passenger-#{passenger_version}/ext/apache2/mod_passenger.so" }
  let(:debian_mod_passenger_location) { "#{debian_gem_path}/passenger-#{passenger_version}/ext/apache2/mod_passenger.so" }
  let(:darwin_mod_passenger_location) { "#{darwin_gem_path}/bin/passenger-#{passenger_version}/ext/apache2/mod_passenger.so" }

  # Helper methods to match config file contents below
  let(:redhat_conf_content) { "LoadModule passenger_module #{redhat_gem_path}/passenger-#{passenger_version}/ext/apache2/mod_passenger.so\nPassengerRoot #{redhat_gem_path}/passenger-#{passenger_version}\nPassengerRuby /usr/bin/ruby\n\n# you probably want to tune these settings\nPassengerHighPerformance on\nPassengerMaxPoolSize 12\nPassengerPoolIdleTime 1500\n# PassengerMaxRequests 1000\nPassengerStatThrottleRate 120\nRailsAutoDetect On" } 
  let(:debian_passenger_conf_content) { "<IfModule mod_passenger.c>\n\tPassengerRoot #{debian_gem_path}/passenger-#{passenger_version}\n\tPassengerRuby /usr/bin/ruby\n\n\t# you probably want to tune these settings\n\tPassengerHighPerformance on\n\tPassengerMaxPoolSize 12\n\tPassengerPoolIdleTime 1500\n\t# PassengerMaxRequests 1000\n\tPassengerStatThrottleRate 120\n\tRailsAutoDetect On\n</IfModule>" }
  let(:debian_passenger_load_content) { "LoadModule passenger_module #{debian_gem_path}/passenger-#{passenger_version}/ext/apache2/mod_passenger.so" }

  # Iterate through all supported operatingsystems
  ['redhat', 'debian', 'darwin'].each do |current_os|
    context "on #{current_os} family operatingsystems" do
      let(:facts) do
        { :osfamily        => current_os,
          :operatingsystem => current_os
        }
      end
      let(:params) do
        {
          :passenger_version  => passenger_version,
          :passenger_provider => passenger_provider
        }
      end
      
      it { should include_class('apache') }
      it { should include_class('apache::dev') }

      if current_os == 'redhat'
        it 'should install the libcurl-devel package' do
          subject.should contain_package('libcurl-devel').with(
            'ensure' => 'present'
          )
        end

        it 'should install the Passenger config file' do
          subject.should contain_file('/etc/httpd/conf.d/passenger.conf').with(
            'ensure'  => 'present',
            'owner'   => '0',
            'group'   => '0',
            'mode'    => '0644',
            'content' => eval(current_os + '_conf_content')
          )
        end
      elsif current_os == 'debian'
        ['libopenssl-ruby', 'libcurl4-openssl-dev'].each do |deb_pkg|
          it "should install the #{deb_pkg} package" do
            subject.should contain_package(deb_pkg).with(
              'ensure' => 'present'
            )
          end
        end

        ['passenger.load', 'passenger.conf'].each do |deb_file|
          it "should install the #{deb_file} file into mods_available" do
            subject.should contain_file("/etc/apache2/mods-available/#{deb_file}").with(
              'ensure'  => 'present',
              'owner'   => '0',
              'group'   => '0',
              'mode'    => '0644',
              # The below is ugly - basically I'm trying to refer to the let helper methods above
              #  in the format of 'debian_passenger_conf_content'. The problem is that I need
              #  to use 'passenger.conf' for the filename, but 'passenger_conf' in the
              #  eval to match the let helper methods. Would LOVE to see someone make this
              #  both cleaner and simpler!
              'content' => eval('debian_' + deb_file.gsub(/\./, '_') + '_content')
            )
          end

          it "should install the #{deb_file} symlink into mods_enabled" do
            subject.should contain_file("/etc/apache2/mods-enabled/#{deb_file}").with(
              'ensure'  => 'link',
              'target'  => "/etc/apache2/mods-available/#{deb_file}",
              'owner'   => '0',
              'group'   => '0',
              'mode'    => '0777'
            )
          end
        end
      end

      it 'should install the passenger package' do
        subject.should contain_package('passenger').with(
          'ensure'   => passenger_version,
          'provider' => passenger_provider,
          'name'     => 'passenger'
        )
      end

      it 'should compile the passenger package' do
        subject.should contain_exec('compile-passenger').with(
          'path'      => [ "#{eval(current_os + '_gem_path')}/bin", '/usr/bin', '/bin' ],
          'command'   => 'passenger-install-apache2-module -a',
          'logoutput' => 'on_failure',
          'creates'   => eval(current_os + '_mod_passenger_location')
        )
      end
    end
  end
end
