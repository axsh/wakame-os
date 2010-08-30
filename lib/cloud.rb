#
module WakameOS
  module Cloud

    autoload :Driver,    'cloud/driver'

    autoload :Base,      'cloud/base'
    autoload :PermanentHost, 'cloud/permanent_host'
    autoload :AWS,       'cloud/aws'
    autoload :Wakame,    'cloud/wakame'
    # autoload :SliceHost, 'cloud/slice_host'
    # autoload :SoftLayer, 'cloud/soft_layer'

  end
end
