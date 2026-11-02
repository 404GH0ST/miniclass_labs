bridge_interface = ENV["WRI_LAB_BRIDGE_INTERFACE"]
bridge_enabled = !bridge_interface.nil? && !bridge_interface.empty?

# Projects kept on NTFS/exFAT mounts cannot store the Vagrant SSH private key:
# chmod is a no-op there, so the key keeps world-readable permissions and SSH
# refuses it mid-boot ("private key ... invalid permissions"). Detect that case
# and abort with the remedy for the commands that would actually hit it.
begin
  probe = File.join(Dir.pwd, ".vagrant-perm-probe-#{Process.pid}")
  File.write(probe, "")
  File.chmod(0o600, probe)
  chmod_ok = (File.stat(probe).mode & 0o777) == 0o600
ensure
  File.delete(probe) if File.exist?(probe)
end
key_commands = %w[up ssh scp reload provision resume]
if !chmod_ok && key_commands.include?(ARGV[0]) && ENV["VAGRANT_DOTFILE_PATH"].to_s.empty?
  abort(<<~ERROR)
    [WRI LAB] This project directory is on a filesystem without chmod support
    (NTFS/exFAT), so Vagrant cannot secure its SSH private key there.

    Fix, either:

        scripts/lab.sh up week3          # wrapper redirects state to $HOME

    or:

        export VAGRANT_DOTFILE_PATH="$HOME/.vagrant"
        vagrant up week3
  ERROR
end

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
    "week5" => "192.168.56.50",
  }.each do |name, address|
    # The target must be selected explicitly (for example, `vagrant up week5`).
    # This prevents a bare `vagrant up` from consuming resources by deploying every
    # week's lab at once.
    config.vm.define name, autostart: false do |machine|
      machine_bridge_enabled = bridge_enabled
      machine.vm.hostname = name
      machine.vm.network "private_network", ip: address
      if machine_bridge_enabled
        machine.vm.network "public_network", bridge: bridge_interface
      end
      if name == "week5"
        machine.vm.provider "virtualbox" do |vb|
          vb.memory = 4096
          vb.cpus = 2
        end
      end
      provision_with_ansible(machine, name, address, machine_bridge_enabled)
    end
  end
end
