# config/initializers/ood_appkit.rb
require "ood_core"

OODClusters = OodCore::Clusters.new(
  OodAppkit.clusters.select(&:job_allow?)
)

OODClusters.each(&:job_adapter)

# make copies of owens cluster to get 20,000 jobs
19.times do |x|
  OODClusters = OodCore::Clusters.new(OODClusters.to_a + [OodCore::Cluster.new(OODClusters[:owens].to_h.merge({id: :"owens#{x}", metadata: {title: "Owens#{x}"} }))])
end

# require "ood_core/job/adapters/torque/error"
# require "ood_core/job/adapters/torque/attributes"
# require "ood_core/job/adapters/torque/ffi"
# require "ood_core/job/adapters/torque/batch"

class OodCore::Job::Adapters::Torque::Batch
  alias_method :orig_get_jobs, :get_jobs

  #FIXME: since the filters could be a mixture of Info and attribute specific fields,
  # we should allow both of these keys in the array
  # so :jobname => :Job_Name but :egroup isn't in Info key list so its just :egroup
  #
  # Also the info_hash should have a native: {} and then attributes specified

  def get_jobs(id: '', filters: [ :job_state, :queue, :Job_Name, :Account_Name, :job_id, :resources_used, :Job_Owner, :egroup ])
    orig_get_jobs(id: id, filters: filters)
  end
end


Rails.application.config.to_prepare do
  ::Rack::MiniProfiler.profile_method(OodCore::Job::Adapters::Torque::Batch, :get_jobs) { "Torque::Batch#get_jobs"  }
  ::Rack::MiniProfiler.profile_method(OodCore::Job::Adapters::Torque, :info_all) { "info_all called"  }
end

# example filter for a single user's jobs
Filter.list << Filter.new(
  title: "osu9725 Jobs",
  filter_id: "osu9725"
) { |job| job.job_owner == 'osu9725' }

# example filter for a groups
group = OodSupport::User.new.group.name
Filter.list << Filter.new(
  title: "Your Group's Jobs (#{group})",
  filter_id: "group"
) { |job| job.native[:egroup] == group }
