class HydrusCollectionsController < ApplicationController

  include Hydra::Controller::ControllerBehavior
  include Hydra::AssetsControllerHelper  # This is to get apply_depositor_metadata method
  include Hydra::Controller::UploadBehavior
  include Hydrus::AccessControlsEnforcement

  before_filter :enforce_access_controls
  before_filter :setup_attributes, :except => :new
  before_filter :redirect_if_not_correct_object_type, :only => [:edit,:show,:update]

  def index
    flash[:warning]="You need to log in."
    redirect_to new_user_session_path
  end

  def setup_attributes
    @document_fedora  = Hydrus::Collection.find(params[:id])
  end

  def show
  end

  def edit
  end

  def new
    apo = create_apo(current_user)
    dor_obj = Hydrus::GenericObject.register_dor_object(current_user, 'collection', apo.pid)
    collection = dor_obj.adapt_to(Hydrus::Collection)
    collection.remove_relationship :has_model, 'info:fedora/afmodel:Dor_Collection'
    collection.assert_content_model
    #TODO:  Initialize roleMetadata datastream with the collection-manager role for the current logged-in user
    collection.save
    redirect_to edit_polymorphic_path(collection)
  end

  def create_apo(user)
    args = [user, 'adminPolicy', Dor::Config.ur_apo_druid]
    apo  = Hydrus::GenericObject.register_dor_object(*args)
    apo  = apo.adapt_to(Hydrus::AdminPolicyObject)
    apo.remove_relationship :has_model, 'info:fedora/afmodel:Dor_AdminPolicyObject'
    apo.assert_content_model
    apo.save
    return apo
  end

  def person_roles_data(phc)
    # Takes a hash containing info like this:
    #   {
    #     "person_id"   => {"0"=>"ggreen",               "1"=>"bblack"},
    #     "person_role" => {"0"=>"collection-depositor", "1"=>"collection-manager"},
    #   }
    # Uses that info to return hash with SUNETIDs as keys and roles as values.
    h = {}
    phc['person_id'].each { |i, id|
      h[id] = phc['person_role'][i]
    }
    return h
  end

  def update
    notice = []
    phc = params["hydrus_collection"]

    phc[:person_roles] = person_roles_data(phc) if (
      phc and
      (phc.has_key?('person_id') or phc.has_key?('person_role'))
    )
    
    @document_fedora.update_attributes(phc) if phc
    if params.has_key?(:add_link)
      @document_fedora.descMetadata.insert_related_item
    elsif params.has_key?(:add_person)
      # FIXME:  hardcoded role ...
      @document_fedora.add_empty_person_to_role('from_controller')
    end

#    logger.debug("attributes submitted: #{params['hydrus_collection'].inspect}")
    
    if @document_fedora.object_valid?
      @document_fedora.save
    else
      # invalid collection, generate errors to display to user
      errors = []  
      @document_fedora.object_error_messages.each do |field, error|
        errors << "#{field.to_s.humanize.capitalize} #{error.join(', ')}"
      end
      flash[:error] = errors.join("<br/>").html_safe
      render :edit and return
    end  
    
    notice << "Your changes have been saved."
    flash[:notice] = notice.join("<br/>").html_safe unless notice.blank?
    
    respond_to do |want|
      want.html {
        if params.has_key?(:add_link) or params.has_key?(:add_person)
          # if we want to pass on parameters to edit screen we'll need to use the named route
          #redirect_to edit_polymorphic_path(@document_fedora, :person_role=>"collection_viewer")
          redirect_to [:edit, @document_fedora]
        else
          redirect_to @document_fedora
        end
      }
      want.js {
        if params.has_key?(:add_link)
          render "add_link", :locals=>{:index=>@document_fedora.related_item_title.length-1}
        elsif params.has_key?(:add_person)
          render "add_person", :locals=>{:index=>@document_fedora.person_id.length-1}
        else
          render :json => tidy_response_from_update(@response)
        end
      }
    end
  end # update

  def destroy_value
    @document_fedora.descMetadata.remove_node(params[:term], params[:term_index])
    @document_fedora.save
    respond_to do |want|
      want.html {redirect_to :back}
      want.js
    end
  end

  # remove an 'actor' (person or group) form the roleMetadata
  def destroy_actor
    @document_fedora.remove_actor(params[:actor_id])
    @document_fedora.save
    respond_to do |want|
      want.html {redirect_to :back}
      want.js
    end
  end

  protected :create_apo

end
