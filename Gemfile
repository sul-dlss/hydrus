source 'https://rubygems.org'
source 'http://sul-gems.stanford.edu'

gem 'rails', '3.2.14'

gem 'dor-services', ">= 4.3.1"
gem 'sul_chrome', '~> 0.1.0'
gem 'about_page'
gem 'is_it_working-cbeer', "~> 1.0.13"
gem 'assembly-objectfile', "1.5.0"
gem 'blacklight', '~>4.4'
gem 'hydra-head', '~> 5.1'
gem 'active-fedora', "~> 5.7.1"
gem 'solrizer', '~> 2.2'
gem 'devise', '~> 2.2.5'
gem 'carrierwave', "0.6.2"
gem 'jquery-rails'
gem 'dynamic_form'
gem 'bootstrap-datepicker-rails'
gem 'cancan'
gem 'validates_email_format_of'
gem 'coderay'
gem 'whenever', "~> 0.8.3"

group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem "bootstrap-sass", '2.3.2.1'
  gem 'therubyracer'
  gem 'uglifier', '>= 1.0.3'
end

# gems only needed for particular environments

group :test do
  gem 'database_cleaner'
  gem 'rspec-rails', '>=2.9.0'
  gem 'capybara'
  gem 'simplecov'
  gem 'simplecov-rcov'
end

group :development, :test do
  gem 'jettywrapper', '1.4.1'
  gem 'sqlite3'
  gem 'awesome_print'
  gem 'launchy'
  gem 'ruby-prof', :platform => 'ruby_19'
  gem 'debugger', :platform => 'ruby_19'
  gem 'byebug', :platform => 'ruby_20'
	gem 'letter_opener'
end

group :development do
  gem 'looksee', :platform => 'ruby_19'
	gem 'newrelic_rpm'
end

group :production, :dortest do
  gem 'mysql2'
  gem 'activerecord-mysql-adapter'
end

gem 'quiet_assets', :group => :development

