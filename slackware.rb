# The standard init-based service type.  Many other service types are
# customizations of this module.
Puppet::Type.type(:service).provide :slackware, :parent => :init do
  desc "Slackware init service management."

  def self.defpath
    "/etc/rc.d"
  end

  # Debian and Ubuntu should use the Debian provider.
  # RedHat systems should use the RedHat provider.
  confine :true => begin
      os = Puppet.runtime[:facter].value(:operatingsystem).downcase
      (os == 'slackware' || os == 'slackware64' || os == 'salix')
  end
  defaultfor :operatingsystem => :Slackware

  # We can't confine this here, because the init path can be overridden.
  #confine :exists => defpath

  # some init scripts are not safe to execute, e.g. we do not want
  # to suddenly run /etc/init.d/reboot.sh status and reboot our system. The
  # exclude list could be platform agnostic but I assume an invalid init script
  # on system A will never be a valid init script on system B
  def self.excludes
    excludes = []
    
    excludes
  end

  # List all services of this type.
  def self.instances
    get_services(self.defpath)
  end

  def self.get_services(defpath, exclude = self.excludes)
    defpath = [defpath] unless defpath.is_a? Array
    instances = []
    defpath.each do |path|
      unless Puppet::FileSystem.directory?(path)
        Puppet.debug "Service path #{path} does not exist"
        next
      end

      check = [:ensure]

      check << :enable if public_method_defined? :enabled?

      Dir.entries(path).each do |name|
        fullpath = File.join(path, name)
        next if name =~ /^\./
        next if exclude.include? name
        next if Puppet::FileSystem.directory?(fullpath)
        next unless Puppet::FileSystem.executable?(fullpath)
        instances << new(:name => name, :path => path, :hasstatus => true)
      end
    end
    instances
  end

  # Mark that our init script supports 'status' commands.
  def hasstatus=(value)
    case value
    when true, "true"; @parameters[:hasstatus] = true
    when false, "false"; @parameters[:hasstatus] = false
    else
      raise Puppet::Error, "Invalid 'hasstatus' value #{value.inspect}"
    end
  end

  # Where is our init script?
  def initscript
    @initscript ||= self.search(@resource[:name])
  end

  def paths
    @paths ||= @resource[:path].find_all do |path|
      if Puppet::FileSystem.directory?(path)
        true
      else
        if Puppet::FileSystem.exist?(path)
          self.debug "Search path #{path} is not a directory"
        else
          self.debug "Search path #{path} does not exist"
        end
        false
      end
    end
  end

  def search(name)
    paths.each do |path|
      fqname_rc = File.join(path, "rc.#{name}")                                                                                                 
      if Puppet::FileSystem.exist? fqname_rc
        return fqname_rc
      else
        self.debug("Could not find rc.#{name} in #{path}")                                                                                                                                        
      end
    end
    raise Puppet::Error, "Could not find init script for '#{name}'"
  end


  # The start command is just the init script with 'start'.
  def startcmd
    [initscript, :start]
  end

  # The stop command is just the init script with 'stop'.
  def stopcmd
    [initscript, :stop]
  end

  def restartcmd
    (@resource[:hasrestart] == :true) && [initscript, :restart]
  end

  def texecute(type, command, fof = true, squelch = false, combine = true)
    if type == :start && Puppet.runtime[:facter].value(:osfamily) == "Solaris"
        command =  ["/usr/bin/ctrun -l child", command].flatten.join(" ")
    end
    super(type, command, fof, squelch, combine)
  end

  # If it was specified that the init script has a 'status' command, then
  # we just return that; otherwise, we return false, which causes it to
  # fallback to other mechanisms.
  def statuscmd
    (@resource[:hasstatus] == :true) && [initscript, :status]
  end

private

end
