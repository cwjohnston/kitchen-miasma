require 'logger'
require 'stringio'

require 'pry'

require 'kitchen/driver/miasma'
require 'kitchen/provisioner/dummy'
require 'kitchen/transport/dummy'
require 'kitchen/verifier/dummy'

describe Kitchen::Driver::Miasma do
  let(:logged_output) { StringIO.new }
  let(:logger)        { Logger.new(logged_output) }
  let(:config) { { :kitchen_root => '/kroot', :key_name => 'provider_key' } }
  let(:platform) { Kitchen::Platform.new(:name => 'ubuntu-14.04') }
  let(:suite) { Kitchen::Suite.new(:name => 'default') }
  let(:verifier) { Kitchen::Verifier::Dummy.new }
  let(:provisioner) { Kitchen::Provisioner::Dummy.new }
  let(:transport) { Kitchen::Transport::Dummy.new }
  let(:state_file) { double('state_file') }
  let(:state) { Hash.new }

  let(:non_default_compute_provider) do
    {
      :name => 'open_stack',
      :open_stack_username => 'alice',
      :open_stack_password => 'secret',
      :open_stack_region => 'us-west-2'
    }
  end

  let(:env) do
    {
      'AWS_DEFAULT_REGION' => 'us-west-2',
      'AWS_ACCESS_KEY_ID' => 'INVALID_ID',
      'AWS_SECRET_ACCESS_KEY' => 'INVALID_KEY'
    }
  end

  let(:default_data_fixture) do
    {
      'default_flavor_id' => 'm3.medium',
      'usernames' => {
        'ubuntu-14.04' => 'ubuntu'
      },
      'regions' => {
        'us-west-2' => {
          'ubuntu-14.04' => 'ami-159cad25'
        }
      }
    }
  end

  let(:non_default_data_fixture) do
    {
      'default_flavor_id' => 'm1.small',
      'usernames' => {
        'ubuntu-14.04' => 'openstack'
      },
      'regions' => {
        'us-west-2' => {
          'ubuntu-14.04' => 'ubuntu-image'
        }
      }
    }
  end

  let(:driver_object) { Kitchen::Driver::Miasma.new(config) }

  let(:driver) do
    d = driver_object
    instance
    d
  end

  let(:instance) do
    Kitchen::Instance.new(
      :verifier => verifier,
      :driver => driver_object,
      :logger => logger,
      :suite => suite,
      :platform => platform,
      :provisioner => provisioner,
      :transport => transport,
      :state_file => state_file
    )
  end

  before { stub_const("ENV", env) }

  it 'plugin_version is set to Kitchen::Driver::MIASMA_VERSION' do
    expect(driver.diagnose_plugin[:version]).to eq(Kitchen::Driver::MIASMA_VERSION)
  end

  context 'without a key path provided' do
    before do
      config[:key_name] = nil
    end

    it 'raises an exception' do
      expect { driver.verify_dependencies }.to raise_error(
        Kitchen::UserError, /key_name/
      )
    end
  end

  describe 'configuration' do

    it 'sets :key_path to nil by default' do
      expect(driver[:key_path]).to eq(nil)
    end

    it 'sets :username to nil by default' do
      expect(driver[:username]).to eq(nil)
    end

    it 'sets :port to 22 by default' do
      expect(driver[:port]).to eq(22)
    end

    it 'sets :retryable_tries to 60 by default' do
      expect(driver[:retryable_tries]).to eq(60)
    end

    it 'sets :retryable_sleep to 5 by default' do
      expect(driver[:retryable_sleep]).to eq(5)
    end

    it 'uses AWS credentials from environment variables as the defaults for :compute_provider' do
      expect(driver[:compute_provider]).to eq(
        :name => 'aws',
        :aws_region => 'us-west-2',
        :aws_access_key_id => 'INVALID_ID',
        :aws_secret_access_key => 'INVALID_KEY'
      )
    end

    context 'when the default :compute_provider is used' do
      before do
        allow_any_instance_of(Kitchen::Driver::Miasma).to receive(:images).and_return(default_data_fixture)
      end

      it 'returns the expected image id' do
        expect(driver[:image_id]).to eq('ami-159cad25')
      end
    end

    context 'when :comptue_provider is assigned a non-default value' do

      before do
        config[:compute_provider] = non_default_compute_provider
        allow_any_instance_of(Kitchen::Driver::Miasma).to receive(:images).and_return(non_default_data_fixture)
      end

      it 'overrides the default compute_provider' do
        expect(driver[:compute_provider]).to eq(non_default_compute_provider)
      end

      it 'returns the expected default flavor id' do
        expect(driver[:flavor_id]).to eq('m1.small')
      end

      it 'returns the expected default image id' do
        expect(driver[:image_id]).to eq('ubuntu-image')
      end

    end

  end

end

