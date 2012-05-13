require 'spec_helper'
describe 'passenger', :type => :class do
  let(:passenger_version) { '1.2.3' }
  let(:passenger_provider) { 'gem' }

  let(:redhat_gem_binary_path) { '/usr/lib/ruby/gems/1.8/gems/bin' }
  let(:debian_gem_binary_path) { '/var/lib/gems/1.8/bin' }
  let(:darwin_gem_binary_path) { '/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin' }

  let(:redhat_mod_passenger_location) { "/usr/lib/ruby/gems/1.8/gems/passenger-#{passenger_version}/ext/apache2/mod_passenger.so" }
  let(:debian_mod_passenger_location) { "/var/lib/gems/1.8/gems/passenger-#{passenger_version}/ext/apache2/mod_passenger.so" }
  let(:darwin_mod_passenger_location) { "/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/passenger-#{passenger_version}/ext/apache2/mod_passenger.so" }

  let(:redhat_conf_content) { "LoadModule passenger_module /usr/lib/ruby/gems/1.8/gems/passenger-#{passenger_version}/ext/apache2/mod_passenger.so\nPassengerRoot /usr/lib/ruby/gems/1.8/gems/passenger-#{passenger_version}\nPassengerRuby /usr/bin/ruby\n\n# you probably want to tune these settings\nPassengerHighPerformance on\nPassengerMaxPoolSize 12\nPassengerPoolIdleTime 1500\n# PassengerMaxRequests 1000\nPassengerStatThrottleRate 120\nRailsAutoDetect On" } 
  let(:debian_conf_content) { "LoadModule passenger_module /usr/lib/ruby/gems/1.8/gems/passenger-#{passenger_version}/ext/apache2/mod_passenger.so\nPassengerRoot /usr/lib/ruby/gems/1.8/gems/passenger-#{passenger_version}\nPassengerRuby /usr/bin/ruby\n\n# you probably want to tune these settings\nPassengerHighPerformance on\nPassengerMaxPoolSize 12\nPassengerPoolIdleTime 1500\n# PassengerMaxRequests 1000\nPassengerStatThrottleRate 120\nRailsAutoDetect On" }
  let(:darwin_conf_content) { "LoadModule passenger_module /usr/lib/ruby/gems/1.8/gems/passenger-#{passenger_version}/ext/apache2/mod_passenger.so\nPassengerRoot /usr/lib/ruby/gems/1.8/gems/passenger-#{passenger_version}\nPassengerRuby /usr/bin/ruby\n\n# you probably want to tune these settings\nPassengerHighPerformance on\nPassengerMaxPoolSize 12\nPassengerPoolIdleTime 1500\n# PassengerMaxRequests 1000\nPassengerStatThrottleRate 120\nRailsAutoDetect On" }

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
          'path'      => [ eval(current_os + '_gem_binary_path'), '/usr/bin', '/bin' ],
          'command'   => 'passenger-install-apache2-module -a',
          'logoutput' => 'on_failure',
          'creates'   => eval(current_os + '_mod_passenger_location')
        )
      end

      # 
      # it 'should set up /etc/haproxy/haproxy.cfg as a concat resource' do
      #   subject.should contain_concat('/etc/haproxy/haproxy.cfg').with(
      #     'owner' => '0',
      #     'group' => '0',
      #     'mode'  => '0644'
      #   )
      # end
    
    end
  end
end
