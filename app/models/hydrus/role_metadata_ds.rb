class Hydrus::RoleMetadataDS < ActiveFedora::NokogiriDatastream

  include SolrDocHelper
  include Hydrus::GenericDS
  
  set_terminology do |t|
    t.root :path => 'roleMetadata'

    t.actor do
      t.identifier do
        t.type_ :path => {:attribute => 'type'}
      end
      t.name
    end
    t.person :ref => [:actor], :path => 'person'
    t.group  :ref => [:actor], :path => 'group'
    
    t.person_id :proxy => [:person, :identifier]

    t.role do
      t.type_ :path => {:attribute => 'type'}
      t.person :ref => [:person]
      t.group  :ref => [:group]
    end
    
    # APO roles
    t.collection_manager   :ref => [:role], :attributes => {:type => 'hydrus-collection-manager'}
    t.collection_depositor :ref => [:role], :attributes => {:type => 'hydrus-collection-depositor'}
    t.collection_reviewer  :ref => [:role], :attributes => {:type => 'hydrus-collection-reviewer'}
    t.collection_viewer    :ref => [:role], :attributes => {:type => 'hydrus-collection-viewer'}
    t.collection_owner    :proxy => [:collection_manager, :person, :identifier]
    # item object roles
    t.item_depositor       :ref => [:role], :attributes => {:type => 'hydrus-item-depositor'}
  end

  def to_solr(solr_doc=Hash.new, *args)
    find_by_xpath('/roleMetadata/role/*').each do |actor|
      role_type = toggle_hyphen_underscore(actor.parent['type']) # eg hydrus_item_depositor
      val = [
        actor.at_xpath('identifier/@type'),  # eg sunetid
        actor.at_xpath('identifier/text()')  # eg ggreen
      ].join ':'
      f1 = "apo_role_#{actor.name}_#{role_type}" # eg apo_role_person_hydrus_collection_manager
      f2 = "apo_role_#{role_type}"               # eg apo_role_hydrus_collection_manager
      add_solr_value(solr_doc, f1, val, :string, [:searchable, :facetable])
      add_solr_value(solr_doc, f2, val, :string, [:searchable, :facetable])
      if ['hydrus_collection_manager','hydrus_collection_depositor'].include? role_type
        add_solr_value(solr_doc, "apo_register_permissions", val, :string, [:searchable, :facetable])
      end
    end
    solr_doc
  end

  # Takes a string       (eg, hydrus-item-foo or hydrus_collection_bar)
  # Returns a new string (eg, hydrus_item_foo or hydrus-collection-bar).
  TOGGLE_HYPHEN_REGEX = / \A (hydrus) ([_\-]) (collection|item) \2 ([a-z]) /ix
  def toggle_hyphen_underscore(role_type)
    role_type.sub(TOGGLE_HYPHEN_REGEX) {
      [$1, $3, $4].join($2 == '_' ? '-' : '_')
    }
  end

  # Adding/removing nodes.

  # if the role node exists, add the person node to it; 
  #  otherwise, create the role node and then add the person node.  
  def add_person_with_role(id, role_type)
    role_node = find_by_xpath("/roleMetadata/role[@type='#{role_type}']")
    if role_node.size == 0
      new_role_node = insert_role(role_type)
      return insert_person(new_role_node, id)
    else
      return insert_person(role_node, id)
    end
  end  

  # if the role node exists, add an empty person node to it; 
  #  otherwise, create the role node and then add an empty person node
  def add_empty_person_to_role(role_type)
    add_person_with_role("", role_type)
  end  

  def insert_role(role_type)
    add_hydrus_child_node(ng_xml.root, :role, role_type)
  end

  def insert_person(role_node, sunetid)
    add_hydrus_child_node(role_node, :person, sunetid)
  end

  def insert_group(role_node, group_type)
    add_hydrus_child_node(role_node, :group, group_type)
  end

  # OM templates.

  define_template :role do |xml, role_type|
    xml.role(:type => role_type)
  end

  define_template :person do |xml, sunetid|
    xml.person {
      xml.identifier(:type => 'sunetid') { xml.text(sunetid) }
      xml.name
    }
  end

  define_template :group do |xml, group_type|
    xml.group {
      xml.identifier(:type => group_type)
      xml.name
    }
  end

  # Empty XML document.

  def self.xml_template
    Nokogiri::XML::Builder.new do |xml|
      xml.roleMetadata
    end.doc
  end

end
