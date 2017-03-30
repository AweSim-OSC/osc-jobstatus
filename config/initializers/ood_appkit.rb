# config/initializers/ood_appkit.rb

begin
  OODClusters = OodAppkit.clusters.select do |c|
    c.valid? &&
    c.resource_mgr_server? &&
    c.resource_mgr_server.is_a?(OodCluster::Servers::Torque)
  end.each_with_object({}) { |c, h| h[c.id] = c }
rescue
  # If OodAppkit.clusters is nil
  OODClusters = {}
end
