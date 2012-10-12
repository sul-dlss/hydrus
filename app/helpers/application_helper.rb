module ApplicationHelper
  include HydrusFormHelper

  def application_name
    'Stanford Digital Repository'
  end
  
  def license_image(license_code)
    if Hydrus::GenericObject.license_type(license_code) == 'creativeCommons'
      image_tag "licenses/" + license_code.downcase.gsub('-','_') + ".png"
    end
  end
  
  def license_link(license_code)
    license_name=Hydrus::GenericObject.license_human(license_code)
    license_type=Hydrus::GenericObject.license_type(license_code)
    if license_type == 'creativeCommons'
      link_to license_name,'http://creativecommons.org/licenses/'
    elsif license_type == 'openDataCommons'
      link_to license_name,'http://opendatacommons.org/licenses/'
    else 
      license_code
    end
  end
  
  def hydrus_format_date(input_string)
    input_string.blank? ? '' : input_string.to_date.strftime("%b %d, %Y")
  end

  def seen_beta_dialog?
    if session[:seen_beta_dialog]
      return true
    else
      session[:seen_beta_dialog]=true
      return false
    end
  end

  def render_head_content
    render_extra_head_content + content_for(:head)
  end

  def render_contextual_layout
    controller.controller_name == 'catalog' ? (render "shared/home_contents") : (render "shared/main_contents")
  end

  def hydrus_signin_link
    link_to("Sign in", new_signin_path(:referrer => request.fullpath), :class=>'signin_link', :"data-url" => new_signin_path(:referrer => request.fullpath))
  end
  
  def terms_of_deposit_path(pid)
    url_for(:controller=>'hydrus_items',:action=>'terms_of_deposit',:pid=>pid)
  end

  def terms_of_deposit_agree_path(pid)
    url_for(:controller=>'hydrus_items',:action=>'agree_to_terms_of_deposit',:pid=>pid)
  end
    
  def hydrus_strip(value)
    value.nil? ? "" : value.strip
  end

  # indicates if we should show the item edit tab for a given item
  # only if its not published yet, unless we are in development mode (to make development easier)
  def show_item_edit(item)
    can?(:edit,@document_fedora) && (!@document_fedora.is_published || ["development","test"].include?(Rails.env))
  end
  
  def edit_item_text(item)
    "Edit Draft"
  end
  
  # text to show on item view tab
  def view_item_text(item)
    item.is_published ? "Published Version" : "View Draft"
  end
  
  def hydrus_object_setting_value(obj)
    hydrus_is_empty?(obj) ? content_tag(:span, "not specified", :class => "unspecified") : obj
  end

  # a helper to create links to items that may or may not have titles yet
  def item_title_link(item)
    title_text=item.title.blank? ? 'new item' : item.title
    return link_to(title_text, polymorphic_path(item))
  end
  
  # Take a datetime string.
  # Returns a string using the default Hydrus date format.
  def formatted_datetime(datetime, k = :datetime)
    begin
      return Time.parse(datetime.to_s).strftime(datetime_format(k))
    rescue
      return nil
    end
  end

  def datetime_format(k)
    return (k == :date ? '%d-%b-%Y' :
            k == :time ? '%I:%M %P' : '%d-%b-%Y %I:%M %P')
  end

  def render_contextual_navigation(model)
    render :partial=>"#{view_path_from_model(model)}/navigation"
  end
  
  def view_path_from_model(model)
    model.class.to_s.pluralize.parameterize("_")
  end

  def select_status_checkbox_icon(field)
    content_tag(:i, nil, :class =>  field ? "icon-check" : "icon-minus")
  end
end
