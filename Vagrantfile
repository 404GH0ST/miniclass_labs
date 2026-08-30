bridge_interface = ENV["WRI_LAB_BRIDGE_INTERFACE"]
bridge_enabled = !bridge_interface.nil? && !bridge_interface.empty?

def provision_with_ansible(machine, machine_name, address, bridge_enabled)
  machine.vm.provision "ansible" do |ansible|
    ansible.playbook = "ansible/playbooks/#{machine_name}.yml"
    ansible.config_file = "ansible.cfg"
    ansible.limit = machine_name
    ansible.compatibility_mode = "2.0"
    ansible.extra_vars = {
      "lab_ip" => address,
      "lab_bind_ip" => bridge_enabled ? "0.0.0.0" : address,
      "lab_allowed_network" => bridge_enabled ? "0.0.0.0/0" : "192.168.56.0/24",
      "lab_bridge_enabled" => bridge_enabled,
    }
  end
end

Vagrant.configure("2") do |config|
  config.vm.box = "cloud-image/ubuntu-24.04"
  # The lab is provisioned over SSH, so it does not require VirtualBox shared
  # folders or matching Guest Additions.
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.boot_timeout = 600

  # Some hosts install the optional vagrant-vbguest plugin. Its automatic
  # Guest Additions rebuild can block first boot on newer VirtualBox releases.
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end

  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.memory = 1024
    vb.cpus = 1
  end

  {
    "week3" => "192.168.56.30",
    "week4" => "192.168.56.40",
    "week5" => "192.168.56.50",
    "week6" => "192.168.56.60",
    "week7" => "192.168.56.70",
    "week8" => "192.168.56.80",
  }.each do |name, address|
    # Weekly targets must be selected explicitly (for example, `vagrant up week4`).
    # This prevents a bare `vagrant up` from consuming resources by deploying every
    # week's lab at once.
    config.vm.define name, autostart: false do |machine|
      machine.vm.hostname = name
      machine.vm.network "private_network", ip: address
      if bridge_enabled
        machine.vm.network "public_network", bridge: bridge_interface
      end
      if name == "week4"
        machine.vm.provider "virtualbox" do |vb|
          vb.memory = 1536
          vb.cpus = 2
        end
      end
      provision_with_ansible(machine, name, address, bridge_enabled)
    end
  end
end
