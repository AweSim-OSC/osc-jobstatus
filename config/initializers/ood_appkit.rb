# config/initializers/ood_appkit.rb
require "ood_core"

OODClusters = OodCore::Clusters.new(
  OodAppkit.clusters.select(&:job_allow?)
)

OODClusters.each(&:job_adapter)

# require "ood_core/job/adapters/torque/error"
# require "ood_core/job/adapters/torque/attributes"
# require "ood_core/job/adapters/torque/ffi"
# require "ood_core/job/adapters/torque/batch"

class OodCore::Job::Adapters::Torque::Batch
  alias_method :orig_get_jobs, :get_jobs
  def get_jobs(id: '', filters: [ :job_state, :queue, :Job_Name, :Account_Name, :job_id, :resources_used ])
    orig_get_jobs(id: id, filters: filters)
  end
end


Rails.application.config.to_prepare do
  ::Rack::MiniProfiler.profile_method(OodCore::Job::Adapters::Torque::Batch, :get_jobs) { |a| "Torque::Batch#get_jobs"  }
end
