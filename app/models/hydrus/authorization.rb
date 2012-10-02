module Hydrus::Authorization

  ####
  # SUNET IDs of administrators and collection creators.
  ####

  def self.administrators
    return Set.new %w(
      hfrost
    )
  end

  def self.collection_creators
    ids = Set.new %w(
      archivist1
      archivist2
    )
    return administrators.union(ids)
  end

  ####
  # Roles.
  ####

  def self.collection_editor_roles
    return Set.new %w(
      hydrus-collection-manager
      hydrus-collection-depositor
    )
  end

  def self.item_creator_roles
    return Set.new %w(
      hydrus-collection-manager
      hydrus-collection-depositor
      hydrus-collection-item-depositor
    )
  end

  def self.item_editor_roles
    return Set.new %w(
      hydrus-collection-manager	
      hydrus-collection-depositor	
      hydrus-item-depositor	
      hydrus-item-manager
    )
  end

  ####
  # Abilities and related methods.
  ####

  # Takes two Sets.
  # Returns true if they have any items in common.
  def self.does_intersect(s1, s2)
    return s1.intersection(s2).size > 0
  end

  # Returns true if the given user is a Hydrus administrator.
  def self.is_administrator(user)
    return administrators.include?(user.sunetid)
  end

  # Returns true if the given user can create new Hydrus Collections.
  def self.can_create_collections(user)
    return collection_creators.include?(user.sunetid)
  end

  # Returns true if the given user can create new Items
  # in the given Collection.
  def self.can_create_items_in(user, coll)
    return true if is_administrator(user)
    user_roles = coll.roles_of_person(user.sunetid)
    return does_intersect(user_roles, item_creator_roles)
  end

  # Takes a user and a Collection or Item.
  # Returns true if the user can edit the object.
  def self.can_edit_object(user, obj)
    c = obj.hydrus_class_to_s.downcase      # 'collection' or 'item'
    return send("can_edit_#{c}", user, obj)
  end

  # Returns true if the given user can edit the given Collection.
  def self.can_edit_collection(user, coll)
    return true if is_administrator(user)
    user_roles = coll.roles_of_person(user.sunetid)
    return does_intersect(user_roles, collection_editor_roles)
  end

  # Returns true if the given user can edit the given Item.
  def self.can_edit_item(user, item)
    sid = user.sunetid
    return true if is_administrator(user)
    user_roles = item.roles_of_person(sid) + item.apo.roles_of_person(sid)
    return does_intersect(user_roles, item_editor_roles)
  end

end