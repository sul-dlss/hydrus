class Hydrus::HydrusPropertiesDS < ActiveFedora::OmDatastream

  include Hydrus::GenericDS
  include SolrDocHelper

  set_terminology do |t|
    t.root path: 'hydrusProperties'

    t.accepted_terms_of_deposit path: 'acceptedTermsOfDeposit'

    t.users_accepted_terms_of_deposit(path: 'usersAcceptedTermsOfDeposit') do
      t.user do
        t.date_accepted path: {attribute: 'dateAccepted'}
      end
    end

    t.requires_human_approval   path: 'requiresHumanApproval'
    t.reviewed_release_settings path: 'reviewedReleaseSettings'
    t.item_type                 path: 'itemType'
    t.object_status             path: 'objectStatus', index_as: [:symbol]
    t.disapproval_reason        path: 'disapprovalReason'
    t.submit_for_approval_time  path: 'submitForApprovalTime'
    t.last_modify_time          path: 'lastModifyTime'
    t.version_started_time      path: 'versionStartedTime'
    t.embargo_option            path: 'embargoOption'
    t.embargo_terms             path: 'embargoTerms'
    t.visibility_option         path: 'visibilityOption'
    t.license_option            path: 'licenseOption'
    t.prior_license             path: 'priorLicense'
    t.prior_visibility          path: 'priorVisibility'

    # When Hydrus objects are created, the version of the application
    # is stored here. Later, Hydrus remediation scripts can update this value.
    t.object_version            path: 'objectVersion', index_as: [:symbol]

    # Two variants of publish time:
    #   - The time the user clicks Open/Approve/Publish in UI.
    #       - Stored in hydrusProperties.
    #           submitted_for_publish_time
    #           initial_submitted_for_publish_time
    #       - Aligns conceptually with the is_published() method.
    #   - The time the object achieves published lifecycle in accessioning.
    #       - Stored in hydrusProperties, when 2nd version is opened.
    #           initial_publish_time
    #       - Obtained via workflow service.
    #           publish_time
    t.submitted_for_publish_time         path: 'submittedForPublishTime'
    t.initial_submitted_for_publish_time path: 'initialSubmittedForPublishTime'
    t.initial_publish_time               path: 'initialPublishTime'
  end

  define_template :user do |xml, username, datetime_accepted|
    xml.user(username,dateAccepted: datetime_accepted)
  end

  define_template :users_accepted_terms_of_deposit do |xml|
    xml.usersAcceptedTermsOfDeposit
  end

  # Empty XML document.
  def self.xml_template
    Nokogiri::XML::Builder.new do |xml|
      xml.hydrusProperties
    end.doc
  end

  # Takes a User object and a datetime String.
  # Adds info to the datastream indicating that the user accepted the terms of
  # deposit: either update the time (if user has done this before) or add a new
  # node. Note that this is done in the hydrusProperties of Collection objects,
  # not Items.
  def accept_terms_of_deposit(user, datetime_accepted)
    existing_user = ng_xml.at_xpath("//user[text()='#{user}']")
    if existing_user.nil?
      insert_user_accepting_terms_of_deposit(user, datetime_accepted)
    else
      existing_user['dateAccepted'] = datetime_accepted
    end
  end

  # Takes a User object and a datetime String.
  # Adds a node to the datastream indicating when the user accepted
  # the terms of deposit. Note that this is done in the hydrusProperties
  # of Collection objects, not Items.
  def insert_user_accepting_terms_of_deposit(user, datetime_accepted)
    k = :users_accepted_terms_of_deposit
    parent = find_by_terms(k).first
    parent = add_hydrus_child_node(ng_xml.root, k) if parent.nil?
    add_hydrus_child_node(parent, :user, user, datetime_accepted)
  end

end
