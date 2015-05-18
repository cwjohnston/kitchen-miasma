require 'pry'
require 'miasma'
require 'retryable'

module Kitchen
  module Driver

    class Miasma < Kitchen::Driver::SSHBase

      default_config(:username, nil)
      default_config(:image_id, nil)
      default_config(:flavor_id, nil)
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

      required_config(:image_id)

      def compute
        @compute ||= ::Miasma.api(
          :type => 'compute',
          :provider => config[:compute_provider][:name],
          :credentials => config[:compute_provider]
        )
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
        state[:username] = config[:username]
        return if state[:server_id]

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

      end

    end

  end
end
