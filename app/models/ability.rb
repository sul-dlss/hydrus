class Ability

  include CanCan::Ability
  include Hydra::Ability

  AUTH = Hydrus::Authorization
  
  def hydra_default_permissions(user, session, *args)

    # Read.

    can(:read, [String, ActiveFedora::Base]) do |obj|
      AUTH.can_read_object(user, get_fedora_object(obj))
    end

    cannot(:read, SolrDocument)

    # Create.

    can(:create_collections, :all) if AUTH.can_create_collections(user)

    can(:create_items_in, [String, Hydrus::Collection]) do |obj|
      AUTH.can_create_items_in(user, get_fedora_object(obj))
    end

    # Update/edit.

    can([:edit, :update], [String, ActiveFedora::Base]) do |obj|
      AUTH.can_edit_object(user, get_fedora_object(obj))
    end

    cannot([:edit, :update], SolrDocument)

    # Review (approve/disapprove).

    can(:review, [String, ActiveFedora::Base]) do |obj|
      AUTH.can_review_item(user, get_fedora_object(obj))
    end

    # Destroy.

    cannot(:destroy, String)
    cannot(:destroy, ActiveFedora::Base)
    cannot(:destroy, SolrDocument)

  end

  # Takes a String (presumably a pid) or an ActiveFedora object.
  # Returns the corresponding ActiveFedora object.
  def get_fedora_object(obj)
    return obj.kind_of?(String) ?
           ActiveFedora::Base.find(obj, :cast => true) : obj
  end

end
