module WakameOS
  module Client
    class SetupBase
      @@credential = {}
      @@spec_name  = 'default'
      @@option     = {}
      
      def self.credential;              @@credential;                  end
      def self.credential=(credential); @@credential = credential.dup; end
      def self.spec_name;               @@spec_name;                   end
      def self.spec_name=(spec_name);   @@spec_name = spec_name.dup;   end
      
      def self.setup(option={})
        credential = option.delete(:credential) || @@credential
        spec_name  = option.delete(:spec_name)  || @@spec_name  || 'default'
        
        option = option.dup
        @@credential = credential.dup
        @@spec_name  = spec_name.dup
        @@option     = option
        {:credential => credential.dup, :spec_name => spec_name.dup}
      end
    end
  end
end
