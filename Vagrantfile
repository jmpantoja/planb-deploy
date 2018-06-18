# -*- mode: ruby -*-
# vi: set ft=ruby :



confDir = $confDir ||= File.dirname(__FILE__)
require File.expand_path(".ansistrano/enviroment.rb", File.dirname(__FILE__))

siteYamlPath = File.expand_path("nodes.yaml", File.dirname(__FILE__))

Vagrant.configure("2") do |config|

    if File.exist? siteYamlPath then
        settings = YAML::load(File.read(siteYamlPath))
    else
        abort "site settings file not found in #{confDir}"
    end

    config.ssh.forward_agent = true

    config.vm.define "development", primary: true, autostart: true do |node|
        Enviroment.configure(node, "development", settings)
    end

    config.vm.define "preproduction", primary: false, autostart: false do |node|
        Enviroment.configure(node, "preproduction", settings)
    end

    config.vm.define "production", primary: false, autostart: false do |node|
        Enviroment.configure(node, "production", settings)
    end
end
