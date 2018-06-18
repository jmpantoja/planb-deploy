class Enviroment
    def Enviroment.configure(config, env, info)
        settings = info['enviroments'][env]

        projectName =  File.basename(Dir.getwd)
        name =  settings['name'] ||= "#{projectName}-#{env}";

        provider = settings["provider"] ||= "virtualbox"

        # Allow SSH Agent Forward from The Box
        config.ssh.forward_agent = true

        # Configure The Box
        config.vm.define name
        config.vm.synced_folder '.', '/vagrant', disabled: true
        config.vm.box = settings["box"] ||= "ubuntu/bionic64"
        config.vm.hostname = settings["hostname"] ||= name

        # Configure A Private Network IP
        if settings["ip"] != "autonetwork"
            config.vm.network :private_network, ip: settings["ip"] ||= "192.168.10.10"
        else
            config.vm.network :private_network, :ip => "0.0.0.0", :auto_network => true
        end

        # Configure Additional Networks
        if settings.has_key?("networks")
            settings["networks"].each do |network|
                config.vm.network network["type"], ip: network["ip"], bridge: network["bridge"] ||= nil, netmask: network["netmask"] ||= "255.255.255.0"
            end
        end

        # Configure A Few VirtualBox Settings
        if provider == "virtualbox"
            config.vm.provider "virtualbox" do |vb|
                vb.name = settings["name"] ||= name
                vb.customize ["modifyvm", :id, "--memory", settings["memory"] ||= "2048"]
                vb.customize ["modifyvm", :id, "--cpus", settings["cpus"] ||= "1"]
                vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
                vb.customize ["modifyvm", :id, "--natdnshostresolver1", settings["natdnshostresolver"] ||= "on"]
                vb.customize ["modifyvm", :id, "--ostype", "Ubuntu_64"]
                if settings.has_key?("gui") && settings["gui"]
                    vb.gui = true
                end
            end
        end

        if provider == "digital_ocean"
            config.vm.provider "digital_ocean" do |provider, override|
                override.ssh.private_key_path =  settings['private_key_path'] ||= "~/.ssh/id_rsa"
                override.nfs.functional = false
                override.vm.box = 'digital_ocean'
                override.vm.box_url = "https://github.com/smdahlen/vagrant-digitalocean/raw/master/box/digital_ocean.box"
                provider.token = settings["token"]
                provider.image = settings["image"] ||= 'ubuntu-18-04-x64'
                provider.region = settings["region"] ||= 'lon1'
                provider.size = settings["size"] ||= '512mb'
            end
        end

        # Override Default SSH port on the host
        if (settings.has_key?("default_ssh_port"))
            config.vm.network :forwarded_port, guest: 22, host: settings["default_ssh_port"], auto_correct: false, id: "ssh"
        end


        # Configure A Few Parallels Settings
        if provider == "parallels"
            config.vm.provider "parallels" do |v|
                v.name = settings["name"] ||= name
                v.update_guest_tools = settings["update_parallels_tools"] ||= false
                v.memory = settings["memory"] ||= 2048
                v.cpus = settings["cpus"] ||= 1
            end
        end

        # Standardize Ports Naming Schema
        if (settings.has_key?("ports"))
            settings["ports"].each do |port|
                port["guest"] ||= port["to"]
                port["host"] ||= port["send"]
                port["protocol"] ||= "tcp"
            end
        else
            settings["ports"] = []
        end


        # Configure The Public Key For SSH Access
        if settings.include? 'authorize'
            if File.exists? File.expand_path(settings["authorize"])
                config.vm.provision "shell" do |s|
                    s.inline = "echo $1 | grep -xq \"$1\" /home/vagrant/.ssh/authorized_keys || echo \"\n$1\" | tee -a /home/vagrant/.ssh/authorized_keys"
                    s.args = [File.read(File.expand_path(settings["authorize"]))]
                end
            end
        end

        # Copy The SSH Private Keys To The Box
        if settings.include? 'keys'
            if settings["keys"].to_s.length == 0
                puts "Check your nodes.yaml file, you have no private key(s) specified."
                exit
            end
            settings["keys"].each do |key|
                if File.exists? File.expand_path(key)
                    config.vm.provision "shell" do |s|
                        s.privileged = false
                        s.inline = "echo \"$1\" > /home/vagrant/.ssh/$2 && chmod 600 /home/vagrant/.ssh/$2"
                        s.args = [File.read(File.expand_path(key)), key.split('/').last]
                    end
                else
                    puts "Check your nodes.yaml file, the path to your private key does not exist."
                    exit
                end
            end
        end

        # Copy User Files Over to VM
        if settings.include? 'copy'
            settings["copy"].each do |file|
                config.vm.provision "file" do |f|
                    f.source = File.expand_path(file["from"])
                    f.destination = file["to"].chomp('/') + "/" + file["from"].split('/').last
                end
            end
        end

        # Register All Of The Configured Shared Folders
        if settings.include? 'folders'
            settings["folders"].each do |folder|
                if File.exists? File.expand_path(folder["map"])
                    mount_opts = []

                    if (folder["type"] == "nfs")
                        mount_opts = folder["mount_options"] ? folder["mount_options"] : ['actimeo=1', 'nolock']
                    elsif (folder["type"] == "smb")
                        mount_opts = folder["mount_options"] ? folder["mount_options"] : ['vers=3.02', 'mfsymlinks']
                    end

                    # For b/w compatibility keep separate 'mount_opts', but merge with options
                    options = (folder["options"] || {}).merge({ mount_options: mount_opts })

                    # Double-splat (**) operator only works with symbol keys, so convert
                    options.keys.each{|k| options[k.to_sym] = options.delete(k) }

                    config.vm.synced_folder folder["map"], folder["to"], type: folder["type"] ||= nil, **options

                    # Bindfs support to fix shared folder (NFS) permission issue on Mac
                    if (folder["type"] == "nfs")
                        if Vagrant.has_plugin?("vagrant-bindfs")
                            config.bindfs.bind_folder folder["to"], folder["to"]
                        end
                    end
                else
                    config.vm.provision "shell" do |s|
                        s.inline = ">&2 echo \"Unable to mount one of your folders. Please check your folders in nodes.yaml\""
                    end
                end
            end
        end

        config.vm.provision "ansible" do |ansible|
            ansible.playbook = ".ansistrano/provision.yml"
            ansible.extra_vars =  settings["extra_vars"] ||= {}
        end
    end
end
