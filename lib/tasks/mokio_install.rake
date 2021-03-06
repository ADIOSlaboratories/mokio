require 'rake'
require 'mokio'
require 'rails/generators'

namespace :mokio do
  desc "Create database, running migrations and creating some default data for Mokio application"

  task :install, [:email, :password] => :environment do |t, args|
    args.with_defaults(:email => "admin@admin.com", :password => "admin")

    puts "\nRunning task: 'rake:db:create'...".green
    Rake::Task["db:create"].execute

    puts "\nRunning task: 'rake:db:migrate'...".green
    Rake::Task["db:migrate"].execute

    puts "\nCreating initial data...".green

    default_lang = Mokio::Lang.new({
      :name => Mokio.frontend_default_lang,
      :shortname => Mokio.frontend_default_lang,
      :active => true,
      :menu_id => Mokio.frontend_initial_pl,
      :id => 1
    })

    puts "\n\tCreated default lang '#{default_lang.name}'".green if default_lang.save
    menu = Mokio::Menu.find_by_name(default_lang.shortname)
    puts "\n\tCreated default initial menu '#{menu.name}'".green unless menu.nil?

    top_menu = Mokio::Menu.new({
      name: "top",
      seq: 1,
      deletable: false,
      editable: false,
      lang_id: 1,
      id: 2,
      content_editable: false,
      modules_editable: false,
      fake: true,
      parent: menu,
      slug: "top"
    })
    top_menu.build_meta
    puts "\n\tCreated default initial menu 'top'".green if top_menu.save(:validate => false)


    Mokio::ModulePosition.create!(:name => 'footer')
    puts "\n\tCreated default module position 'footer'".green
    user = Mokio::User.new({
      email: args[:email],
      password: args[:password],
      password_confirmation: args[:password],
      roles_mask: 1
    })
    puts "\n\tCreated default user '#{args[:email]}' with password '#{args[:password]}'".green if user.save(:validate => false)

    text = File.read("#{Rails.root}/config/routes.rb")

    File.open("#{Rails.root}/config/routes.rb", "w") do |file|
      file.puts text.gsub(/# The priority is based upon order of creation: first created \-\> highest priority\./, "mount Mokio::Engine => '/backend'")
    end

    unless File.exist?("#{Rails.root}/config/initializers/mokio.rb")
      puts "\n"
      result = Rails::Generators.invoke("mokio:install")
      puts "\n\tCreated initializer(configuration file) in #{result}".green
    end
    puts "\nMokio is ready to start! Run 'rails server' and go to localhost:3000/backend to see your application in development mode"
  end


  namespace :menu do
    desc "Creates menu tree based on menu.yml file"

    task :create_final_tree => :environment do
      config = YAML.load_file("#{Rails.root}/config/menu.yml")

      langs = []

      config['langs'].each do |l|
        langs << Mokio::Lang.new(l)
      end

      Mokio::Lang.import langs
      
      menus = build_menu(config['menus'], nil)

      menus.each do |me|
        me.save(validate: false) #validation needs to be turned off as we create menu elements with editable flag set to false
      end
    end

  #recursively prepares Menu nodes based on given node list (menu_params)

    def build_menu(menu_params, ancestry) 
      menus = []
      menu_params.each do |m|
        
        m["ancestry"] = ancestry
        new_menu = Mokio::Menu.new(m.except("children"))
        new_menu.build_meta
        menus << new_menu

        unless m["children"].nil?
          menus += build_menu(m["children"], ancestry.blank? ?  m['id'].to_s : ancestry + "/#{m['id'].to_s}")
        end
      end
      menus
    end
  end
end
