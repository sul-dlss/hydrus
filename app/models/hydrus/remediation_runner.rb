class Hydrus::RemediationRunner

  include Hydrus::SolrQueryable

  attr_accessor(
    :pid,
    :object_type,
    :object_version,
    :remed_method,
    :remed_version,
    :fobj,
    :log,
    :needs_versioning,
    :no_versioning,
    :no_save,
    :force
  )

  LOWEST_VERSION = '0000.00.00a'

  # Creates a new RemediationRunner.
  # Typically invoked via the remediations/run.rb script.
  def initialize(opts = {})
    # Unpack options passed on command line.
    @force         = opts[:force]
    @no_versioning = opts[:no_versioning]
    @no_save       = opts[:no_save]
    # Set values we always need -- eg, for logging.
    @remed_version = LOWEST_VERSION
    @pid           = 'UNKNOWN_PID'
    # Set up the logger.
    @log           = Logger.new("#{Rails.root}/log/remediation.log", 10, 10240000)
    @log.formatter = proc { |severity, datetime, progname, msg|
      "#{severity}: #{datetime}: #{pid}: #{remed_method}: #{msg}\n"
    }
  end

  # Runs all remediations for all Hydrus objects.
  # The all_hydrus_objects() method returns a list of hashes (one per object)
  # obtained via a SOLR query. Each hash contains the following:
  #   :pid
  #   :object_type     # String: Item, Collection, or AdminPolicyObject
  #   :object_version  # Used to determine whether a remediation needs to run.
  def run
    rems = discover_remediations()
    all_hydrus_objects().each do |h|
      rems.each do |rem|
        send(rem, h)
      end
    end
  end

  # Finds remediation scripts in the remediations directory. Requires those
  # files, and returns a list of the corresponding remediation method names.
  # For example:
  #   script             = 'remediations/2013.02.27a.rb'
  #   remediation method = 'remediation_2013_02_27a'
  def discover_remediations
    g = File.expand_path(File.join(Rails.root, 'remediations', '2*.rb'))
    remediations = Dir.glob(g)
    methods = []
    remediations.each do |r|
      require r
      m = File.basename(r, '.rb').gsub(/\./, '_')
      methods << 'remediation_' + m
    end
    return methods
  end

  # Called by a remediation method, which always receives one of the
  # hashes from all_hydrus_objects(). Unpacks that hash into various
  # attributes, and also stores the method name and associated version
  # number associated with the running remediation method.
  def unpack_args(h, remediation_method)
    # Unpack the object's hash from the SOLR query.
    @pid            = h[:pid]
    @object_type    = h[:object_type]
    @object_version = h[:object_version] || LOWEST_VERSION
    # Store info about the currently running remediation method.
    @remed_method   = remediation_method.to_s
    @remed_version  = @remed_method.sub(/\A\D+/, '').gsub(/_/, '.')
    # Log that we've started.
    log.info("----")
    log.info("started")
  end

  # Loads up the Fedora object.
  def load_fedora_object
    log.info("loading fedora object")
    @fobj = ActiveFedora::Base.find(@pid, :cast => true)
  end

  # Returns true if the currently running remediation method needs to be
  # applied to the currently loaded Fedora object, and logs accordingly.
  def remediation_is_needed
    msg = 'skipping'
    msg = "running in --force mode" if force
    msg = "is needed" if remed_version > object_version
    log.info(msg)
    return msg != 'skipping'
  end

  # Some code to wrap version-handling and save-handling around the
  # particular steps of a remediation method. Takes the remediation
  # code via a block.
  def do_remediation
    # Open new version if necessary.
    needs_versioning = fobj.is_item? && fobj.is_published
    needs_versioning = false if no_versioning
    open_new_version_of_object()
    # Run the remediation code that was passed via a block,
    # and update the object's version to the version associated
    # with the currently running remediation method.
    log.info('starting remediation code')
    yield
    log.info('finished remediation code')
    fobj.object_version = remed_version
    # Save object, and close version if necessary.
    try_to_save_object()
    close_version_of_object()
  end

  # Tries to open a new administrative version of the fedora object, if needed.
  def open_new_version_of_object
    return unless needs_versioning
    begin
      fobj.open_new_version(:description    => remed_method,
                            :significance   => :admin,
                            :is_remediation => true)
      log.info('open_new_version(success)')
    rescue Exception => e
      needs_versioning = false  # So we won't try to close the version.
      log.warn("open_new_version(FAILED): #{e.message}")
    end
  end

  # Tries to save the fedora object.
  def try_to_save_object
    return if no_save
    log.info('trying to save')
    if fobj.save(:is_remediation => true)
      log.info('saved')
    else
      es = fobj.errors
      msg = es ? es.messages.inspect : 'unknown reason'
      log.warn("save failed: #{msg}")
    end
  end

  # Tries to close the version.
  def close_version_of_object
    return unless needs_versioning
    begin
      fobj.close_version()
      log.info('close_version(success)')
    rescue Exception => e
      log.warn("close_version(FAILED): #{e.message}")
    end
  end

end