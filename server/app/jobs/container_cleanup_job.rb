require 'celluloid'
require_relative '../services/logging'

class ContainerCleanupJob
  include Celluloid
  include CurrentLeader
  include Logging

  def initialize(perform = true)
    async.perform if perform
  end

  def perform
    info 'starting to cleanup stale containers'
    loop do
      if leader?
        cleanup_stale_containers
        cleanup_reserved_overlay_cidrs
        destroy_deleted_containers

        sleep 1.minute.to_i
      end
    end
  end

  def cleanup_stale_containers
    Container.where(:updated_at.lt => 2.minutes.ago).each do |c|
      if c.host_node && c.host_node.connected?
        c.mark_for_delete
      elsif c.host_node.nil?
        c.destroy
      end
    end
  end

  def cleanup_reserved_overlay_cidrs
    OverlayCidr.where(:reserved_at.ne => nil, :reserved_at.lt => 2.minutes.ago, :container_id => nil).each do |c|
      c.set(:reserved_at => nil)
    end
  end

  def destroy_deleted_containers
    Container.deleted.where(:deleted_at.lt => 1.minutes.ago).each do |c|
      c.destroy
    end
  end
end
