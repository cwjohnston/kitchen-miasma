require 'json'
require 'miasma'
require 'pry'
require 'retryable'

require 'kitchen'
require 'kitchen/miasma/version'

module Kitchen
  module Driver
    class Miasma < SSHBase

      plugin_version Kitchen::Driver::MIASMA_VERSION

      default_config(:username, nil)
      default_config(:key_name, nil)
      default_config(:key_path, nil)
      default_config(:sudo, true)
      default_config(:port, 22)
      default_config(:retryable_tries, 60)
      default_config(:retryable_sleep, 5)
      default_config(:compute_provider) do
        {
          :name => 'aws',
          :aws_region => ENV['AWS_DEFAULT_REGION'],
          :aws_access_key_id => ENV['AWS_ACCESS_KEY_ID'],
          :aws_secret_access_key => ENV['AWS_SECRET_ACCESS_KEY']
        }
      end

      default_config(:image_id) do |driver|
        driver.default_image_id
      end

      default_config(:flavor_id) do |driver|
        driver.default_flavor_id
      end

      required_config(:key_name)

      def compute
        @compute ||= ::Miasma.api(
          :type => 'compute',
          :provider => config[:compute_provider][:name],
          :credentials => config[:compute_provider]
        )
      end

      # Returns defaults for known compute providers
      # @return [Smash]
      def images
        @images ||= begin
                      json_file = File.join(
                        File.dirname(__FILE__), %w(.. .. .. data), "#{config[:compute_provider][:name]}.json"
                      )
                      if File.exist?(json_file)
                        Smash.new(JSON.load(IO.read(json_file)))
                      else
                        warn("Failed to load defaults for #{config[:compute_provider][:name]} provider.")
                        Smash.new
                      end
                    end
      end

      # Returns the default image ID for the compute provider's given region.
      # @returns [String] default image ID
      def default_image_id
        region_name = config[:compute_provider]
        region_map = images.get(:regions, region_name)
        image_id = region_map && region_map[instance.platform.name]

        if image_id.nil?
          error("Could not determine default image_id in #{region_name} region for platform #{instance.platform.name}")
        end

        image_id
      end

      # Retrieve provider's default flavor id from image map
      # @return
      def default_flavor_id
        flavor_id = images['default_flavor_id']

        if flavor_id.nil?
          error("Could not determine default flavor_id for platform #{instance.platform.name} via #{config[:compute_provider][:name]}")
        end

        flavor_id
      end

      def configure_transport(state)
        if instance.transport[:username] == instance.transport.class.defaults[:username]
          image_username = images['usernames'][instance.platform.name]
          state[:username] = image_username if image_username
        end

        if config[:key_path]
          state[:key_path] = config[:key_path]
        end

        if config[:port]
          state[:port] = instance.transport[:port] = config[:port]
        end
      end

      def provision_server
        begin
          server = compute.servers.build(instance_data)
          server.save
          server
        rescue => e
          "Error provisioning server: #{e}"
        end
      end

      def instance_data
        {
          :name => instance.name,
          :flavor_id => config[:flavor_id],
          :image_id => config[:image_id],
          :key_name => config[:key_name]
        }
      end

      def create(state)
        return if state[:server_id]

        configure_transport(state)

        server = provision_server
        state[:server_id] = server.id

        Retryable.retryable(
          :tries => config[:retryable_tries],
          :sleep => config[:retryable_sleep],
          :on => TimeoutError
        ) do |retries, exception|

          c = retries * config[:retryable_sleep]
          t = config[:retryable_tries] * config[:retryable_sleep]
          info "Waited #{c}/#{t} for instance #{state[:server_id]} to become ready"
          server.reload
          ready = server.state == :running
          unless ready
            raise TimeoutError
          end
        end

        info("Instance #{state[:server_id]} created")
        state[:hostname] = server.address
        instance.transport.connection(state).wait_until_ready
      end

      def destroy(state)
        return unless state[:server_id]
        instance.transport.connection(state).close
        servers = compute.servers.all.select { |x| x.id == state[:server_id] }
        server = servers.first
        server.destroy

        Retryable.retryable(
          :tries => config[:retryable_tries],
          :sleep => config[:retryable_sleep],
          :on => TimeoutError
        ) do |retries, exception|

          c = retries * config[:retryable_sleep]
          t = config[:retryable_tries] * config[:retryable_sleep]
          info "Waited #{c}/#{t} for instance #{state[:server_id]} to be destroyed"
          server.reload
          destroyed = server.state == :terminated
          unless destroyed
            raise TimeoutError
          end
        end

        state.delete(:server_id)
        state.delete(:hostname)
      end

    end

  end
end
