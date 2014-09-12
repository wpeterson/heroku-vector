
module HerokuVector
  module Helper
    def self.included(target)
      target.send(:include, InstanceMethods)
      target.extend ClassMethods
    end

    module ClassMethods
    end

    module InstanceMethods
      def logger
        HerokuVector.logger
      end

      def round_to_one_decimal(value)
        ((value * 10.0).floor.to_f / 10.0)
      end

    end
  end
end
