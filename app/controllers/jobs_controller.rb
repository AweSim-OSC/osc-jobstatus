class JobsController < ApplicationController
  include ApplicationHelper

  def index
    @jobfilter = get_filter
    @jobcluster = get_cluster

    respond_to do |format|
      format.html # index.html.erb
      format.json {
        jobs = []
        errors = []
        job_filter = Filter.list.find(Filter.all_filter) { |f| f.filter_id == @jobfilter }
        #FIXME: clusters = @jobcluster == 'all' ? OODClusters : OODClusters.select {|cluster| cluster.id == @jobcluster }
        clusters = OODClusters.select { |cluster| @jobcluster == 'all' || cluster == OODClusters[@jobcluster]  }

        # FIXME: handle exceptions from info_where_owner, info_all calls
        clusters.each do |cluster|
          job_info = job_filter.user? ? cluster.job_adapter.info_where_owner(OodSupport::User.new.name) : cluster.job_adapter.info_all
          jobs += convert_info(job_filter.apply(job_info), cluster)
        end

        render :json => Rack::MiniProfiler.step("render #{jobs.count} jobs as json"){ { data: jobs, errors: errors }.to_json }
      }
    end
  end

  # Used to send the data to the Datatable.
  def json
    #Only allow the configured servers to respond
    if cluster = OODClusters[params[:cluster].to_s.to_sym]
      render '/jobs/extended_data', :locals => {:jobstatusdata => get_job(params[:pbsid], cluster) }
    else
      msg = "Request did not specify an available cluster. "
      msg += "Available clusters are: #{OODClusters.map(&:id).join(',')} "
      msg += "But specified cluster is: #{params[:cluster]}"
      render :json => { name: params[:pbsid], error: msg }
    end
  end

  def delete_job

    # Only delete if the pbsid and host params are present and host is configured in servers.
    # PBS will prevent a user from deleting a job that is not their own and throw an error.
    cluster = OODClusters[params[:cluster].to_sym]
    if (params[:pbsid] && cluster)
      job_id = params[:pbsid].to_s.gsub(/_/, '.')

      begin
        cluster.job_adapter.delete(job_id)

        # It takes a couple of seconds for the job to clear out
        # Using the sleep to wait before reload
        sleep(2.0)
        redirect_to root_url, :notice => "Successfully deleted " + job_id
      rescue
        redirect_to root_url, :alert => "Failed to delete " + job_id
      end
    else
      redirect_to root_url, :alert => "Failed to delete."
    end
  end

  private

  # Get the extended data for a particular job.
  #
  # @param [String] jobid The id of the job
  # @param [String] cluster The id of the cluster as string
  #
  # @return [Jobstatusdata] The job data as a Jobstatusdata object
  def get_job(jobid, cluster)
    begin
      data = OODClusters[cluster].job_adapter.info(jobid)

      raise OodCore::JobAdapterError if data.native.nil?
      Jobstatusdata.new(data, cluster, true)

    rescue OodCore::JobAdapterError
      OpenStruct.new(name: jobid, error: "No job details because job has already left the queue." , status: status_label("completed") )
    rescue => e
      OpenStruct.new(name: jobid, error: "No job details available.\n" + e.backtrace.to_s, status: status_label("") )
    end
  end

  # Returns the filter id from the parameter if it is valid
  #
  # @return [String, nil] the filter id if valid
  def get_filter
    if params[:jobfilter] && Filter.list.any? { |f| f.filter_id == params[:jobfilter] }
      params[:jobfilter]
    end
  end

  # Returns the cluster id from the parameter if it is valid
  #
  # @return [String, nil] the cluster id if valid
  def get_cluster
    if params[:jobcluster] && (OODClusters[params[:jobcluster]] || params[:jobcluster] == 'all')
      params[:jobcluster]
    end
  end

  def convert_info(info_all, cluster)
    extended_available = %w(torque slurm lsf pbspro).include?(cluster.job_config[:adapter])

    info_all.map { |j|
      {
        cluster_title: cluster.metadata.title || cluster.id.to_s.titleize,
        status: status_for_job(j),
        cluster: cluster.id.to_s,
        pbsid: j.id,
        jobname: j.job_name,
        account: j.accounting_id,
        queue: j.queue_name,
        walltime_used: j.wallclock_time,
        username: j.job_owner,
        extended_available: extended_available
      }
    }
  end

  def status_for_job(job)
    status_label(job.status.state.to_s)
  end

  def status_label(status)
    case status
    when "completed"
      label = "Completed"
      labelclass = "label-success"
    when "running"
      label = "Running"
      labelclass = "label-primary"
    when "queued"
      label = "Queued"
      labelclass = "label-info"
    when "queued_held"
      label = "Hold"
      labelclass = "label-warning"
    when "suspended"
      label = "Suspend"
      labelclass = "label-warning"
    else
      label = "Undetermined"
      labelclass = "label-default"
    end
    "<div style='white-space: nowrap;'><span class='label #{labelclass}'>#{label}</span></div>".html_safe
  end
end
