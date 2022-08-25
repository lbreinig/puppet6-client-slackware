require_relative '../../../puppet/provider/package'

Puppet::Type.type(:package).provide :slackpkg, :source => :slackpkg, :parent => Puppet::Provider::Package do
  desc "Slackpkg packaging support for ya boyz!"

  commands :slackpkg => "/usr/sbin/slackpkg"
  commands :installpkg => "/sbin/installpkg"

  defaultfor  :operatingsystem => :Slackware
  
  def self.instances
    instances = []
    
    # Get the installed packages
    installed_packages = get_installed_packages
    installed_packages.sort_by { |k, _| k }.each do |package, version|
      instances << new(to_resource_hash(package, version))
    end
 
    instances
  end

  # returns a hash package => version of installed packages
  def self.get_installed_packages
    begin
      packages = {}
      execpipe( ['/bin/cat', '/var/lib/slackpkg/pkglist' ]) do |pipe|
        regex = %r{^(slackware(64)?|extra|pasture|patches) (\S+) (\S+)}
        pipe.each_line do |line|
          match = regex.match(line)
          if match
            packages[match.captures[0]] = match.captures[1]
          else
            warning(_("Failed to match line '%{line}'") % { line: line })
          end
        end
      end
      packages
    rescue Puppet::ExecutionFailure
      fail(_("Error getting installed packages"))
    end
  end
  
  def latest
    self.update
  end
  
  def self.to_resource_hash(name, version)
    {
      :name     => name,
      :ensure   => version,
      :provider => self.name
    }
  end
  
  def install
    if @resource[:source]
      installpkg( @resource[:source] )
    else
      slackpkg( '-batch=on', '-default_answer=y', 'install', @resource[:name] )
    end
  end

  def uninstall
    slackpkg( '-batch=on', '-default_answer=y', 'remove', @resource[:name] )
  end

  def update
    slackpkg( 'update' )
    slackpkg( '-batch=on', '-default_answer=y', 'upgrade', @resource[:name] )
  end

  def query
    # list out our specific package
    execpipe( ['/usr/sbin/slackpkg', 'search', @resource[:name]] ) do |output|
    installed = %r{^\[ installed \]}
    uninstalled = %r{^\[uninstalled\]}
    output.each_line do |line|
      if installed.match(line) 
        return { :ensure => 'present' }
      elsif uninstalled.match(line)
        return { :ensure => 'absent' }
      else
        next
      end
    end
  end
  rescue Puppet::ExecutionFailure
    return {
      :ensure => :purged,
      :status => 'missing',
      :name => @resource[:name],
      :error => 'ok',
    }
  end

  private

end
